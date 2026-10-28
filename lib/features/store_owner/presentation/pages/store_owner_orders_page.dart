import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/store_order_part.dart';
import '../providers/store_owner_providers.dart';
import 'store_owner_visual_icons.dart';

enum StoreOwnerOrdersSection { newOrders, waitingCourier, today }

class StoreOwnerOrdersPage extends ConsumerWidget {
  final StoreOwnerOrdersSection section;

  const StoreOwnerOrdersPage({super.key, required this.section});

  String get _title {
    switch (section) {
      case StoreOwnerOrdersSection.newOrders:
        return '\u{627}\u{644}\u{637}\u{644}\u{628}\u{627}\u{62A} \u{627}\u{644}\u{62C}\u{62F}\u{64A}\u{62F}\u{629}';
      case StoreOwnerOrdersSection.waitingCourier:
        return '\u{637}\u{644}\u{628}\u{627}\u{62A} \u{628}\u{627}\u{646}\u{62A}\u{638}\u{627}\u{631} \u{627}\u{644}\u{645}\u{646}\u{62F}\u{648}\u{628}';
      case StoreOwnerOrdersSection.today:
        return '\u{637}\u{644}\u{628}\u{627}\u{62A} \u{627}\u{644}\u{64A}\u{648}\u{645}';
    }
  }

  String get _subtitle {
    switch (section) {
      case StoreOwnerOrdersSection.newOrders:
        return '\u{631}\u{627}\u{62C}\u{639} \u{627}\u{644}\u{637}\u{644}\u{628}\u{627}\u{62A} \u{627}\u{644}\u{62C}\u{62F}\u{64A}\u{62F}\u{629} \u{648}\u{627}\u{628}\u{62F}\u{623} \u{62A}\u{62C}\u{647}\u{64A}\u{632}\u{647}\u{627} \u{641}\u{648}\u{631}\u{64B}\u{627}.';
      case StoreOwnerOrdersSection.waitingCourier:
        return '\u{627}\u{644}\u{637}\u{644}\u{628}\u{627}\u{62A} \u{627}\u{644}\u{62C}\u{627}\u{647}\u{632}\u{629} \u{644}\u{627}\u{633}\u{62A}\u{644}\u{627}\u{645} \u{627}\u{644}\u{645}\u{646}\u{62F}\u{648}\u{628}.';
      case StoreOwnerOrdersSection.today:
        return '\u0622\u062E\u0631 48 \u0633\u0627\u0639\u0629 \u2022 \u0644\u0644\u0639\u0631\u0636 \u0641\u0642\u0637';
    }
  }

  HenaOrderIconKind get _iconKind {
    switch (section) {
      case StoreOwnerOrdersSection.newOrders:
        return HenaOrderIconKind.newOrder;
      case StoreOwnerOrdersSection.waitingCourier:
        return HenaOrderIconKind.courier;
      case StoreOwnerOrdersSection.today:
        return HenaOrderIconKind.today;
    }
  }

