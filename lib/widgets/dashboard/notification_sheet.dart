import 'package:flutter/material.dart';

import '../../data/notifications.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';

/// Buka daftar notifikasi sebagai panel dari bawah layar.
///
/// [unreadIds] adalah notifikasi yang belum dibaca saat panel dibuka; dipakai
/// untuk titik penanda, bukan untuk badge (badge sudah dimatikan oleh
/// pemanggil begitu panel dibuka).
Future<void> showNotificationSheet({
  required BuildContext context,
  required List<AppNotification> notifications,
  required Set<String> unreadIds,
  required ValueChanged<AppNotification> onOpen,
  VoidCallback? onSeeAll,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _NotificationSheet(
      notifications: notifications,
      unreadIds: unreadIds,
      onOpen: onOpen,
      onSeeAll: onSeeAll,
    ),
  );
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({
    required this.notifications,
    required this.unreadIds,
    required this.onOpen,
    this.onSeeAll,
  });

  final List<AppNotification> notifications;
  final Set<String> unreadIds;
  final ValueChanged<AppNotification> onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onSeeAll = this.onSeeAll;
    final unreadCount = notifications
        .where((notification) => unreadIds.contains(notification.id))
        .length;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.navy,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifikasi',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    unreadCount == 0
                        ? 'Tidak ada yang baru'
                        : '$unreadCount baru',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppColors.statusGood,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Belum ada notifikasi. Pengiriman dari pusat akan '
                        'muncul di sini.',
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      isUnread: unreadIds.contains(notification.id),
                      onTap: () {
                        Navigator.of(context).pop();
                        onOpen(notification);
                      },
                    );
                  },
                ),
              ),
            if (onSeeAll != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSeeAll();
                  },
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Lihat semua pengiriman'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isUnread,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (color, icon) = switch (notification.kind) {
      AppNotificationKind.shipmentIncoming => (
        AppColors.navy,
        Icons.local_shipping_rounded,
      ),
      AppNotificationKind.shipmentReceived => (
        AppColors.statusGood,
        Icons.check_circle_rounded,
      ),
    };

    return Material(
      color: isUnread ? color.withValues(alpha: 0.06) : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? color.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatRelativeTime(notification.time),
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
