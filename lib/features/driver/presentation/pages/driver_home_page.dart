import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../checkout/domain/entities/order.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/presentation/providers/notifications_providers.dart';
import '../../presentation/providers/driver_providers.dart';
import 'driver_account_page.dart';
import 'driver_earnings_page.dart';
import 'driver_order_details_page.dart';

final driverCompletedTodayProvider = FutureProvider.autoDispose<List<Order>>((
  ref,
) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) {
    throw StateError('لا توجد جلسة دخول حالية.');
  }

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final startOfNextDay = startOfDay.add(const Duration(days: 1));

  final startUtc = startOfDay.toUtc().toIso8601String();
  final endUtc = startOfNextDay.toUtc().toIso8601String();

  final response = await client
      .from('orders')
      .select(
        'id,unified_order_number,customer_id,store_id,driver_id,status,subtotal,'
        'delivery_fee,extra_fee,total,customer_notes,delivery_points,'
        'delivery_recipient_name,delivery_phone,delivery_governorate,'
        'delivery_city,delivery_area,delivery_building_number,'
        'delivery_apartment_number,delivery_address_details,created_at,updated_at,'
        'order_items('
        'id,order_id,store_id,product_id,pricing_id,offer_id,product_name,'
        'unit_price,quantity,selling_method,item_total'
        '),'
        'payments(payment_method,status),'
        'order_store_parts(id,store_id,status)'
      )
      .eq('driver_id', user.id)
      .eq('status', 'delivered')
      .gte('updated_at', startUtc)
      .lt('updated_at', endUtc)
      .order('updated_at', ascending: false);

  final rows = List<Map<String, dynamic>>.from(response);

  return rows.map(_completedOrderFromMap).toList();
});

final driverInProgressOrdersProvider =
    FutureProvider.autoDispose<List<Order>>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) {
    throw StateError('لا توجد جلسة دخول حالية.');
  }

  final response = await client
      .from('orders')
      .select(
        'id,unified_order_number,customer_id,store_id,driver_id,status,subtotal,'
        'delivery_fee,extra_fee,total,customer_notes,delivery_points,'
        'delivery_recipient_name,delivery_phone,delivery_governorate,'
        'delivery_city,delivery_area,delivery_building_number,'
        'delivery_apartment_number,delivery_address_details,created_at,'
        'order_items('
        'id,order_id,store_id,product_id,pricing_id,offer_id,product_name,'
        'unit_price,quantity,selling_method,item_total'
        '),'
        'payments(payment_method,status),'
        'order_store_parts(id,store_id,status)'
      )
      .eq('driver_id', user.id)
      .inFilter('status', ['assigned', 'picked_up', 'out_for_delivery'])
      .order('created_at', ascending: true);

  final rows = List<Map<String, dynamic>>.from(response);
  return rows.map(_inProgressOrderFromMap).toList();
});

