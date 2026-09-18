import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';
import '../../data/sales_widget_publisher.dart';
import '../../models/app_user.dart';
import '../../screens/app_navigation.dart';
import '../../theme/app_colors.dart';
import '../app_header.dart';

/// Header halaman setelah login: logo, peran, notifikasi, dan menu akun.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({
    super.key,
    required this.user,
    this.notificationCount = 0,
    this.onNotificationsTap,
  });

  final AppUser user;

  /// Jumlah di ikon lonceng. Lonceng hanya tampil kalau [onNotificationsTap]
  /// diisi.
  final int notificationCount;
  final VoidCallback? onNotificationsTap;

  @override
  Size get preferredSize => const AppHeader(title: '').preferredSize;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda akan kembali ke halaman utama.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AuthRepository.instance.logout();
    // Data penjualan tidak tetap tampil di widget setelah keluar.
    await SalesWidgetPublisher.clear();
    if (!context.mounted) return;
    openPublicHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final roleLine = user.storeName == null
        ? user.role.label
        : '${user.role.label} · ${user.storeName}';

    return AppHeader(
      title: 'Supply Sync',
      subtitle: roleLine,
      subtitleIcon: user.role == UserRole.centralAdmin
          ? Icons.verified_user_rounded
          : Icons.storefront_rounded,
      actions: [
        if (onNotificationsTap != null)
          HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifikasi',
            badgeCount: notificationCount,
            onPressed: onNotificationsTap,
          ),
        _AccountMenu(user: user, onLogout: () => _confirmLogout(context)),
      ],
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu({required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Akun',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          child: Row(
            children: [
              _Initials(user: user, size: 36, onDark: false),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<void>(
          onTap: onLogout,
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
              SizedBox(width: 12),
              Text('Keluar', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
      child: _Initials(user: user, size: 40, onDark: true),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.user,
    required this.size,
    required this.onDark,
  });

  final AppUser user;
  final double size;

  /// true = di atas header navy.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: onDark
            ? LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
              ),
        border: onDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2)
            : null,
      ),
      child: Text(
        user.initials,
        style: TextStyle(
          color: onDark ? AppColors.navy : Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
