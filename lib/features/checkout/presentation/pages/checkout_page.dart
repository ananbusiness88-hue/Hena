import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/app_exception.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../auth/presentation/pages/complete_profile_page.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/order.dart';
import '../providers/checkout_providers.dart';
import '../../../delivery/presentation/providers/delivery_settings_providers.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  PaymentMethod _paymentMethod = PaymentMethod.cashOnDelivery;

  final _recipientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingCustomerData = true;
  Address? _savedDefaultAddress;

  static const String _paymentNumber = '01002026939';

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingCustomerData = false;
        });
      }
      return;
    }

    try {
      final client = Supabase.instance.client;
      final repository = ref.read(checkoutRepositoryProvider);

      final profileResponse = await client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', user.id)
          .maybeSingle();

      final addresses = await repository.getAddresses(user.id);

      if (!mounted) {
        return;
      }

      final profileName =
          (profileResponse?['full_name'] as String?)?.trim() ?? '';
      final profilePhone =
          (profileResponse?['phone'] as String?)?.trim() ?? '';

      Address? defaultAddress;

      for (final address in addresses) {
        if (address.isDefault) {
          defaultAddress = address;
          break;
        }
      }

      _savedDefaultAddress = defaultAddress;

      //     profiles.
      if (profileName.isNotEmpty) {
        _recipientNameController.text = profileName;
      }

      if (profilePhone.isNotEmpty) {
        _phoneController.text = profilePhone;
      }

      //      .
      if (defaultAddress != null) {
        _addressController.text = defaultAddress.fullAddress;

        //      fallback
        //      profile.
        if (profileName.isEmpty &&
            defaultAddress.recipientName.trim().isNotEmpty) {
          _recipientNameController.text =
              defaultAddress.recipientName.trim();
        }

        if (profilePhone.isEmpty &&
            defaultAddress.phone.trim().isNotEmpty) {
          _phoneController.text = defaultAddress.phone.trim();
        }
      }

      setState(() {
        _isLoadingCustomerData = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCustomerData = false;
      });

      _showMessage(
        '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0639\u0645\u064a\u0644: $error',
      );
    }
  }

  bool _isUsingSavedDefaultAddress() {
    final address = _savedDefaultAddress;

    if (address == null) {
      return false;
    }

    return _recipientNameController.text.trim() ==
            address.recipientName.trim() &&
        _phoneController.text.trim() == address.phone.trim() &&
        _addressController.text.trim() == address.fullAddress.trim();
  }

  Future<void> _openAddressSetup() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _showMessage('\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0623\u0648\u0644\u0627\u064b');
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompleteProfilePage(
          phone: _phoneController.text.trim(),
          email: user.email ?? '',
          fullName: _recipientNameController.text.trim(),
          returnToPreviousPage: true,
        ),
      ),
    );

    if (result != true || !mounted) {
      return;
    }

    setState(() {
      _isLoadingCustomerData = true;
      _savedDefaultAddress = null;
    });

    await _loadCustomerData();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _paymentMethodName() {
    switch (_paymentMethod) {
      case PaymentMethod.cashOnDelivery:
        return '\u0643\u0627\u0634 \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645';
      case PaymentMethod.instapay:
        return 'Instapay \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645';
      case PaymentMethod.vodafoneCash:
        return 'Vodafone Cash \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645';
    }
  }

  void _showPaymentInfo() {
    if (_paymentMethod == PaymentMethod.cashOnDelivery) {
      return;
    }

    final serviceName = _paymentMethod == PaymentMethod.instapay
        ? 'Instapay'
        : 'Vodafone Cash';

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _paymentMethod == PaymentMethod.instapay
                      ? Icons.account_balance
                      : Icons.phone_android,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '\u0627\u0644\u062f\u0641\u0639 \u064a\u062a\u0645 \u0639\u0646\u062f \u0627\u0633\u062a\u0644\u0627\u0645 \u0627\u0644\u0637\u0644\u0628 \u0641\u0642\u0637.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  '\u0631\u0642\u0645 \u0627\u0644\u062a\u062d\u0648\u064a\u0644',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const SelectableText(
                  _paymentNumber,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '\u0639\u0646\u062f \u0627\u0644\u062a\u062d\u0648\u064a\u0644\u060c \u064a\u062a\u062d\u0642\u0642 \u0627\u0644\u0645\u0646\u062f\u0648\u0628 \u0645\u0646 \u0627\u0644\u062a\u062d\u0648\u064a\u0644 \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645 \u0648\u064a\u062d\u062a\u0641\u0638 \u0628\u0644\u0642\u0637\u0629 \u0634\u0627\u0634\u0629 \u0644\u0625\u062b\u0628\u0627\u062a \u0627\u0644\u0639\u0645\u0644\u064a\u0629.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                   child: const Text('\u062d\u0633\u0646\u064b\u0627'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmOrder(List<CartItem> items) async {
    if (_isSubmitting || _isLoadingCustomerData) {
      return;
    }

    if (items.isEmpty) {
      _showMessage('\u0627\u0644\u0633\u0644\u0629 \u0641\u0627\u0631\u063a\u0629');
      return;
    }

    final recipientName = _recipientNameController.text.trim();
    final phone = _phoneController.text.trim();
    final addressText = _addressController.text.trim();
    final note = _noteController.text.trim();

    if (recipientName.isEmpty || phone.isEmpty || addressText.isEmpty) {
      _showMessage('\u0645\u0646 \u0641\u0636\u0644\u0643 \u0623\u0643\u0645\u0644 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0648\u0635\u064a\u0644');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _showMessage('\u064a\u062c\u0628 \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0623\u0648\u0644\u0627\u064b');
      return;
    }

    final groupedItems = <String, List<CartItem>>{};

    for (final item in items) {
      groupedItems
          .putIfAbsent(item.product.storeId, () => [])
          .add(item);
    }

    final storeCount = groupedItems.length;

    final deliverySettings = ref.read(deliverySettingsProvider).requireValue;

    final deliveryFee = deliverySettings.calculateFee(storeCount);

    final subtotal = ref.read(cartSubtotalProvider);
    final total = subtotal + deliveryFee;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الطلب'),
          content: Text(
            'عدد المتاجر: $storeCount\n\n'
            'طريقة الدفع:\n'
            '${_paymentMethodName()}\n\n'
            'إجمالي المنتجات: ${subtotal.toStringAsFixed(2)} ج.م\n'
            'رسوم التوصيل: ${deliveryFee.toStringAsFixed(2)} ج.م\n\n'
            'الإجمالي: ${total.toStringAsFixed(2)} ج.م\n\n'
            'الدفع يتم عند الاستلام فقط.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد الطلب'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(checkoutRepositoryProvider);

      final Address address;

      if (_isUsingSavedDefaultAddress()) {
        address = _savedDefaultAddress!;
      } else {
        address = await repository.createAddress(
          userId: user.id,
          label: '\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0637\u0644\u0628',
          recipientName: recipientName,
          phone: phone,
          area: addressText,
          buildingNumber: '',
          apartmentNumber: '',
          addressDetails: addressText,
          isDefault: false,
        );
      }

      final orderItems = groupedItems.values
          .expand(
            (storeItems) => storeItems.map(
              (item) => OrderItem(
                id: '',
                orderId: '',
                storeId: item.product.storeId,
                productId: item.product.id,
                pricingId: item.pricing.id,
                offerId: item.offer?.id,
                productName: item.product.name,
                pricingName: item.pricing.unitName,
                sellingMethod: item.product.sellingMethod.name,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
              ),
            ),
          )
          .toList();

      final order = await repository.createOrder(
        deliveryAddressId: address.id,
        paymentMethod: _paymentMethod,
        customerNote: note.isEmpty ? null : note,
        items: orderItems,
      );

      if (!mounted) {
        return;
      }

      ref.read(cartProvider).clear();

      final orderNumber = order.id;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('تم استلام طلبك'),
            content: Text(
              'تم استلام طلبك بنجاح.\n\n'
              'رقم الطلب:\n'
              '$orderNumber\n\n'
              'الإجمالي: ${total.toStringAsFixed(2)} ج.م\n\n'
              'سيتم تجهيز طلبك وإرساله إليك.'
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context, true);
                },
                child: const Text('تم'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      // The raw error is never shown to the customer: it used to expose
      // internal database details. The technical detail only goes to the log.
      final failure = mapNetworkError(error, context: 'createOrder');
      debugPrint('CHECKOUT: order creation failed -> ${failure.debugMessage}');
      _showMessage(failure.message);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartItemsProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final deliverySettingsAsync = ref.watch(deliverySettingsProvider);
    final deliverySettings = deliverySettingsAsync.asData?.value;

    final storeIds = <String>{};
    for (final item in items) {
      storeIds.add(item.product.storeId);
    }

    final storeCount = storeIds.length;
    final deliveryFee =
        deliverySettings?.calculateFee(storeCount) ?? 0.0;
    final total = subtotal + deliveryFee;

    final isBusy =
        _isSubmitting ||
        _isLoadingCustomerData ||
        deliverySettingsAsync.isLoading ||
        deliverySettings == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u0625\u062a\u0645\u0627\u0645 \u0627\u0644\u0637\u0644\u0628'),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text('\u0627\u0644\u0633\u0644\u0629 \u0641\u0627\u0631\u063a\u0629'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle(
                    context,
                    icon: Icons.location_on_outlined,
                    title: '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0648\u0635\u064a\u0644',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _recipientNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '\u0627\u0633\u0645 \u0627\u0644\u0645\u0633\u062a\u0644\u0645',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    readOnly: true,
                    onTap: _openAddressSetup,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'عنوان التوصيل',
                      hintText: 'اختر عنوان التوصيل من المناطق المتاحة',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'تغيير العنوان',
                        onPressed: _openAddressSetup,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (!_isLoadingCustomerData &&
                      _savedDefaultAddress == null) ...[
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                '\u0644\u0627 \u064a\u0648\u062c\u062f \u0639\u0646\u0648\u0627\u0646 \u0645\u062d\u0641\u0648\u0638. \u0623\u0636\u0641 \u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u062a\u0648\u0635\u064a\u0644 \u0644\u0644\u0645\u062a\u0627\u0628\u0639\u0629.',
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _openAddressSetup,
                              icon: const Icon(
                                Icons.add_location_alt_outlined,
                              ),
                              label: const Text('\u0625\u0636\u0627\u0641\u0629 \u0639\u0646\u0648\u0627\u0646'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0644\u0644\u0637\u0644\u0628 (\u0627\u062e\u062a\u064a\u0627\u0631\u064a)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    context,
                    icon: Icons.payment_outlined,
                    title: '\u0637\u0631\u064a\u0642\u0629 \u0627\u0644\u062f\u0641\u0639',
                  ),
                  const SizedBox(height: 12),
                  _PaymentOption(
                    title: '\u0643\u0627\u0634 \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645',
                    subtitle:
                        '\u0627\u062f\u0641\u0639 \u0644\u0644\u0645\u0646\u062f\u0648\u0628 \u0639\u0646\u062f \u0648\u0635\u0648\u0644 \u0627\u0644\u0637\u0644\u0628',
                    icon: Icons.payments_outlined,
                    selected:
                        _paymentMethod ==
                            PaymentMethod.cashOnDelivery,
                    onTap: () {
                      setState(() {
                        _paymentMethod =
                            PaymentMethod.cashOnDelivery;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _PaymentOption(
                    title: 'Instapay',
                    subtitle: '\u062a\u062d\u0648\u064a\u0644 \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645',
                    icon: Icons.account_balance_outlined,
                    selected:
                        _paymentMethod ==
                            PaymentMethod.instapay,
                    onTap: () {
                      setState(() {
                        _paymentMethod =
                            PaymentMethod.instapay;
                      });
                      _showPaymentInfo();
                    },
                  ),
                  const SizedBox(height: 10),
                  _PaymentOption(
                    title: 'Vodafone Cash',
                    subtitle: '\u062a\u062d\u0648\u064a\u0644 \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645',
                    icon: Icons.phone_android_outlined,
                    selected:
                        _paymentMethod ==
                            PaymentMethod.vodafoneCash,
                    onTap: () {
                      setState(() {
                        _paymentMethod =
                            PaymentMethod.vodafoneCash;
                      });
                      _showPaymentInfo();
                    },
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: '\u0645\u0644\u062e\u0635 \u0627\u0644\u0637\u0644\u0628',
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _SummaryRow(
                            title: '\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
                            value: '${items.length} \u0645\u0646\u062a\u062c',
                          ),
                          const SizedBox(height: 10),
                          _SummaryRow(
                            title: '\u0627\u0644\u0645\u062c\u0645\u0648\u0639 \u0627\u0644\u0641\u0631\u0639\u064a',
                            value:
                                '${subtotal.toStringAsFixed(2)} \u062c.\u0645',
                          ),
                          const SizedBox(height: 10),
                          _SummaryRow(
                            title: '\u0631\u0633\u0648\u0645 \u0627\u0644\u062a\u0648\u0635\u064a\u0644',
                            value: '${deliveryFee.toStringAsFixed(2)} \u062c.\u0645',
                          ),
                          const Divider(height: 24),
                          _SummaryRow(
                            title: '\u0627\u0644\u0625\u062c\u0645\u0627\u0644\u064a',
                            value:
                                '${total.toStringAsFixed(2)} \u062c.\u0645',
                            bold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed:
                        isBusy
                            ? null
                            : () => _confirmOrder(items),
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(54),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            '\u062a\u0623\u0643\u064a\u062f \u0627\u0644\u0637\u0644\u0628  ${total.toStringAsFixed(2)} \u062c.\u0645',
                            style:
                                const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '\u0627\u0644\u062f\u0641\u0639 \u064a\u062a\u0645 \u0639\u0646\u062f \u0627\u0644\u0627\u0633\u062a\u0644\u0627\u0645 \u0641\u0642\u0637. \u0644\u0627 \u064a\u062a\u0645 \u0637\u0644\u0628 \u0623\u064a \u062f\u0641\u0639 \u0645\u0633\u0628\u0642.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  Color _accentColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (icon == Icons.account_balance_outlined) {
      return scheme.primary;
    }

    if (icon == Icons.phone_android_outlined) {
      return const Color(0xFFE53935);
    }

    return const Color(0xFF2E8B57);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(context);
    final background = selected
        ? accent.withValues(alpha: 0.12)
        : accent.withValues(alpha: 0.04);
    final borderColor = selected
        ? accent
        : accent.withValues(alpha: 0.25);

    return Card(
      elevation: selected ? 3 : 1,
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: borderColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: selected ? 0.18 : 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 27,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: selected ? accent : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Theme.of(context)
                            .colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off_outlined,
                  key: ValueKey<bool>(selected),
                  color: selected
                      ? accent
                      : Theme.of(context).colorScheme.outline,
                  size: 27,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String title;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.title,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight:
          bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 17 : 14,
    );

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: style),
        Text(value, style: style),
      ],
    );
  }
}
