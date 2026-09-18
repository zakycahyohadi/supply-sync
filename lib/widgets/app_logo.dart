import 'package:flutter/material.dart';

/// Logo Supply Sync: huruf S dari dua panah, di atas kotak putih membulat.
///
/// Gambarnya sudah termasuk kotak putih dan sudut membulatnya, jadi bisa
/// ditaruh di atas latar apa pun — termasuk header navy dan layar pembuka.
/// Berkasnya dibuat `tool/generate_icons.dart` dari logo yang sama dengan
/// ikon aplikasi, supaya tidak pernah beda.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.size});

  final double size;

  static const asset = 'assets/icon/app_logo_badge.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      // Logonya kotak; ukuran yang diminta selalu dituruti.
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Supply Sync',
    );
  }
}