Order _inProgressOrderFromMap(Map<String, dynamic> row) {
  final payments = row['payments'];
  Map<String, dynamic>? payment;

  if (payments is List && payments.isNotEmpty) {
    payment = Map<String, dynamic>.from(payments.first as Map);
  } else if (payments is Map) {
    payment = Map<String, dynamic>.from(payments);
  }

  final rawItems = row['order_items'];
  final items = rawItems is List
      ? rawItems
            .whereType<Map>()
            .map(
              (item) => OrderItem(
                id: item['id'] as String,
                orderId: item['order_id'] as String,
                storeId: item['store_id'] as String?,
                productId: item['product_id'] as String,
                pricingId: item['pricing_id'] as String,
                offerId: item['offer_id'] as String?,
                productName: item['product_name'] as String? ?? 'منتج',
                pricingName: null,
                sellingMethod: item['selling_method'] as String? ?? 'unit',
                quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
                unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
                totalPrice: (item['item_total'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList()
      : <OrderItem>[];

  return Order(
    id: row['id'] as String,
    unifiedOrderNumber: row['unified_order_number'] as String?,
    createdAt: DateTime.tryParse(row['created_at'].toString()),
    userId: row['customer_id'] as String,
    storeId: row['store_id'] as String?,
    driverId: row['driver_id'] as String?,
    status: _orderStatusFromDb(row['status'] as String? ?? 'assigned'),
    paymentMethod: _paymentMethodFromDb(payment?['payment_method'] as String?),
    paymentStatus: _paymentStatusFromDb(payment?['status'] as String?),
    subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
    deliveryFee: (row['delivery_fee'] as num?)?.toDouble() ?? 0,
    totalAmount: (row['total'] as num?)?.toDouble() ?? 0,
    deliveryAddressId: null,
    deliveryRecipientName:
        row['delivery_recipient_name'] as String? ?? 'العميل',
    deliveryPhone: row['delivery_phone'] as String? ?? '',
    deliveryAddress: _buildAddress(row),
    customerNote: row['customer_notes'] as String?,
    items: items,
  );
}

OrderStatus _orderStatusFromDb(String value) {
  switch (value) {
    case 'confirmed':
      return OrderStatus.confirmed;
    case 'preparing':
      return OrderStatus.preparing;
    case 'ready':
      return OrderStatus.ready;
    case 'assigned':
      return OrderStatus.assigned;
    case 'picked_up':
      return OrderStatus.pickedUp;
    case 'out_for_delivery':
      return OrderStatus.outForDelivery;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'pending':
    default:
      return OrderStatus.pending;
  }
}

Order _completedOrderFromMap(Map<String, dynamic> row) {
  final payments = row['payments'];
  Map<String, dynamic>? payment;

  if (payments is List && payments.isNotEmpty) {
    payment = Map<String, dynamic>.from(payments.first as Map);
  } else if (payments is Map) {
    payment = Map<String, dynamic>.from(payments);
  }

  final rawItems = row['order_items'];

  final items = rawItems is List
      ? rawItems
            .whereType<Map>()
            .map(
              (item) => OrderItem(
                id: item['id'] as String,
                orderId: item['order_id'] as String,
                storeId: item['store_id'] as String?,
                productId: item['product_id'] as String,
                pricingId: item['pricing_id'] as String,
                offerId: item['offer_id'] as String?,
                productName: item['product_name'] as String? ?? 'منتج',
                pricingName: null,
                sellingMethod: item['selling_method'] as String? ?? 'unit',
                quantity: (item['quantity'] as num?)?.toDouble() ?? 0,
                unitPrice: (item['unit_price'] as num?)?.toDouble() ?? 0,
                totalPrice: (item['item_total'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList()
      : <OrderItem>[];

  return Order(
    id: row['id'] as String,
    unifiedOrderNumber: row['unified_order_number'] as String?,
    createdAt: DateTime.tryParse(row['created_at'].toString()),
    userId: row['customer_id'] as String,
    storeId: row['store_id'] as String?,
    driverId: row['driver_id'] as String?,
    status: OrderStatus.delivered,
    paymentMethod: _paymentMethodFromDb(payment?['payment_method'] as String?),
    paymentStatus: _paymentStatusFromDb(payment?['status'] as String?),
    subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
    deliveryFee: (row['delivery_fee'] as num?)?.toDouble() ?? 0,
    totalAmount: (row['total'] as num?)?.toDouble() ?? 0,
    deliveryAddressId: null,
    deliveryRecipientName:
        row['delivery_recipient_name'] as String? ?? 'العميل',
    deliveryPhone: row['delivery_phone'] as String? ?? '',
    deliveryAddress: _buildAddress(row),
    customerNote: row['customer_notes'] as String?,
    items: items,
  );
}

PaymentMethod _paymentMethodFromDb(String? value) {
  switch (value) {
    case 'instapay':
      return PaymentMethod.instapay;
    case 'vodafone_cash':
      return PaymentMethod.vodafoneCash;
    case 'cash_on_delivery':
    default:
      return PaymentMethod.cashOnDelivery;
  }
}

PaymentStatus _paymentStatusFromDb(String? value) {
  switch (value) {
    case 'paid':
      return PaymentStatus.paid;
    case 'failed':
      return PaymentStatus.failed;
    case 'refunded':
      return PaymentStatus.refunded;
    case 'pending':
    default:
      return PaymentStatus.pending;
  }
}

String _buildAddress(Map<String, dynamic> row) {
  return [
    row['delivery_governorate'],
    row['delivery_city'],
    row['delivery_area'],
    row['delivery_building_number'],
    row['delivery_apartment_number'],
    row['delivery_address_details'],
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
}

class DriverHomePage extends ConsumerWidget {
  const DriverHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final availabilityAsync = ref.watch(driverAvailabilityControllerProvider);
    final ordersAsync = ref.watch(driverAvailableOrdersProvider);
    final completedTodayAsync = ref.watch(driverCompletedTodayProvider);
    final inProgressAsync = ref.watch(driverInProgressOrdersProvider);

    final profile = profileAsync.value;
    final driverName = profile?['full_name'] as String? ?? 'السائق';
    final avatarPath = profile?['avatar_url'] as String?;
    final isAvailable = availabilityAsync.value ?? true;
    final ordersCount = ordersAsync.value?.length ?? 0;
    final completedOrders = completedTodayAsync.value ?? <Order>[];
    final completedTodayCount = completedOrders.length;
    final collectedToday = completedOrders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount,
    );
    final inProgressCount = inProgressAsync.value?.length ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData(
          useMaterial3: true,
          fontFamily: 'Cairo',
          scaffoldBackgroundColor: const Color(0xFFF8FBF9),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF19A66A)),
        ),
        child: DefaultTabController(
          length: 3,
          child: Scaffold(
            body: SafeArea(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: _DriverTopSection(
                        driverName: driverName,
                        avatarPath: avatarPath,
                        isAvailable: isAvailable,
                        ordersCount: ordersCount,
                        completedTodayCount: completedTodayCount,
                        collectedToday: collectedToday,
                        inProgressCount: inProgressCount,
                        onAvailabilityChanged: (value) {
                          ref
                              .read(
                                driverAvailabilityControllerProvider.notifier,
                              )
                              .setAvailability(value);
                        },
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _DriverTabsDelegate(),
                    ),
                  ];
                },
                body: TabBarView(
                  children: [
                    _OrdersTab(ordersAsync: ordersAsync),
                    _InProgressTab(ordersAsync: inProgressAsync),
                    _CompletedTodayTab(ordersAsync: completedTodayAsync),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: const _DriverBottomNavigationBar(),
          ),
        ),
      ),
    );
  }
}

class _DriverTopSection extends StatelessWidget {
  const _DriverTopSection({
    required this.driverName,
    required this.avatarPath,
    required this.isAvailable,
    required this.ordersCount,
    required this.completedTodayCount,
    required this.collectedToday,
    required this.inProgressCount,
    required this.onAvailabilityChanged,
  });

  final String driverName;
  final String? avatarPath;
  final bool isAvailable;
  final int ordersCount;
  final int completedTodayCount;
  final double collectedToday;
  final int inProgressCount;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8FFF2), Color(0xFFF7FFFA)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5F2E2),
                  borderRadius: BorderRadius.circular(30),
                ),
                clipBehavior: Clip.antiAlias,
                child: _DriverHomeAvatar(avatarPath: avatarPath),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hena',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF073D35),
                      ),
                    ),
                    Text(
                      'كل احتياجاتك.. في مكان واحد',
                      style: TextStyle(fontSize: 11, color: Color(0xFF38675B)),
                    ),
                  ],
                ),
              ),
              Consumer(
                builder: (context, ref, child) {
                  final unreadCount = ref.watch(
                    unreadNotificationsCountProvider,
                  );

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: .82),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );
                          },
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFF073D35),
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 21,
                              minHeight: 21,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'مرحبًا $driverName',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF073D35),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'نتمنى لك يومًا موفقًا في التوصيل',
              style: TextStyle(
                fontSize: 17,
                color: Color(0xFF17744F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: isAvailable ? const Color(0xFF16B86A) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حالتك الآن',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF52665D),
                        ),
                      ),
                      Text(
                        isAvailable
                            ? 'جاهز لاستقبال الطلبات'
                            : 'غير متاح لاستقبال الطلبات',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isAvailable
                              ? const Color(0xFF168957)
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isAvailable,
                  activeThumbColor: const Color(0xFF18A66B),
                  onChanged: onAvailabilityChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _StatisticCard(
                title: 'طلبات اليوم',
                value: '$ordersCount',
                subtitle: 'طلب',
                icon: Icons.assignment_rounded,
                background: const Color(0xFFE8F4FF),
                iconColor: const Color(0xFF2995E5),
              ),
              const SizedBox(width: 8),
              _StatisticCard(
                title: 'تم إنجازه',
                value: '$completedTodayCount',
                subtitle: 'طلب',
                icon: Icons.check_circle_rounded,
                background: const Color(0xFFE7F9EE),
                iconColor: const Color(0xFF16A66A),
              ),
              const SizedBox(width: 8),
              _StatisticCard(
                title: 'جاري التوصيل',
                value: '$inProgressCount',
                subtitle: 'طلب',
                icon: Icons.local_shipping_rounded,
                background: Color(0xFFFFF4DF),
                iconColor: Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatisticCard(
            title: 'إجمالي المحصل',
            value: collectedToday.toStringAsFixed(2),
            subtitle: 'ج.م',
            icon: Icons.account_balance_wallet_rounded,
            background: Color(0xFFE7F9EE),
            iconColor: Color(0xFF16A66A),
            expanded: true,
          ),
        ],
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.iconColor,
    this.expanded = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color background;
  final Color iconColor;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final card = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 140.0;

        final iconBoxSize = width < 110 ? 34.0 : 42.0;
        final iconSize = width < 110 ? 20.0 : 25.0;
        final titleSize = width < 110 ? 10.0 : 12.0;
        final valueSize = width < 110 ? 20.0 : 23.0;
        final subtitleSize = width < 110 ? 10.0 : 12.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: width < 110 ? 6 : 10,
            vertical: width < 110 ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: iconSize),
              ),
              SizedBox(height: width < 110 ? 5 : 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: width < 110 ? 2 : 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  maxLines: 1,
                  style: TextStyle(fontSize: subtitleSize),
                ),
              ),
            ],
          ),
        );
      },
    );

    return expanded ? card : Expanded(child: card);
  }
}

