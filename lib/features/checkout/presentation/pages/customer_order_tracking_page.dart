import '../../../../core/services/fcm_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerOrderTrackingPage extends StatefulWidget {
  const CustomerOrderTrackingPage({super.key});

  @override
  State<CustomerOrderTrackingPage> createState() =>
      _CustomerOrderTrackingPageState();
}

class _CustomerOrderTrackingPageState extends State<CustomerOrderTrackingPage> {
  final SupabaseClient _client = Supabase.instance.client;

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  Timer? _editWindowTimer;
  DateTime _countdownNow = DateTime.now();

  final Map<String, String> _otpByOrder = {};
  final Map<String, Map<String, dynamic>?> _driverContactByOrder = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _subscribeToOrders();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadOrders(silent: true),
    );

    _editWindowTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _countdownNow = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _editWindowTimer?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل طلباتك.';
        });
      }
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await _client
          .from('orders')
          .select(
            'id,unified_order_number,status,driver_id,subtotal,delivery_fee,'
            'extra_fee,total,created_at,updated_at,customer_notes,'
            'delivery_recipient_name,delivery_phone,'
            'delivery_governorate,delivery_city,delivery_area,'
            'delivery_building_number,delivery_apartment_number,'
            'delivery_address_details,'
            'order_items('
            'id,store_id,product_id,product_name,unit_price,quantity,'
            'selling_method,item_total'
            ')',
          )
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      final rows = (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      if (!mounted) return;
      for (final order in rows) {
        final orderId = order['id']?.toString();
        final driverId = order['driver_id']?.toString();

        if (orderId == null || orderId.isEmpty) continue;

        if (driverId == null || driverId.isEmpty) {
          _driverContactByOrder.remove(orderId);
          continue;
        }

        if (_driverContactByOrder.containsKey(orderId)) continue;

        try {
          final response = await _client.rpc(
            'customer_get_assigned_driver_contact',
            params: {'p_order_id': orderId},
          );

          if (response is Map) {
            _driverContactByOrder[orderId] = Map<String, dynamic>.from(
              response,
            );
          } else {
            _driverContactByOrder[orderId] = null;
          }
        } catch (error) {
          // Contact lookup is best effort: keep the order visible even when the
          // driver phone lookup fails.
          debugPrint(
            'ORDER TRACKING: driver contact lookup failed for $orderId -> $error',
          );
          _driverContactByOrder[orderId] = null;
        }
      }
      setState(() {
        _orders = rows;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الطلبات:\n$error';
      });
    }
  }

  void _subscribeToOrders() {
    final user = _client.auth.currentUser;

    if (user == null) return;

    final channel = _client.channel('customer-orders-${user.id}');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'orders',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'customer_id',
        value: user.id,
      ),
      callback: (_) {
        _loadOrders(silent: true);
      },
    );

    channel.subscribe();
    _channel = channel;
  }

  Future<void> _loadOtp(String orderId) async {
    if (_otpByOrder.containsKey(orderId)) return;

    try {
      final response = await _client.rpc(
        'customer_get_delivery_otp',
        params: {'p_order_id': orderId},
      );

      debugPrint('HENA OTP RPC RESPONSE: $response');

      final otp = response?.toString().trim() ?? '';

      debugPrint('HENA OTP VALUE: $otp');

      if (otp.length != 4 || !RegExp(r'^\d{4}$').hasMatch(otp)) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر إنشاء رمز التسليم')));
        return;
      }

      if (!mounted) return;

      setState(() {
        _otpByOrder[orderId] = otp;
      });
    } catch (error, stackTrace) {
      debugPrint('HENA OTP ERROR: $error');
      debugPrint('HENA OTP STACK: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء رمز التسليم:\n$error')),
      );
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('إلغاء الطلب؟'),
          content: const Text(
            'هل تريد إلغاء هذا الطلب؟\n\n'
            'يمكن إلغاء الطلب خلال أول 90 ثانية من إنشائه.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB42318),
              ),
              child: const Text('إلغاء الطلب'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) {
      return;
    }

    final user = _client.auth.currentUser;

    if (user == null) {
      _showOrderMessage('يجب تسجيل الدخول لإلغاء الطلب.');
      return;
    }

    try {
      final response = await _client
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId)
          .eq('customer_id', user.id)
          .select('id,status')
          .maybeSingle();

      if (!mounted) {
        return;
      }

      if (response == null) {
        _showOrderMessage('  .    90      .');
        await _loadOrders(silent: true);
        return;
      }

      await _loadOrders(silent: true);

      if (!mounted) {
        return;
      }

      _showOrderMessage('تم إلغاء الطلب بنجاح.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showOrderMessage('تعذر إلغاء الطلب:\n$error');
    }
  }

  void _showOrderMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editOrder(String orderId) async {
    if (orderId.trim().isEmpty) {
      _showOrderMessage('رقم الطلب غير صالح.');
      return;
    }

    final orderIndex = _orders.indexWhere(
      (order) => order['id']?.toString() == orderId,
    );

    if (orderIndex < 0) {
      _showOrderMessage('تعذر العثور على الطلب.');
      return;
    }

    final order = _orders[orderIndex];
    final rawItems = order['order_items'];

    if (rawItems is! List || rawItems.isEmpty) {
      _showOrderMessage('       .');
      return;
    }

    final items = rawItems
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final quantities = <int, double>{};

    for (var index = 0; index < items.length; index++) {
      quantities[index] = double.tryParse('${items[index]['quantity']}') ?? 0;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final visibleIndexes = <int>[];

            for (var index = 0; index < items.length; index++) {
              if ((quantities[index] ?? 0) > 0) {
                visibleIndexes.add(index);
              }
            }

            final canSave = visibleIndexes.isNotEmpty;

            return AlertDialog(
              title: const Text('تعديل الطلب'),
              content: SizedBox(
                width: double.maxFinite,
                child: visibleIndexes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('        .', textAlign: TextAlign.center),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: visibleIndexes.length,
                        separatorBuilder: (_, _) => const Divider(height: 20),
                        itemBuilder: (context, position) {
                          final index = visibleIndexes[position];
                          final item = items[index];
                          final quantity = quantities[index] ?? 1;

                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['product_name']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item['unit_price']} جنيه',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '',
                                onPressed: quantity <= 1
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          quantities[index] = quantity - 1;
                                        });
                                      },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                quantity % 1 == 0
                                    ? quantity.toInt().toString()
                                    : quantity.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              IconButton(
                                tooltip: '',
                                onPressed: () {
                                  setDialogState(() {
                                    quantities[index] = quantity + 1;
                                  });
                                },
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              IconButton(
                                tooltip: '',
                                onPressed: () {
                                  setDialogState(() {
                                    quantities[index] = 0;
                                  });
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('رجوع'),
                ),
                FilledButton(
                  onPressed: canSave
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text(' '),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) {
      return;
    }

    final editedItems = <Map<String, dynamic>>[];

    for (var index = 0; index < items.length; index++) {
      final quantity = quantities[index] ?? 0;

      if (quantity <= 0) {
        continue;
      }

      final item = items[index];

      final storeId = item['store_id']?.toString();
      final productId = item['product_id']?.toString();
      final pricingId = item['pricing_id']?.toString();

      if (storeId == null ||
          storeId.isEmpty ||
          productId == null ||
          productId.isEmpty ||
          pricingId == null ||
          pricingId.isEmpty) {
        _showOrderMessage('    .      .');
        return;
      }

      final payload = <String, dynamic>{
        'store_id': storeId,
        'product_id': productId,
        'pricing_id': pricingId,
        'quantity': quantity,
      };

      final offerId = item['offer_id']?.toString();

      if (offerId != null && offerId.isNotEmpty) {
        payload['offer_id'] = offerId;
      }

      editedItems.add(payload);
    }

    if (editedItems.isEmpty) {
      _showOrderMessage('يجب أن يحتوي الطلب على منتج واحد على الأقل.');
      return;
    }

    try {
      final response = await _client.rpc(
        'edit_unified_order',
        params: {'p_order_id': orderId, 'p_items': editedItems},
      );

      if (!mounted) {
        return;
      }

      await _loadOrders(silent: true);

      if (!mounted) {
        return;
      }

      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};

      final number = data['unified_order_number']?.toString();

      _showOrderMessage(
        number != null && number.isNotEmpty ? '   $number .' : '   .',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showOrderMessage('تعذر تحديث الطلب:\n$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        appBar: AppBar(
          title: const Text(
            'طلباتي',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFF7FAF8),
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              tooltip: '',
              onSelected: (value) async {
                if (value != 'logout') return;

                await FcmService.instance.unregisterCurrentToken();
                await _client.auth.signOut();
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded),
                      SizedBox(width: 10),
                      Text(' ', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(onRefresh: _loadOrders, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && _orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 150),
          Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFF087A4B)),
          SizedBox(height: 16),
          Center(
            child: Text(
              '    .',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Text('    .', style: TextStyle(color: Colors.black54)),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _SectionHeader(
          title: 'متابعة الطلبات',
          subtitle: 'تابع حالة طلبك وتفاصيل التوصيل هنا',
        ),
        const SizedBox(height: 14),
        ..._orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _OrderInvoiceCard(
              order: order,
              otp: _otpByOrder[order['id']?.toString()],
              driverContact: _driverContactByOrder[order['id']?.toString()],
              onRequestOtp: () => _loadOtp(order['id'].toString()),
              countdownNow: _countdownNow,
              onCancelOrder: () => _cancelOrder(order['id'].toString()),
              onEditOrder: () => _editOrder(order['id']?.toString() ?? ''),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class _OrderInvoiceCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String? otp;
  final Map<String, dynamic>? driverContact;
  final VoidCallback onRequestOtp;
  final DateTime countdownNow;
  final VoidCallback onCancelOrder;
  final VoidCallback onEditOrder;

  const _OrderInvoiceCard({
    required this.order,
    required this.otp,
    required this.driverContact,
    required this.onRequestOtp,
    required this.countdownNow,
    required this.onCancelOrder,
    required this.onEditOrder,
  });

  Duration _editWindowRemaining({
    required String status,
    required DateTime? createdAt,
    required DateTime now,
  }) {
    if (status != 'pending' || createdAt == null) {
      return Duration.zero;
    }

    final expiresAt = createdAt.add(const Duration(seconds: 90));
    final remaining = expiresAt.difference(now);

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  @override
  Widget build(BuildContext context) {
    final orderId = order['id']?.toString() ?? '';
    final number =
        order['unified_order_number']?.toString().trim().isNotEmpty == true
        ? order['unified_order_number'].toString()
        : orderId;

    final status = order['status']?.toString() ?? 'pending';

    final items = (order['order_items'] is List)
        ? (order['order_items'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
        : <Map<String, dynamic>>[];

    final subtotal = _toDouble(order['subtotal']);
    final delivery = _toDouble(order['delivery_fee']);
    final extraFee = _toDouble(order['extra_fee']);
    final total = _toDouble(order['total']);

    final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');

    final editWindowRemaining = _editWindowRemaining(
      status: status,
      createdAt: createdAt,
      now: countdownNow,
    );

    final showEditWindow = editWindowRemaining > Duration.zero;

    final showOtp = status == 'out_for_delivery';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE3EAE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF087A4B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ' #$number',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 18),
            _StatusTimeline(status: status),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text(
              ' ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('    .', style: TextStyle(color: Colors.black54))
            else
              ...items.map((item) => _InvoiceItemRow(item: item)),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _PriceRow(label: 'قيمة المنتجات', value: subtotal),
            _PriceRow(label: 'رسوم التوصيل', value: delivery),
            if (extraFee > 0) _PriceRow(label: 'رسوم إضافية', value: extraFee),
            const SizedBox(height: 5),
            _PriceRow(label: 'الإجمالي', value: total, emphasized: true),
            const SizedBox(height: 16),
            _DeliveryInfo(order: order),
            if (driverContact != null) ...[
              const SizedBox(height: 16),
              _DriverContactCard(
                name: driverContact!['full_name']?.toString() ?? '',
                phone: driverContact!['phone']?.toString() ?? '',
              ),
            ],
            if (showEditWindow) ...[
              const SizedBox(height: 16),
              _OrderEditWindowCard(
                remaining: editWindowRemaining,
                onCancelOrder: onCancelOrder,
                onEditOrder: onEditOrder,
              ),
            ],
            if (showOtp) ...[
              const SizedBox(height: 16),
              _OtpCard(otp: otp, onRequestOtp: onRequestOtp),
            ],
            if (status == 'delivered') ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF168957)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '   .    .',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'التاريخ غير متاح';

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'م' : 'ص';

    return '$day/$month/$year  $hour:$minute $period';
  }
}

class _OrderEditWindowCard extends StatelessWidget {
  final Duration remaining;
  final VoidCallback onCancelOrder;
  final VoidCallback onEditOrder;

  const _OrderEditWindowCard({
    required this.remaining,
    required this.onCancelOrder,
    required this.onEditOrder,
  });

  @override
  Widget build(BuildContext context) {
    final totalSeconds = remaining.inSeconds.clamp(0, 90).toInt();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    final timeText =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D9A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9BE),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: Color(0xFFB66A00),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  ' 90     ',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                timeText,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFB66A00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '        .',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditOrder,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تعديل الطلب'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCancelOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFB42318),
                  ),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('إلغاء الطلب'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceItemRow extends StatelessWidget {
  final Map<String, dynamic> item;

  const _InvoiceItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['product_name']?.toString() ?? '';
    final quantity = _toDouble(item['quantity']);
    final unitPrice = _toDouble(item['unit_price']);
    final total = _toDouble(item['item_total']);

    final sellingMethod = item['selling_method']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 20,
              color: Color(0xFF087A4B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  '${_formatQuantity(quantity)} \u00D7 ${unitPrice.toStringAsFixed(2)} \u062C.\u0645'
                  '${sellingMethod != null && sellingMethod.isNotEmpty ? '  $sellingMethod' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${total.toStringAsFixed(2)} جنيه',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasized;

  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} جنيه',
            style: TextStyle(
              fontSize: emphasized ? 17 : 14,
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
              color: emphasized ? const Color(0xFF087A4B) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryInfo extends StatelessWidget {
  final Map<String, dynamic> order;

  const _DeliveryInfo({required this.order});

  @override
  Widget build(BuildContext context) {
    final recipient = order['delivery_recipient_name']?.toString().trim() ?? '';
    final phone = order['delivery_phone']?.toString().trim() ?? '';

    final address =
        [
              order['delivery_governorate'],
              order['delivery_city'],
              order['delivery_area'],
              order['delivery_building_number'],
              order['delivery_apartment_number'],
              order['delivery_address_details'],
            ]
            .map((value) => value?.toString().trim())
            .where((value) => value != null && value.isNotEmpty)
            .join(' ');

    if (recipient.isEmpty && phone.isEmpty && address.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(' ', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (recipient.isNotEmpty)
            _InfoLine(icon: Icons.person_outline_rounded, text: recipient),
          if (phone.isNotEmpty)
            _InfoLine(icon: Icons.phone_outlined, text: phone),
          if (address.isNotEmpty)
            _InfoLine(icon: Icons.location_on_outlined, text: address),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF087A4B)),
          const SizedBox(width: 7),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final data = _statusData(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: data.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 16, color: data.foreground),
          const SizedBox(width: 5),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: data.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String status;

  const _StatusTimeline({required this.status});

  static const _steps = [
    ('pending', 'قيد المراجعة'),
    ('preparing', 'جارٍ تجهيز الطلب'),
    ('ready', 'جاهز للاستلام'),
    ('picked_up', 'تم استلام الطلب'),
    ('out_for_delivery', 'في الطريق إليك'),
    ('delivered', 'تم التسليم'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _timelineIndex(status);

    return Column(
      children: List.generate(_steps.length, (index) {
        final step = _steps[index];
        final active = currentIndex >= index;
        final isLast = index == _steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? const Color(0xFF168957)
                        : const Color(0xFFE0E7E3),
                  ),
                  child: active
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 26,
                    color: currentIndex > index
                        ? const Color(0xFF8AC7AA)
                        : const Color(0xFFE0E7E3),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Text(
                step.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? Colors.black87 : Colors.black45,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  static int _timelineIndex(String status) {
    switch (status) {
      case 'pending':
      case 'confirmed':
        return 0;
      case 'preparing':
        return 1;
      case 'ready':
      case 'assigned':
        return 2;
      case 'picked_up':
        return 3;
      case 'out_for_delivery':
        return 4;
      case 'delivered':
        return 5;
      case 'cancelled':
        return 0;
      default:
        return 0;
    }
  }
}

class _OtpCard extends StatelessWidget {
  final String? otp;
  final VoidCallback onRequestOtp;

  const _OtpCard({required this.otp, required this.onRequestOtp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2D6AA)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 30,
            color: Color(0xFFB66A00),
          ),
          const SizedBox(height: 8),
          const Text(
            '  ',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'اعرض هذا الرمز على مندوب التوصيل عند استلام الطلب.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (otp == null)
            FilledButton.icon(
              onPressed: onRequestOtp,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB66A00),
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('عرض رمز الاستلام'),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                otp!,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: Color(0xFFB66A00),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusData {
  final String label;
  final Color foreground;
  final Color background;
  final IconData icon;

  const _StatusData({
    required this.label,
    required this.foreground,
    required this.background,
    required this.icon,
  });
}

_StatusData _statusData(String status) {
  switch (status) {
    case 'pending':
      return const _StatusData(
        label: 'في الطريق إليك',
        foreground: Color(0xFF386A58),
        background: Color(0xFFE7F4EE),
        icon: Icons.schedule_rounded,
      );
    case 'confirmed':
      return const _StatusData(
        label: 'جاهز للاستلام',
        foreground: Color(0xFF386A58),
        background: Color(0xFFE7F4EE),
        icon: Icons.check_circle_outline_rounded,
      );
    case 'preparing':
      return const _StatusData(
        label: 'جارٍ تجهيز الطلب',
        foreground: Color(0xFF206E9B),
        background: Color(0xFFE7F1F9),
        icon: Icons.inventory_2_outlined,
      );
    case 'ready':
      return const _StatusData(
        label: 'جاهز للاستلام',
        foreground: Color(0xFF168957),
        background: Color(0xFFE7F5ED),
        icon: Icons.store_mall_directory_outlined,
      );
    case 'assigned':
      return const _StatusData(
        label: 'تم تأكيد الطلب',
        foreground: Color(0xFF5A5C9A),
        background: Color(0xFFEDEDFC),
        icon: Icons.person_pin_circle_outlined,
      );
    case 'picked_up':
      return const _StatusData(
        label: 'تم التسليم',
        foreground: Color(0xFF5A5C9A),
        background: Color(0xFFEDEDFC),
        icon: Icons.inventory_outlined,
      );
    case 'out_for_delivery':
      return const _StatusData(
        label: 'تم تعيين مندوب التوصيل',
        foreground: Color(0xFFB66A00),
        background: Color(0xFFFFF1DD),
        icon: Icons.local_shipping_outlined,
      );
    case 'delivered':
      return const _StatusData(
        label: 'تم التسليم',
        foreground: Color(0xFF168957),
        background: Color(0xFFE7F5ED),
        icon: Icons.check_circle_rounded,
      );
    case 'cancelled':
      return const _StatusData(
        label: 'في الطريق إليك',
        foreground: Color(0xFFA33D3D),
        background: Color(0xFFFBEAEA),
        icon: Icons.cancel_outlined,
      );
    default:
      return const _StatusData(
        label: 'قيد المراجعة',
        foreground: Color(0xFF386A58),
        background: Color(0xFFE7F4EE),
        icon: Icons.sync_rounded,
      );
  }
}

class _DriverContactCard extends StatelessWidget {
  final String name;
  final String phone;

  const _DriverContactCard({required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD4E6F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (phone.isNotEmpty)
            IconButton(
              tooltip: 'الاتصال بالمندوب',
              icon: const Icon(Icons.phone_rounded, color: Color(0xFF168957)),
              onPressed: () async {
                final uri = Uri(scheme: 'tel', path: phone);

                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (error) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر فتح تطبيق الاتصال.')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
