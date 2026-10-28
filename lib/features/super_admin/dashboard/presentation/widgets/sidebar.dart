import 'package:flutter/material.dart';
import '../theme/dashboard_colors.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../../data/mock/mock_dashboard_data.dart';

class Sidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback? onCustomerMode;
  final bool collapsed;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.onCustomerMode,
    this.collapsed = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: widget.collapsed ? 76 : 248,
      decoration: const BoxDecoration(
        color: DashboardColors.surface,
        border: Border(
          right: BorderSide(color: DashboardColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildBrand(),
          const SizedBox(height: 12),
          _buildNav(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 16 : 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DashboardColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: DashboardColors.accent.withValues(alpha: 0.1),
              border: Border.all(color: DashboardColors.accent, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                'H',
                style: TextStyle(
                  color: DashboardColors.accent,
                  fontFamily: DashboardColors.monoFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!widget.collapsed) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HENA',
                    style: TextStyle(
                      color: DashboardColors.textPrimary,
                      fontFamily: DashboardColors.monoFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'admin.console',
                    style: TextStyle(
                      color: DashboardColors.textMuted,
                      fontFamily: DashboardColors.monoFont,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNav() {
    return Expanded(
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: DashboardMockData.navItems.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, i) {
          final item = DashboardMockData.navItems[i];
          final isSelected = i == widget.selectedIndex;
          final isHovered = i == _hoveredIndex;

          return _NavTile(
            item: item,
            selected: isSelected,
            hovered: isHovered,
            collapsed: widget.collapsed,
            onTap: () => widget.onItemSelected(i),
            onHover: (v) => setState(() => _hoveredIndex = v ? i : null),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(widget.collapsed ? 12 : 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: DashboardColors.border, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.collapsed ? _buildCollapsedFooter() : _buildExpandedFooter(),
          if (widget.onCustomerMode != null) ...[
            const SizedBox(height: 10),
            _buildCustomerModeButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedFooter() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: DashboardColors.surfaceElevated,
            border: Border.all(color: DashboardColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'v2',
              style: TextStyle(
                color: DashboardColors.accent,
                fontFamily: DashboardColors.monoFont,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Admin Console',
                style: TextStyle(
                  color: DashboardColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'v2.4.1',
                style: TextStyle(
                  color: DashboardColors.textMuted,
                  fontSize: 10,
                  fontFamily: DashboardColors.monoFont,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right,
            color: DashboardColors.textMuted, size: 16),
      ],
    );
  }

  Widget _buildCustomerModeButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onCustomerMode,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: DashboardColors.border,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                color: DashboardColors.accent,
                size: 18,
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'USE AS CUSTOMER',
                    style: TextStyle(
                      color: DashboardColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: DashboardColors.textMuted,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedFooter() {
    return Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: DashboardColors.surfaceElevated,
          border: Border.all(color: DashboardColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Icon(Icons.expand_more,
              size: 16, color: DashboardColors.textMuted),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool hovered;
  final bool collapsed;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.hovered,
    required this.collapsed,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? DashboardColors.accent
        : (hovered ? DashboardColors.textPrimary : DashboardColors.textSecondary);

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Tooltip(
        message: collapsed ? item.label : '',
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? DashboardColors.accent.withValues(alpha: 0.08)
                    : (hovered ? DashboardColors.surfaceHover : Colors.transparent),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected
                      ? DashboardColors.accent.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(item.icon, color: color, size: 18),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: DashboardColors.statusDown.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: DashboardColors.statusDown.withValues(alpha: 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          item.badge!,
                          style: const TextStyle(
                            color: DashboardColors.statusDown,
                            fontSize: 9,
                            fontFamily: DashboardColors.monoFont,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
