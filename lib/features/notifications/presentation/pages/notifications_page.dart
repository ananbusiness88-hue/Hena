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
    final visibleItems = ref.watch(visibleNotificationsProvider);

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
            if (visibleItems.isEmpty) {
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

            return Column(
              children: [
                _ClearAllButton(
                  count: visibleItems.length,
                  onPressed: () => _clearAllNotifications(context, ref),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notificationsProvider);
                      await ref.read(notificationsProvider.future);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: visibleItems.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];

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
                          onDelete: () =>
                              _deleteNotification(context, ref, item),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Deletes one notification.
  ///
  /// The notification disappears immediately and comes back when the
  /// server refuses the deletion.
  Future<void> _deleteNotification(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    final deletion = ref.read(notificationDeletionProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    deletion.hide(item.id);

    try {
      await ref
          .read(notificationRepositoryProvider)
          .deleteNotification(item.id);

      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (error) {
      deletion.reveal(item.id);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '\u{062a}\u{0639}\u{0630}\u{0631} \u{062d}\u{0630}\u{0641} '
              '\u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}. '
              '\u{062d}\u{0627}\u{0648}\u{0644} \u{0645}\u{0631}\u{0629} '
              '\u{0623}\u{062e}\u{0631}\u{0649}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Deletes every notification of the signed in user after a
  /// confirmation.
  Future<void> _clearAllNotifications(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final previous = ref.read(notificationDeletionProvider);
    final currentIds = ref
        .read(visibleNotificationsProvider)
        .map((item) => item.id)
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          '\u{062d}\u{0630}\u{0641} \u{062c}\u{0645}\u{064a}\u{0639} '
          '\u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a}',
        ),
        content: const Text(
          '\u{0633}\u{064a}\u{062a}\u{0645} \u{062d}\u{0630}\u{0641} '
          '\u{062c}\u{0645}\u{064a}\u{0639} '
          '\u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              '\u{0625}\u{0644}\u{063a}\u{0627}\u{0621}',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const Text(
              '\u{062d}\u{0630}\u{0641} \u{0627}\u{0644}\u{062c}\u{0645}\u{064a}\u{0639}',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final deletion = ref.read(notificationDeletionProvider.notifier);

    deletion.hideAll(currentIds);

    try {
      await ref.read(notificationRepositoryProvider).deleteAllNotifications();

      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (error) {
      deletion.revertTo(previous);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '\u{062a}\u{0639}\u{0630}\u{0631} \u{062d}\u{0630}\u{0641} '
              '\u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a}. '
              '\u{062d}\u{0627}\u{0648}\u{0644} \u{0645}\u{0631}\u{0629} '
              '\u{0623}\u{062e}\u{0631}\u{0649}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }
}

/// The button that clears every notification of the signed in user.
class _ClearAllButton extends StatelessWidget {
  const _ClearAllButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.delete_sweep_outlined, size: 20),
          label: Text(
            '\u{062d}\u{0630}\u{0641} \u{062c}\u{0645}\u{064a}\u{0639} '
            '\u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}\u{0627}\u{062a} '
            '($count)',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB42318),
            side: const BorderSide(color: Color(0xFFE7C7C7)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
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
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
              const SizedBox(width: 4),
              IconButton(
                tooltip: '\u{062d}\u{0630}\u{0641} \u{0627}\u{0644}\u{0625}\u{0634}\u{0639}\u{0627}\u{0631}',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFB42318),
                  size: 22,
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