class _DriverTabsDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 50;

  @override
  double get maxExtent => 50;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF8FBF9),
      child: const TabBar(
        indicatorColor: Color(0xFF18A66B),
        indicatorWeight: 4,
        labelColor: Color(0xFF168957),
        unselectedLabelColor: Color(0xFF526477),
        labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        tabs: [
          Tab(text: 'الطلبات الجديدة'),
          Tab(text: 'جاري التوصيل'),
          Tab(text: 'تم إنجازه اليوم'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.ordersAsync});

  final AsyncValue<List<Order>> ordersAsync;

  @override
  Widget build(BuildContext context) {
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'حدث خطأ أثناء تحميل الطلبات\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const _SimpleEmptyTab(
            title: 'لا توجد طلبات جديدة',
            subtitle: 'ستظهر هنا الطلبات الجاهزة للاستلام',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _OrderCard(order: orders[index]);
          },
        );
      },
    );
  }
}

class _InProgressTab extends ConsumerWidget {
  const _InProgressTab({required this.ordersAsync});

  final AsyncValue<List<Order>> ordersAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'حدث خطأ أثناء تحميل الطلبات قيد التوصيل\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const _SimpleEmptyTab(
            title: 'لا توجد طلبات قيد التوصيل',
            subtitle: 'ستظهر هنا الطلبات التي استلمتها وتعمل على توصيلها',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverInProgressOrdersProvider);
            await ref.read(driverInProgressOrdersProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _InProgressOrderCard(order: orders[index]);
            },
          ),
        );
      },
    );
  }
}

