import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../checkout/domain/entities/order.dart';
import '../../../store_owner/domain/entities/store_order_part.dart';
import '../providers/driver_providers.dart';

class DriverOrderDetailsPage extends ConsumerWidget {
  final Order order;

  const DriverOrderDetailsPage({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partsAsync = ref.watch(driverOrderPartsProvider(order.id));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(order.unifiedOrderNumber ?? order.id),
        ),
        body: partsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'تعذر تحميل أجزاء الطلب:\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (parts) {
            final allPickedUp = parts.isNotEmpty &&
                parts.every(
                  (part) => part.status == StoreOrderPartStatus.pickedUp,
                );

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(driverOrderPartsProvider(order.id));
                await ref.read(driverOrderPartsProvider(order.id).future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _OrderSummary(order: order),
                  const SizedBox(height: 14),
                  _ProductsReviewCard(order: order),
                  const SizedBox(height: 16),
                  Text(
                    'استلام الطلب حسب المحل',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  if (parts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('لا توجد أجزاء للطلب.'),
                      ),
                    )
                  else
                    ...parts.map(
                      (part) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PartCard(
                          part: part,
                          items: order.items
                              .where((item) => item.storeId == part.storeId)
                              .toList(),
                          onPickedUp: () async {
                            await ref
                                .read(driverRepositoryProvider)
                                .updateOrderPartStatus(
                                  partId: part.id,
                                  status: StoreOrderPartStatus.pickedUp,
                                );
                            ref.invalidate(driverOrderPartsProvider(order.id));
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (allPickedUp)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.local_shipping_outlined,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'تم استلام جميع أجزاء الطلب',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'الطلب الآن في الطريق إلى العميل.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () {
                                _showOtpDialog(context, ref, order.id);
                              },
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('تأكيد التسليم بالـ OTP'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showOtpDialog(
    BuildContext context,
    WidgetRef ref,
    String orderId,
  ) async {
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _OtpDialog(
        orderId: orderId,
      ),
    );

    if (!context.mounted) return;

    if (verified == true) {
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسليم الطلب بنجاح.'),
        ),
      );
    }
  }
}

class _OtpDialog extends ConsumerStatefulWidget {
  final String orderId;

  const _OtpDialog({
    required this.orderId,
  });

  @override
  ConsumerState<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends ConsumerState<_OtpDialog> {
  late final TextEditingController _controller;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _controller.text.trim();

    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل OTP مكوّنًا من 4 أرقام.'),
        ),
      );
      return;
    }

    if (!RegExp(r'^\d{4}$').hasMatch(otp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP يجب أن يحتوي على أرقام فقط.'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final verified = await ref
          .read(driverRepositoryProvider)
          .verifyDeliveryOtp(
            orderId: widget.orderId,
            otp: otp,
          );

      if (!mounted) return;

      if (verified) {
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP غير صحيح أو لم يعد صالحًا.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تأكيد التسليم:\n$error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تأكيد التسليم'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        maxLength: 4,
        autofocus: true,
        enabled: !_loading,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'OTP',
          hintText: 'أدخل الكود الذي أعطاك إياه العميل',
          counterText: '',
        ),
        onSubmitted: (_) {
          if (!_loading) {
            _verify();
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _loading ? null : _verify,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تأكيد'),
        ),
      ],
    );
  }
}


class _OrderSummary extends StatelessWidget {
  final Order order;

  const _OrderSummary({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الطلب ${order.unifiedOrderNumber ?? order.id}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.person_outline, label: order.deliveryRecipientName),
            _InfoRow(icon: Icons.phone_outlined, label: order.deliveryPhone),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: order.deliveryAddress.isEmpty
                  ? 'العنوان غير مكتمل'
                  : order.deliveryAddress,
            ),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: '${order.totalAmount.toStringAsFixed(2)} ج.م',
            ),
            if (order.deliveryBaseFee > 0)
              _InfoRow(
                icon: Icons.local_shipping_outlined,
                label:
                    'رسوم التوصيل: ${order.deliveryBaseFee.toStringAsFixed(2)} ج.م',
              ),
            if (order.multiStoreFee > 0)
              _InfoRow(
                icon: Icons.storefront_outlined,
                label:
                    'رسوم المتاجر الإضافية: ${order.multiStoreFee.toStringAsFixed(2)} ج.م',
              ),
            if (order.deliveryAreaFee > 0)
              _InfoRow(
                icon: Icons.map_outlined,
                label:
                    'رسوم منطقة التوصيل: ${order.deliveryAreaFee.toStringAsFixed(2)} ج.م',
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductsReviewCard extends StatelessWidget {
  final Order order;

  const _ProductsReviewCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مراجعة المنتجات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'راجع الأصناف والكميات والأسعار قبل الاستلام.',
              style: TextStyle(color: Color(0xFF718096)),
            ),
            const SizedBox(height: 12),
            if (order.items.isEmpty)
              const Text('لا توجد تفاصيل منتجات لهذا الطلب.')
            else
              ...order.items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBF9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE3ECE7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shopping_basket_outlined,
                        size: 21,
                        color: Color(0xFF168957),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_formatQuantity(item.quantity)} × ${item.unitPrice.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                color: Color(0xFF52665D),
                                fontSize: 12,
                              ),
                            ),
                            if (item.sellingMethod.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  _sellingMethodLabel(item.sellingMethod),
                                  style: const TextStyle(
                                    color: Color(0xFF718096),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.totalPrice.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PartCard extends StatelessWidget {
  final StoreOrderPart part;
  final List<OrderItem> items;
  final Future<void> Function() onPickedUp;

  const _PartCard({
    required this.part,
    required this.items,
    required this.onPickedUp,
  });

  @override
  Widget build(BuildContext context) {
    final pickedUp = part.status == StoreOrderPartStatus.pickedUp;

    final statusText = switch (part.status) {
      StoreOrderPartStatus.preparing => 'قيد التجهيز',
      StoreOrderPartStatus.ready => 'جاهز',
      StoreOrderPartStatus.pickedUp => 'تم الاستلام',
    };

    final statusColor = switch (part.status) {
      StoreOrderPartStatus.preparing => const Color(0xFFF59E0B),
      StoreOrderPartStatus.ready => const Color(0xFF168FE0),
      StoreOrderPartStatus.pickedUp => const Color(0xFF168957),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    part.storeName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.inventory_2_outlined,
              label: '${part.itemCount} منتج  ${part.subtotal.toStringAsFixed(2)} ج.م',
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text(
                'لم يتم ربط أصناف بهذا المحل في بيانات الطلب.',
                style: TextStyle(color: Color(0xFF9B6B00), fontSize: 12),
              )
            else
              ...items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBF9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatQuantity(item.quantity)} × ${item.unitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF52665D),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!pickedUp && part.status == StoreOrderPartStatus.ready) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPickedUp,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('استلام الجزء بعد المراجعة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}

String _sellingMethodLabel(String value) {
  switch (value) {
    case 'weight':
      return 'بالكيلو';
    case 'value':
      return 'بالقيمة';
    case 'fraction':
      return 'بالجزء/الكسر';
    case 'unit':
    default:
      return 'بالوحدة';
  }
}
