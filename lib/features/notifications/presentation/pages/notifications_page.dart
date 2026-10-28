import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_notification.dart';
import '../providers/notifications_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  static const _background = Color(0xFFF7FAF8);
  static const _darkGreen = Color(0xFF123F2F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            '\u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a}',
            style: TextStyle(fontWeight: FontWeight.w900, color: _darkGreen),
          ),
          actions: [
            if (unreadCount > 0)
              TextButton.icon(
                onPressed: () async {
                  await ref.read(notificationActionsProvider).markAllAsRead();
                  ref.invalidate(notificationsProvider);
                },
                icon: const Icon(Icons.done_all_rounded, size: 19),
                label: const Text(
                  '\u{0642}\u{0631}\u{0627}\u{0621}\u{0629} \u{0627}\u{0644}\u{0643}\u{0644}',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _NotificationsState(
            icon: Icons.error_outline_rounded,
            title:
                '\u{062a}\u{0639}\u{0630}\u{0631} \u{062a}\u{062d}\u{0645}\u{064a}\u{0644} \u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a}:',
            subtitle: '$error',
            iconColor: const Color(0xFFB42318),
            action: () => ref.invalidate(notificationsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _NotificationsState(
                icon: Icons.notifications_none_rounded,
                title:
                    '\u{0644}\u{0627} \u{062a}\u{0648}\u{062c}\u{062f} \u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a}',
                subtitle:
                    '\u{0633}\u{062a}\u{0638}\u{0647}\u{0631} \u{0647}\u{0646}\u{0627} \u{0627}\u{0644}\u{062a}\u{0646}\u{0628}\u{064a}\u{0647}\u{0627}\u{062a} \u{0627}\u{0644}\u{0645}\u{0647}\u{0645}\u{0629} \u{0627}\u{0644}\u{062e}\u{0627}\u{0635}\u{0629} \u{0628}\u{0643}.',
                iconColor: const Color(0xFF7C9187),
                action: () => ref.invalidate(notificationsProvider),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsProvider);
                await ref.read(notificationsProvider.future);
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];

                  return _NotificationCard(
                    notification: item,
                    onTap: () async {
                      if (!item.isRead) {
                        await ref
                            .read(notificationActionsProvider)
                            .markAsRead(item.id);
                        ref.invalidate(notificationsProvider);
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationsState extends StatelessWidget {
  const _NotificationsState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFDCEBE3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: iconColor),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF16342A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF71857C), height: 1.5),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  '\u{0625}\u{0639}\u{0627}\u{062f}\u{0629} \u{0627}\u{0644}\u{0645}\u{062d}\u{0627}\u{0648}\u{0644}\u{0629}',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final accent = _iconColor(notification.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: unread
                ? const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFE8F7F0), Color(0xFFF9FCFA)],
                  )
                : const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Colors.white, Color(0xFFFBFDFC)],
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: unread ? const Color(0xFFCFE8DA) : const Color(0xFFE1ECE7),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  color: accent,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF19392E),
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF159B68),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        color: Color(0xFF52665D),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDate(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A9B94),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _iconColor(String type) {
    switch (type) {
      case 'order':
      case 'order_status':
        return const Color(0xFF159B68);
      case 'delivery':
        return const Color(0xFF2A76B8);
      case 'offer':
        return const Color(0xFFE48B20);
      default:
        return const Color(0xFF6A7D74);
    }
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'order':
      case 'order_status':
        return Icons.receipt_long_rounded;
      case 'delivery':
        return Icons.local_shipping_rounded;
      case 'offer':
        return Icons.local_offer_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year}  $hour:$minute';
  }
}
