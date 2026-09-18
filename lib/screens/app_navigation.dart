import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'central_admin/central_admin_dashboard_screen.dart';
import 'customer_home_screen.dart';
import 'store_admin/store_admin_home_screen.dart';

/// Buka halaman sesuai role, dan hapus riwayat halaman sebelumnya supaya
/// tombol back tidak kembali ke halaman publik.
void openHomeForUser(BuildContext context, AppUser user) {
  final Widget page = switch (user.role) {
    UserRole.centralAdmin => CentralAdminDashboardScreen(user: user),
    UserRole.storeAdmin => StoreAdminHomeScreen(user: user),
  };
  Navigator.of(context).pushAndRemoveUntil(_fadeRoute(page), (route) => false);
}

/// Kembali ke halaman publik (dipakai setelah logout).
void openPublicHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    _fadeRoute(const CustomerHomeScreen()),
    (route) => false,
  );
}

Route<void> _fadeRoute(Widget page) => PageRouteBuilder<void>(
  pageBuilder: (context, animation, secondaryAnimation) => page,
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(opacity: animation, child: child),
);