class _InProgressOrderCard extends ConsumerWidget {
  const _InProgressOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeIds = order.items
        .map((item) => item.storeId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final storeCount = storeIds.isEmpty
        ? (order.storeId == null ? 0 : 1)
        : storeIds.length;

    final statusText = switch (order.status) {
      OrderStatus.assigned => 'تم استلام الطلب',
      OrderStatus.pickedUp => 'تم استلام أجزاء من الطلب',
      OrderStatus.outForDelivery => 'في الطريق',
      _ => 'قيد التوصيل',
    };

    final statusColor = switch (order.status) {
      OrderStatus.outForDelivery => const Color(0xFF168957),
      OrderStatus.pickedUp => const Color(0xFFF59E0B),
      _ => const Color(0xFF168FE0),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openDriverOrderDetails(context, ref, order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.unifiedOrderNumber ?? order.id,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
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
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF168957)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.deliveryRecipientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.store_outlined, color: Color(0xFF168957)),
                const SizedBox(width: 7),
                Text('المتاجر: $storeCount'),
                const SizedBox(width: 14),
                const Icon(
                  Icons.shopping_basket_outlined,
                  color: Color(0xFF168957),
                ),
                const SizedBox(width: 6),
                Text('المنتجات: ${order.items.length}'),
                const Spacer(),
                Text(
                  '${order.totalAmount.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DriverProductsPreview(items: order.items),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                order.deliveryAddress.isEmpty
                    ? 'العنوان غير مكتمل'
                    : order.deliveryAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF607D72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedTodayTab extends ConsumerWidget {
  const _CompletedTodayTab({required this.ordersAsync});

  final AsyncValue<List<Order>> ordersAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'حدث خطأ أثناء تحميل الطلبات المكتملة اليوم\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (orders) {
        if (orders.isEmpty) {
          return const _SimpleEmptyTab(
            title: 'لم يتم إنجاز أي طلب اليوم',
            subtitle: 'ستظهر هنا الطلبات التي تم تسليمها اليوم',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(driverCompletedTodayProvider);
            await ref.read(driverCompletedTodayProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _CompletedOrderCard(order: orders[index]);
            },
          ),
        );
      },
    );
  }
}