  List<Color> get _gradient {
    switch (section) {
      case StoreOwnerOrdersSection.newOrders:
        return const [Color(0xFF526CF5), Color(0xFF48B9F4)];
      case StoreOwnerOrdersSection.waitingCourier:
        return const [Color(0xFF20AF8A), Color(0xFF68D69B)];
      case StoreOwnerOrdersSection.today:
        return const [Color(0xFFFF9A57), Color(0xFFFFC765)];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StoreOrderPart>> ordersAsync;

    switch (section) {
      case StoreOwnerOrdersSection.newOrders:
        ordersAsync = ref.watch(storeOwnerNewOrdersProvider);
        break;
      case StoreOwnerOrdersSection.waitingCourier:
        ordersAsync = ref.watch(storeOwnerWaitingCourierProvider);
        break;
      case StoreOwnerOrdersSection.today:
        ordersAsync = ref.watch(storeOwnerTodayOrdersProvider);
        break;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: _gradient.first,
          foregroundColor: Colors.white,
          title: Text(
            _title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ),
        body: RefreshIndicator(
          color: _gradient.first,
          onRefresh: () async {
            switch (section) {
              case StoreOwnerOrdersSection.newOrders:
                ref.invalidate(storeOwnerNewOrdersProvider);
                break;
              case StoreOwnerOrdersSection.waitingCourier:
                ref.invalidate(storeOwnerWaitingCourierProvider);
                break;
              case StoreOwnerOrdersSection.today:
                ref.invalidate(storeOwnerTodayOrdersProvider);
                break;
            }
          },
          child: ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _OrdersError(
              message: '\u{62D}\u{62F}\u{62B} \u{62E}\u{637}\u{623}:\n$error',
              onRetry: () {
                switch (section) {
                  case StoreOwnerOrdersSection.newOrders:
                    ref.invalidate(storeOwnerNewOrdersProvider);
                    break;
                  case StoreOwnerOrdersSection.waitingCourier:
                    ref.invalidate(storeOwnerWaitingCourierProvider);
                    break;
                  case StoreOwnerOrdersSection.today:
                    ref.invalidate(storeOwnerTodayOrdersProvider);
                    break;
                }
              },
              color: _gradient.first,
            ),
            data: (orders) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _SectionHero(
                      title: _title,
                      subtitle: _subtitle,
                      count: orders.length,
                      iconKind: _iconKind,
                      colors: _gradient,
                    ),
                  ),
                  if (section == StoreOwnerOrdersSection.today)
                    SliverToBoxAdapter(
                      child: _TodaySalesSummary(orders: orders),
                    ),
                  if (orders.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyOrders(
                        title: _title,
                        iconKind: _iconKind,
                        color: _gradient.first,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index.isOdd) {
                            return const SizedBox(height: 12);
                          }

                          final part = orders[index ~/ 2];

                          return StoreOwnerOrderCard(
                            part: part,
                            section: section,
                            accentColor: _gradient.first,
                          );
                        }, childCount: orders.length * 2 - 1),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TodaySalesSummary extends StatefulWidget {
  final List<StoreOrderPart> orders;

  const _TodaySalesSummary({required this.orders});

  @override
  State<_TodaySalesSummary> createState() => _TodaySalesSummaryState();
}

class _TodaySalesSummaryState extends State<_TodaySalesSummary> {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);

    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (!mounted) return;

      setState(() {});
      _scheduleMidnightReset();
    });
  }

  bool _isSameLocalDay(DateTime value, DateTime now) {
    final local = value.toLocal();

    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  double _todayTotal() {
    final now = DateTime.now();

    return widget.orders
        .where((part) {
          final createdAt = part.pickedUpAt ?? part.createdAt;

          return createdAt != null && _isSameLocalDay(createdAt, now);
        })
        .fold<double>(0, (sum, part) => sum + part.subtotal);
  }

  int _todaySalesCount() {
    final now = DateTime.now();

    return widget.orders.where((part) {
      final createdAt = part.pickedUpAt ?? part.createdAt;

      return createdAt != null && _isSameLocalDay(createdAt, now);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final total = _todayTotal();
    final count = _todaySalesCount();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE3F7EF), Color(0xFFF6FCF9)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD0EDE1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E9B72),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0E9B72),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u{625}\u{62C}\u{645}\u{627}\u{644}\u{64A} \u{645}\u{628}\u{64A}\u{639}\u{627}\u{62A} \u{627}\u{644}\u{64A}\u{648}\u{645}',
                  style: TextStyle(
                    color: Color(0xFF37665A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${total.toStringAsFixed(2)} \u{62C}.\u{645}',
                  style: const TextStyle(
                    color: Color(0xFF087A4B),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '\u{639}\u{62F}\u{62F} \u{627}\u{644}\u{637}\u{644}\u{628}\u{627}\u{62A}: $count',
                      style: const TextStyle(
                        color: Color(0xFF648177),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF8BBFAE),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '\u{645}\u{646} 12:00 \u{635} \u{625}\u{644}\u{649} 11:59 \u{645}',
                      style: TextStyle(
                        color: Color(0xFF648177),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Color(0xFF0E9B72),
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final HenaOrderIconKind iconKind;
  final List<Color> colors;

  const _SectionHero({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.iconKind,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: .20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: HenaOrderIcon(
                kind: iconKind,
                size: 66,
                foregroundColor: Colors.white,
                accentColor: Colors.white.withValues(alpha: .78),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: .90),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .95),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: colors.first,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreOwnerOrderCard extends StatelessWidget {
  final StoreOrderPart part;
  final StoreOwnerOrdersSection section;
  final Color accentColor;

  const StoreOwnerOrderCard({
    super.key,
    required this.part,
    required this.section,
    required this.accentColor,
  });

  bool get _readOnly => section == StoreOwnerOrdersSection.today;

  @override
  Widget build(BuildContext context) {
    final isNew = part.status == StoreOrderPartStatus.preparing;
    final statusColor = isNew
        ? const Color(0xFF4F7EF7)
        : const Color(0xFF26A57C);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StoreOwnerOrderDetailsPage(
                part: part,
                section: section,
                accentColor: accentColor,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: _readOnly
              ? _TodayOrderLayout(part: part, accentColor: accentColor)
              : _ActiveOrderLayout(
                  part: part,
                  statusColor: statusColor,
                  showAction: true,
                ),
        ),
      ),
    );
  }
}

class _TodayOrderLayout extends StatelessWidget {
  final StoreOrderPart part;
  final Color accentColor;

  const _TodayOrderLayout({required this.part, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '#${part.orderIdLabel}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF233149),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2E6),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                '\u{637}\u{644}\u{628} \u{627}\u{644}\u{64A}\u{648}\u{645}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD67425),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniInfo(
                label:
                    '\u{627}\u{633}\u{645} \u{627}\u{644}\u{639}\u{645}\u{64A}\u{644}',
                value: part.customerName,
                color: const Color(0xFF5275D8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniInfo(
                label:
                    '\u{639}\u{62F}\u{62F} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A}',
                value: '${part.itemCount}',
                color: const Color(0xFF27A47A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MiniInfo(
                label:
                    '\u{642}\u{64A}\u{645}\u{629} \u{627}\u{644}\u{637}\u{644}\u{628}',
                value: '${part.subtotal.toStringAsFixed(2)} \u{62C}.\u{645}',
                color: const Color(0xFFD97A2C),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniInfo(
                label:
                    '\u{631}\u{642}\u{645} \u{627}\u{644}\u{647}\u{627}\u{62A}\u{641}',
                value: part.customerPhone.isEmpty
                    ? '\u{63A}\u{64A}\u{631} \u{645}\u{62A}\u{627}\u{62D}'
                    : part.customerPhone,
                color: const Color(0xFF6A6FA8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _AddressInfo(address: part.deliveryAddress, color: accentColor),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8993A2),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderLayout extends StatelessWidget {
  final StoreOrderPart part;
  final Color statusColor;
  final bool showAction;

  const _ActiveOrderLayout({
    required this.part,
    required this.statusColor,
    required this.showAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(
                child: HenaOrderIcon(
                  kind: part.status == StoreOrderPartStatus.preparing
                      ? HenaOrderIconKind.newOrder
                      : HenaOrderIconKind.courier,
                  size: 34,
                  foregroundColor: statusColor,
                  accentColor: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${part.orderIdLabel}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF233149),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    part.customerName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A8597),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                part.status == StoreOrderPartStatus.preparing
                    ? '\u{642}\u{64A}\u{62F} \u{627}\u{644}\u{62A}\u{62C}\u{647}\u{64A}\u{632}'
                    : '\u{62C}\u{627}\u{647}\u{632} \u{644}\u{644}\u{634}\u{62D}\u{646}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            _ActiveMetric(
              label:
                  '\u{639}\u{62F}\u{62F} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A}',
              value: '${part.itemCount}',
            ),
            const SizedBox(width: 8),
            _ActiveMetric(
              label:
                  '\u{642}\u{64A}\u{645}\u{629} \u{627}\u{644}\u{637}\u{644}\u{628}',
              value: '${part.subtotal.toStringAsFixed(2)} \u{62C}.\u{645}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _AddressInfo(address: part.deliveryAddress, color: statusColor),
        const SizedBox(height: 8),
        _PhoneInfo(phone: part.customerPhone),
        if (showAction) ...[
          const SizedBox(height: 13),
          _OrderActionButton(part: part, color: statusColor),
        ],
      ],
    );
  }
}

class _ActiveMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ActiveMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8A94A3),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF32435B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressInfo extends StatelessWidget {
  final String address;
  final Color color;

  const _AddressInfo({required this.address, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE9EDF4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address.isEmpty
                  ? '\u{627}\u{644}\u{639}\u{646}\u{648}\u{627}\u{646} \u{63A}\u{64A}\u{631} \u{645}\u{62A}\u{627}\u{62D}'
                  : address,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: Color(0xFF667286),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneInfo extends StatelessWidget {
  final String phone;

  const _PhoneInfo({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.phone_rounded, size: 17, color: Color(0xFF4B7BCE)),
        const SizedBox(width: 6),
        Text(
          phone.isEmpty
              ? '\u{631}\u{642}\u{645} \u{627}\u{644}\u{647}\u{627}\u{62A}\u{641} \u{63A}\u{64A}\u{631} \u{645}\u{62A}\u{627}\u{62D}'
              : phone,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF657186),
          ),
        ),
      ],
    );
  }
}

class _OrderActionButton extends ConsumerWidget {
  final StoreOrderPart part;
  final Color color;

  const _OrderActionButton({required this.part, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPreparing = part.status == StoreOrderPartStatus.preparing;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: () async {
          final status = isPreparing
              ? StoreOrderPartStatus.ready
              : StoreOrderPartStatus.pickedUp;

          await ref
              .read(storeOwnerRepositoryProvider)
              .updateOrderPartStatus(partId: part.id, status: status);

          ref.invalidate(storeOwnerNewOrdersProvider);
          ref.invalidate(storeOwnerWaitingCourierProvider);
          ref.invalidate(storeOwnerTodayOrdersProvider);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPreparing ? Icons.done_all_rounded : Icons.front_hand_rounded,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isPreparing
                  ? '\u{62C}\u{627}\u{647}\u{632} \u{644}\u{644}\u{634}\u{62D}\u{646}'
                  : '\u{62A}\u{645} \u{627}\u{644}\u{62A}\u{633}\u{644}\u{64A}\u{645} \u{644}\u{644}\u{645}\u{646}\u{62F}\u{648}\u{628}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

extension _StoreOrderPartDisplay on StoreOrderPart {
  String get orderIdLabel {
    final number = unifiedOrderNumber?.trim() ?? '';
    if (number.isNotEmpty) {
      return number;
    }

    return orderId.length >= 8
        ? orderId.substring(0, 8).toUpperCase()
        : orderId.toUpperCase();
  }
}

class StoreOwnerOrderDetailsPage extends StatelessWidget {
  final StoreOrderPart part;
  final StoreOwnerOrdersSection section;
  final Color accentColor;

  const StoreOwnerOrderDetailsPage({
    super.key,
    required this.part,
    required this.section,
    required this.accentColor,
  });

  Future<List<Map<String, dynamic>>> _loadItems() async {
    final response = await Supabase.instance.client
        .from('order_items')
        .select('id,product_name,quantity,unit_price,item_total,selling_method')
        .eq('order_id', part.orderId)
        .eq('store_id', part.storeId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  String _formatQuantity(dynamic value) {
    if (value is num) {
      final d = value.toDouble();
      if (d == d.roundToDouble()) {
        return d.toInt().toString();
      }
      return d.toStringAsFixed(2);
    }
    return value?.toString() ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = section == StoreOwnerOrdersSection.today;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          title: Text(
            '#${part.orderIdLabel}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadItems(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <Map<String, dynamic>>[];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _DetailHeader(
                  part: part,
                  accentColor: accentColor,
                  readOnly: readOnly,
                  iconKind: switch (section) {
                    StoreOwnerOrdersSection.newOrders =>
                      HenaOrderIconKind.newOrder,
                    StoreOwnerOrdersSection.waitingCourier =>
                      HenaOrderIconKind.courier,
                    StoreOwnerOrdersSection.today => HenaOrderIconKind.today,
                  },
                ),
                const SizedBox(height: 12),
                _DetailCard(
                  title:
                      '\u{628}\u{64A}\u{627}\u{646}\u{627}\u{62A} \u{627}\u{644}\u{639}\u{645}\u{64A}\u{644}',
                  child: Column(
                    children: [
                      _DetailRow(
                        label:
                            '\u{627}\u{633}\u{645} \u{627}\u{644}\u{639}\u{645}\u{64A}\u{644}',
                        value: part.customerName,
                      ),
                      _DetailRow(
                        label:
                            '\u{631}\u{642}\u{645} \u{627}\u{644}\u{647}\u{627}\u{62A}\u{641}',
                        value: part.customerPhone.isEmpty
                            ? '\u{63A}\u{64A}\u{631} \u{645}\u{62A}\u{627}\u{62D}'
                            : part.customerPhone,
                      ),
                      _DetailRow(
                        label:
                            '\u{639}\u{646}\u{648}\u{627}\u{646} \u{627}\u{644}\u{62A}\u{648}\u{635}\u{64A}\u{644}',
                        value: part.deliveryAddress.isEmpty
                            ? '\u{63A}\u{64A}\u{631} \u{645}\u{62A}\u{627}\u{62D}'
                            : part.deliveryAddress,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailCard(
                  title:
                      '\u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A} \u{627}\u{644}\u{645}\u{637}\u{644}\u{648}\u{628}\u{629}',
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : snapshot.hasError
                      ? Text(
                          '\u{62D}\u{62F}\u{62B} \u{62E}\u{637}\u{623} \u{623}\u{62B}\u{646}\u{627}\u{621} \u{62A}\u{62D}\u{645}\u{64A}\u{644} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A}:\n${snapshot.error}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        )
                      : items.isEmpty
                      ? const Text(
                          '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A} \u{641}\u{64A} \u{647}\u{630}\u{627} \u{627}\u{644}\u{637}\u{644}\u{628}.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF738094),
                          ),
                        )
                      : Column(
                          children: items.map((item) {
                            final name = item['product_name']?.toString() ?? '';
                            final quantity = _formatQuantity(item['quantity']);
                            final unitPrice =
                                (item['unit_price'] as num?)?.toDouble() ?? 0;
                            final total =
                                (item['item_total'] as num?)?.toDouble() ?? 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFD),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(
                                          alpha: .09,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_rounded,
                                        color: accentColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF2A3950),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$quantity \u00D7 ${unitPrice.toStringAsFixed(2)} \u062C.\u0645',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF7D8899),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${total.toStringAsFixed(2)} \u{62C}.\u{645}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 12),
                _DetailCard(
                  title:
                      '\u{645}\u{644}\u{62E}\u{635} \u{627}\u{644}\u{637}\u{644}\u{628}',
                  child: Column(
                    children: [
                      _DetailRow(
                        label:
                            '\u{639}\u{62F}\u{62F} \u{627}\u{644}\u{645}\u{646}\u{62A}\u{62C}\u{627}\u{62A}',
                        value: '${part.itemCount}',
                      ),
                      _DetailRow(
                        label:
                            '\u{625}\u{62C}\u{645}\u{627}\u{644}\u{64A} \u{627}\u{644}\u{637}\u{644}\u{628}',
                        value:
                            '${part.subtotal.toStringAsFixed(2)} \u{62C}.\u{645}',
                      ),
                      _DetailRow(
                        label:
                            '\u{62D}\u{627}\u{644}\u{629} \u{627}\u{644}\u{637}\u{644}\u{628}',
                        value: readOnly
                            ? '\u{644}\u{644}\u{639}\u{631}\u{636} \u{641}\u{642}\u{637}'
                            : part.status == StoreOrderPartStatus.preparing
                            ? '\u{642}\u{64A}\u{62F} \u{627}\u{644}\u{62A}\u{62C}\u{647}\u{64A}\u{632}'
                            : '\u{62C}\u{627}\u{647}\u{632} \u{644}\u{644}\u{634}\u{62D}\u{646}',
                      ),
                    ],
                  ),
                ),
                if (part.customerNote != null &&
                    part.customerNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailCard(
                    title:
                        '\u{645}\u{644}\u{627}\u{62D}\u{638}\u{629} \u{627}\u{644}\u{639}\u{645}\u{64A}\u{644}',
                    child: Text(
                      part.customerNote!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5E6B7D),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final StoreOrderPart part;
  final Color accentColor;
  final bool readOnly;
  final HenaOrderIconKind iconKind;

  const _DetailHeader({
    required this.part,
    required this.accentColor,
    required this.readOnly,
    required this.iconKind,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [accentColor, accentColor.withValues(alpha: .78)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          HenaOrderIcon(
            kind: iconKind,
            size: 64,
            foregroundColor: Colors.white,
            accentColor: Colors.white70,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${part.orderIdLabel}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  part.storeName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: .90),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .94),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              readOnly
                  ? '\u{644}\u{644}\u{639}\u{631}\u{636} \u{641}\u{642}\u{637}'
                  : '\u{642}\u{64A}\u{62F} \u{627}\u{644}\u{645}\u{62A}\u{627}\u{628}\u{639}\u{629}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7F8FA5).withValues(alpha: .07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF24334A),
            ),
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF939CAB),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: Color(0xFF56647A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final String title;
  final HenaOrderIconKind iconKind;
  final Color color;

  const _EmptyOrders({
    required this.title,
    required this.iconKind,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: HenaOrderIcon(
                  kind: iconKind,
                  size: 76,
                  foregroundColor: color,
                  accentColor: color,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '\u{644}\u{627} \u{62A}\u{648}\u{62C}\u{62F} \u{637}\u{644}\u{628}\u{627}\u{62A} \u{62D}\u{627}\u{644}\u{64A}\u{64B}\u{627} \u{641}\u{64A} \u{642}\u{633}\u{645} $title.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF4E5D73),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color color;

  const _OrdersError({
    required this.message,
    required this.onRetry,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HenaOrderIcon(
              kind: HenaOrderIconKind.store,
              size: 70,
              foregroundColor: color,
              accentColor: color,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF5C687A),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text(
                '\u{625}\u{639}\u{627}\u{62F}\u{629} \u{627}\u{644}\u{645}\u{62D}\u{627}\u{648}\u{644}\u{629}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
