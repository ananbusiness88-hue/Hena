import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final driverEarningsProvider = FutureProvider.autoDispose<DriverEarnings>((
  ref,
) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) {
    throw StateError('    .');
  }

  final rows = await client
      .from('orders')
      .select(
        'id,unified_order_number,created_at,status,driver_id,'
        'order_store_parts(id,store_id)',
      )
      .eq('driver_id', user.id)
      .eq('status', 'delivered')
      .order('created_at', ascending: false);

  final orders = List<Map<String, dynamic>>.from(rows);

  double driverTotal = 0;
  double henaTotal = 0;

  final items = <DriverEarningItem>[];

  for (final order in orders) {
    final rawParts = order['order_store_parts'];
    final parts = rawParts is List ? rawParts : const [];

    final storeCount = parts.length;

    final driverAmount = storeCount <= 3
        ? 20.0
        : 20.0 + ((storeCount - 3) * 5.0);

    const henaAmount = 5.0;

    driverTotal += driverAmount;
    henaTotal += henaAmount;

    items.add(
      DriverEarningItem(
        orderNumber:
            order['unified_order_number']?.toString() ?? order['id'].toString(),
        storeCount: storeCount,
        driverAmount: driverAmount,
        henaAmount: henaAmount,
        createdAt: DateTime.tryParse(order['created_at']?.toString() ?? ''),
      ),
    );
  }

  return DriverEarnings(
    orderCount: orders.length,
    driverTotal: driverTotal,
    henaTotal: henaTotal,
    items: items,
  );
});

class DriverEarnings {
  final int orderCount;
  final double driverTotal;
  final double henaTotal;
  final List<DriverEarningItem> items;

  const DriverEarnings({
    required this.orderCount,
    required this.driverTotal,
    required this.henaTotal,
    required this.items,
  });
}

class DriverEarningItem {
  final String orderNumber;
  final int storeCount;
  final double driverAmount;
  final double henaAmount;
  final DateTime? createdAt;

  const DriverEarningItem({
    required this.orderNumber,
    required this.storeCount,
    required this.driverAmount,
    required this.henaAmount,
    required this.createdAt,
  });
}

class DriverEarningsPage extends ConsumerWidget {
  const DriverEarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(driverEarningsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBF9),
        appBar: AppBar(
          title: const Text('أرباحي',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: earningsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 52,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 12),
                  const Text('تعذر تحميل الأرباح',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.invalidate(driverEarningsProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(driverEarningsProvider);
                await ref.read(driverEarningsProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _MainEarningsCard(
                    amount: data.driverTotal,
                    orders: data.orderCount,
                  ),
                  const SizedBox(height: 14),
                  _HenaDueCard(
                    amount: data.henaTotal,
                    orderCount: data.orderCount,
                  ),
                  const SizedBox(height: 20),
                  const Text('تفاصيل الطلبات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  if (data.items.isEmpty)
                    const _EmptyEarnings()
                  else
                    ...data.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EarningOrderCard(item: item),
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
}

class _MainEarningsCard extends StatelessWidget {
  final double amount;
  final int orders;

  const _MainEarningsCard({required this.amount, required this.orders});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE4F8EC), Color(0xFFF5FFFA)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_rounded,
            size: 44,
            color: Color(0xFF159B68),
          ),
          const SizedBox(height: 10),
          const Text('إجمالي أرباح التوصيل',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF557067),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${amount.toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0D7D50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$orders طلب',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF557067),
            ),
          ),
        ],
      ),
    );
  }
}

class _HenaDueCard extends StatelessWidget {
  final double amount;
  final int orderCount;

  const _HenaDueCard({required this.amount, required this.orderCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3ECE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2D9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: Color(0xFFE59616),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مستحقات هنا',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'رسوم هنا 5 جنيه لكل طلب',
                      style: TextStyle(color: Color(0xFF71857C), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                '${amount.toStringAsFixed(2)} .',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE08A00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'المبلغ المستحق لهنا: ${amount.toStringAsFixed(2)} ج.م',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A6200),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$orderCount \u0637\u0644\u0628 \u00D7 5 \u062C.\u0645',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8F8B)),
          ),
        ],
      ),
    );
  }
}

class _EarningOrderCard extends StatelessWidget {
  final DriverEarningItem item;

  const _EarningOrderCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF159B68),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.orderNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.storeCount} ${item.storeCount == 1 ? 'متجر واحد' : 'متاجر'}',
                  style: const TextStyle(
                    color: Color(0xFF71857C),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${item.driverAmount.toStringAsFixed(2)} ج.م',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF159B68),
                ),
              ),
              const SizedBox(height: 4),
              const Text('أرباح التوصيل',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A8B83)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: Color(0xFFB5C2BC),
          ),
          SizedBox(height: 12),
          Text('لا توجد أرباح مسجلة حتى الآن.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