class _CompletedOrderCard extends ConsumerWidget {
  const _CompletedOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeIds = order.items
        .map((item) => item.storeId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final storeCount = storeIds.isEmpty
        ? (order.storeId == null ? 0 : 1)
        : storeIds.length;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openDriverOrderDetails(context, ref, order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.unifiedOrderNumber ?? order.id,
                    style: const TextStyle(
                      color: Color(0xFF168957),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F9EE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'تم التسليم',
                    style: TextStyle(
                      color: Color(0xFF168957),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF168957)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.deliveryRecipientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.store_outlined, color: Color(0xFF168957)),
                const SizedBox(width: 7),
                Text('المتاجر: $storeCount'),
                const SizedBox(width: 14),
                const Icon(
                  Icons.shopping_basket_outlined,
                  color: Color(0xFF168957),
                ),
                const SizedBox(width: 6),
                Text('المنتجات: ${order.items.length}'),
                const Spacer(),
                Text(
                  '${order.totalAmount.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DriverProductsPreview(items: order.items),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                order.deliveryAddress.isEmpty
                    ? 'العنوان غير مكتمل'
                    : order.deliveryAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF607D72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productCount = order.items.length;

    final storeIds = order.items
        .map((item) => item.storeId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final storeCount = storeIds.isEmpty
        ? (order.storeId == null ? 0 : 1)
        : storeIds.length;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openDriverOrderDetails(context, ref, order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.unifiedOrderNumber ?? order.id,
                    style: const TextStyle(
                      color: Color(0xFF168FE0),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'جاهز للشحن',
                    style: TextStyle(
                      color: Color(0xFF168FE0),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF168957)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.deliveryRecipientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(Icons.store_outlined, color: Color(0xFF168957)),
                const SizedBox(width: 8),
                Text(
                  'المتاجر: $storeCount',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.shopping_basket_outlined,
                  color: Color(0xFF168957),
                ),
                const SizedBox(width: 6),
                Text(
                  'المنتجات: $productCount',
                  style: const TextStyle(fontSize: 15),
                ),
                const Spacer(),
                Text(
                  '${order.totalAmount.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DriverProductsPreview(items: order.items),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                order.deliveryAddress.isEmpty
                    ? 'العنوان غير مكتمل'
                    : order.deliveryAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF607D72),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(driverRepositoryProvider)
                        .acceptOrder(orderId: order.id);

                    ref.invalidate(driverAvailableOrdersProvider);
                    ref.invalidate(driverInProgressOrdersProvider);

                    if (!context.mounted) return;

                    final delivered = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => DriverOrderDetailsPage(order: order),
                      ),
                    );

                    if (delivered == true) {
                      ref.invalidate(driverInProgressOrdersProvider);
                      ref.invalidate(driverCompletedTodayProvider);
                    }
                  } catch (error) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر استلام الطلب:\n$error')),
                    );
                  }
                },
                icon: const Icon(Icons.local_shipping_rounded),
                label: const Text('استلام الطلب والبدء'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF19A66A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverProductsPreview extends StatelessWidget {
  const _DriverProductsPreview({required this.items});

  final List<OrderItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'لا توجد تفاصيل منتجات لهذا الطلب.',
          style: TextStyle(color: Color(0xFF718096)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3ECE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 19,
                color: Color(0xFF168957),
              ),
              SizedBox(width: 7),
              Text(
                'محتويات الطلب',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF243447),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: Color(0xFF168957),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF243447),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatQuantity(item.quantity)} × ${item.unitPrice.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF52665D),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
          ),
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

