import 'package:flutter/material.dart';

import '../theme/dashboard_colors.dart';
import '../../domain/entities/dashboard_entities.dart';
import 'glow_card.dart';
import 'status_badge.dart';
import 'terminal_text.dart';

class RecentOrdersTable extends StatefulWidget {
  final List<OrderModel> orders;

  const RecentOrdersTable({super.key, required this.orders});

  @override
  State<RecentOrdersTable> createState() => _RecentOrdersTableState();
}

class _RecentOrdersTableState extends State<RecentOrdersTable> {
  String _selectedFilter = 'ALL';

  List<OrderModel> get _filteredOrders {
    switch (_selectedFilter) {
      case 'PENDING':
        return widget.orders
            .where((order) => order.status == OrderStatus.pending)
            .toList();

      case 'COMPLETED':
        return widget.orders
            .where((order) => order.status == OrderStatus.completed)
            .toList();

      case 'ALL':
      default:
        return widget.orders;
    }
  }

  void _selectFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _filteredOrders;

    return GlowCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;

              final titleSection = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TerminalLabel(text: 'RECENT ORDERS'),
                        SizedBox(height: 6),
                        Text(
                          'Latest transactions',
                          style: TextStyle(
                            color: DashboardColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DashboardColors.surfaceElevated,
                      border: Border.all(color: DashboardColors.border),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${filteredOrders.length}',
                      style: const TextStyle(
                        color: DashboardColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: DashboardColors.monoFont,
                      ),
                    ),
                  ),
                ],
              );

              final filters = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _FilterChip(
                    label: 'ALL',
                    active: _selectedFilter == 'ALL',
                    count: widget.orders.length,
                    onTap: () => _selectFilter('ALL'),
                  ),
                  _FilterChip(
                    label: 'PENDING',
                    active: _selectedFilter == 'PENDING',
                    count: widget.orders
                        .where((order) => order.status == OrderStatus.pending)
                        .length,
                    onTap: () => _selectFilter('PENDING'),
                  ),
                  _FilterChip(
                    label: 'COMPLETED',
                    active: _selectedFilter == 'COMPLETED',
                    count: widget.orders
                        .where((order) => order.status == OrderStatus.completed)
                        .length,
                    onTap: () => _selectFilter('COMPLETED'),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleSection, const SizedBox(height: 12), filters],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 16),
                  Flexible(child: filters),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (filteredOrders.isEmpty)
            _EmptyOrdersState(filter: _selectedFilter)
          else ...[
            const _TableHeader(),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filteredOrders.length,
                separatorBuilder: (_, _) =>
                    Divider(color: DashboardColors.borderSubtle, height: 1),
                itemBuilder: (context, i) {
                  return _OrderRow(order: filteredOrders[i]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  final String filter;

  const _EmptyOrdersState({required this.filter});

  String get _message {
    switch (filter) {
      case 'PENDING':
        return 'There are no pending orders.';
      case 'COMPLETED':
        return 'There are no completed orders.';
      default:
        return 'There are no recent orders yet.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: DashboardColors.surfaceElevated,
        border: Border.all(color: DashboardColors.borderSubtle),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 28,
            color: DashboardColors.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            filter == 'ALL' ? 'NO ORDERS' : 'NO ${filter.toUpperCase()} ORDERS',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DashboardColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFamily: DashboardColors.monoFont,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DashboardColors.textMuted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? DashboardColors.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? DashboardColors.accent.withValues(alpha: 0.4)
                  : DashboardColors.border,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? DashboardColors.accent
                      : DashboardColors.textMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  fontFamily: DashboardColors.monoFont,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  color: active
                      ? DashboardColors.accent
                      : DashboardColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  fontFamily: DashboardColors.monoFont,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DashboardColors.surfaceElevated,
        border: Border.all(color: DashboardColors.borderSubtle),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: _HeaderCell('ORDER ID')),
          Expanded(flex: 4, child: _HeaderCell('CUSTOMER')),
          Expanded(flex: 4, child: _HeaderCell('STORE')),
          Expanded(
            flex: 3,
            child: _HeaderCell('AMOUNT', align: TextAlign.right),
          ),
          Expanded(flex: 3, child: _HeaderCell('PAYMENT')),
          Expanded(flex: 3, child: _HeaderCell('STATUS')),
          Expanded(flex: 3, child: _HeaderCell('DATE', align: TextAlign.right)),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _HeaderCell(this.label, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: const TextStyle(
        color: DashboardColors.textMuted,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        fontFamily: DashboardColors.monoFont,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _OrderRow extends StatefulWidget {
  final OrderModel order;

  const _OrderRow({required this.order});

  @override
  State<_OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends State<_OrderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered ? DashboardColors.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                widget.order.id,
                style: const TextStyle(
                  color: DashboardColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: DashboardColors.monoFont,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: DashboardColors.surfaceElevated,
                      border: Border.all(color: DashboardColors.border),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(
                      child: Text(
                        _initials(widget.order.customer),
                        style: const TextStyle(
                          color: DashboardColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.order.customer,
                      style: const TextStyle(
                        color: DashboardColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                widget.order.store,
                style: const TextStyle(
                  color: DashboardColors.textSecondary,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '\$${widget.order.amount.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: DashboardColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: DashboardColors.monoFont,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge.forPayment(
                  widget.order.payment,
                  small: true,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge.forOrder(widget.order.status, small: true),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _formatTime(widget.order.date),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: DashboardColors.textMuted,
                  fontSize: 11.5,
                  fontFamily: DashboardColors.monoFont,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');

    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }

    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) {
      return 'just now';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }

    return '${diff.inDays}d ago';
  }
}
