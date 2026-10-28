import '../../../../../core/services/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/dashboard_colors.dart';
import 'terminal_text.dart';

class TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuPressed;
  final bool showMenuButton;

  const TopBar({
    super.key,
    required this.title,
    this.onMenuPressed,
    this.showMenuButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1100;
    final isCompact = width < 600;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: DashboardColors.surface,
        border: Border(
          bottom: BorderSide(color: DashboardColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            _IconBtn(icon: Icons.menu, onPressed: onMenuPressed),
            const SizedBox(width: 8),
          ],

          Expanded(
            child: _PromptTitle(title: title, compact: isCompact),
          ),

          if (isWide) ...[
            const SizedBox(width: 24),
            const Expanded(child: _SearchBar()),
            const SizedBox(width: 24),
            const _StatusIndicator(),
            const SizedBox(width: 12),
          ] else ...[
            const SizedBox(width: 8),
          ],

          const _NotificationButton(),
          const SizedBox(width: 8),

          _AdminProfile(compact: isCompact),
        ],
      ),
    );
  }
}

class _PromptTitle extends StatelessWidget {
  final String title;
  final bool compact;

  const _PromptTitle({required this.title, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final slug = title
        .toLowerCase()
        .replaceAll(' ', '-')
        .replaceAll('/', '-')
        .replaceAll('---', '-');

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'hena@admin',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: DashboardColors.accent,
              fontFamily: DashboardColors.monoFont,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Text(
            ':~/',
            style: TextStyle(
              color: DashboardColors.textMuted,
              fontFamily: DashboardColors.monoFont,
              fontSize: 11,
            ),
          ),
          Flexible(
            child: Text(
              slug,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DashboardColors.textPrimary,
                fontFamily: DashboardColors.monoFont,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(
            r'$',
            style: TextStyle(
              color: DashboardColors.textMuted,
              fontFamily: DashboardColors.monoFont,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'hena@admin',
          style: TextStyle(
            color: DashboardColors.accent,
            fontFamily: DashboardColors.monoFont,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Text(
          ':~/',
          style: TextStyle(
            color: DashboardColors.textMuted,
            fontFamily: DashboardColors.monoFont,
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            slug,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: DashboardColors.textPrimary,
              fontFamily: DashboardColors.monoFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Text(
          r'$',
          style: TextStyle(
            color: DashboardColors.textMuted,
            fontFamily: DashboardColors.monoFont,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        const BlinkingCursor(),
      ],
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: DashboardColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _focused
              ? DashboardColors.accent.withValues(alpha: 0.5)
              : DashboardColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search,
            size: 15,
            color: _focused
                ? DashboardColors.accent
                : DashboardColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(
                color: DashboardColors.textPrimary,
                fontSize: 12.5,
                fontFamily: DashboardColors.monoFont,
              ),
              cursorColor: DashboardColors.accent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                hintText: 'grep -r "search users, stores, orders..."',
                hintStyle: TextStyle(
                  color: DashboardColors.textMuted,
                  fontSize: 12.5,
                  fontFamily: DashboardColors.monoFont,
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: DashboardColors.border),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text(
              'K',
              style: TextStyle(
                color: DashboardColors.textMuted,
                fontSize: 9,
                fontFamily: DashboardColors.monoFont,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DashboardColors.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: DashboardColors.accent.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LiveDot(),
          SizedBox(width: 7),
          Text(
            'SYSTEM ONLINE',
            style: TextStyle(
              color: DashboardColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: DashboardColors.monoFont,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        return Opacity(
          opacity: 0.6 + (_c.value * 0.4),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: DashboardColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: DashboardColors.accent.withValues(alpha: 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NotificationButton extends StatefulWidget {
  const _NotificationButton();

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _hovered
                  ? DashboardColors.surfaceHover
                  : Colors.transparent,
              border: Border.all(
                color: _hovered
                    ? DashboardColors.border
                    : DashboardColors.borderSubtle,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_none_outlined,
                  size: 18,
                  color: _hovered
                      ? DashboardColors.textPrimary
                      : DashboardColors.textSecondary,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: DashboardColors.statusDown,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: DashboardColors.surface,
                        width: 1.5,
                      ),
                    ),
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

class _AdminProfile extends StatelessWidget {
  final bool compact;

  const _AdminProfile({this.compact = false});

  Future<void> _signOut() async {
    await FcmService.instance.unregisterCurrentToken();
    await Supabase.instance.client.auth.signOut();
  }

  String _displayName(User user) {
    final metadata = user.userMetadata;

    final fullName = metadata?['full_name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'USER';
  }

  String _roleLabel(User user) {
    final role = user.userMetadata?['role']?.toString();

    switch (role) {
      case 'admin':
        return 'SUPER ADMIN';
      case 'store_owner':
        return 'STORE OWNER';
      case 'driver':
        return 'DRIVER';
      case 'customer':
        return 'CUSTOMER';
      default:
        return 'USER';
    }
  }

  String _initials(User user) {
    final name = _displayName(user);
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }

    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final displayName = _displayName(user);
    final roleLabel = _roleLabel(user);
    final initials = _initials(user);

    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      onSelected: (value) async {
        if (value == 'sign_out') {
          try {
            await _signOut();
          } catch (error) {
            if (!context.mounted) return;

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('SIGN OUT FAILED: $error')));
          }
        }
      },
      color: DashboardColors.surface,
      elevation: 8,
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'sign_out',
          child: Row(
            children: [
              Icon(
                Icons.logout,
                size: 18,
                color: DashboardColors.textSecondary,
              ),
              SizedBox(width: 10),
              Text(
                'SIGN OUT',
                style: TextStyle(
                  color: DashboardColors.textPrimary,
                  fontFamily: DashboardColors.monoFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: DashboardColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProfileAvatar(initials: initials),
              if (!compact) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DashboardColors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: DashboardColors.monoFont,
                        ),
                      ),
                      Text(
                        roleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DashboardColors.textMuted,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: DashboardColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String initials;

  const _ProfileAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: DashboardColors.accent.withValues(alpha: 0.12),
        border: Border.all(color: DashboardColors.accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: DashboardColors.accent,
            fontFamily: DashboardColors.monoFont,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _IconBtn({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: DashboardColors.textSecondary),
        ),
      ),
    );
  }
}