Future<void> _openDriverOrderDetails(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final delivered = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => DriverOrderDetailsPage(order: order),
    ),
  );

  if (delivered == true) {
    ref.invalidate(driverInProgressOrdersProvider);
    ref.invalidate(driverCompletedTodayProvider);
    ref.invalidate(driverAvailableOrdersProvider);
  }
}

class _SimpleEmptyTab extends StatelessWidget {
  const _SimpleEmptyTab({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverBottomNavigationBar extends StatelessWidget {
  const _DriverBottomNavigationBar();

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE5F8EE),
      onDestinationSelected: (index) {
        if (index == 1) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DriverEarningsPage()));
        } else if (index == 2) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const DriverAccountPage()));
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'أرباحي',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'حسابي',
        ),
      ],
    );
  }
}

class _DriverHomeAvatar extends StatelessWidget {
  const _DriverHomeAvatar({required this.avatarPath});

  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    if (avatarPath == null || avatarPath!.trim().isEmpty) {
      return const Icon(Icons.person, size: 36, color: Color(0xFF168957));
    }

    return FutureBuilder<String>(
      future: Supabase.instance.client.storage
          .from('driver-avatars')
          .createSignedUrl(avatarPath!, 3600),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 58,
            height: 58,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF168957),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return Image.network(
            snapshot.data!,
            width: 58,
            height: 58,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.person,
                size: 36,
                color: Color(0xFF168957),
              );
            },
          );
        }

        return const Icon(Icons.person, size: 36, color: Color(0xFF168957));
      },
    );
  }
}
