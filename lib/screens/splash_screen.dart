import 'dart:async';

import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';
import 'app_navigation.dart';

/// Layar pembuka: logo muncul sebentar sambil memulihkan sesi login.
/// Kalau masih login langsung ke dashboard, kalau tidak ke halaman publik.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final _logo = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
  );
  late final _text = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 0.75, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // Sesi dipulihkan bersamaan dengan animasi, jadi tidak menambah waktu.
    final session = AuthRepository.instance.restoreSession().then<AppUser?>(
      (user) => user,
      onError: (Object _) => null,
    );
    await _controller.forward();
    final user = await session;
    if (!mounted) return;

    if (user == null) {
      openPublicHome(context);
    } else {
      openHomeForUser(context, user);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy, AppColors.navyLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _logo,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _text,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(_text),
                  child: const Column(
                    children: [
                      Text(
                        'SUPPLY SYNC',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Stok & penjualan semua toko, selalu sinkron',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
