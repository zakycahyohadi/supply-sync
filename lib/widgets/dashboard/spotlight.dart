import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Latar kartu sorotan di bawah header: terang dengan semburat navy tipis,
/// supaya tidak menumpuk dengan header yang gelap.
BoxDecoration spotlightDecoration() => BoxDecoration(
  gradient: const LinearGradient(
    colors: [Color(0xFFE6EDF8), AppColors.surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.border),
  boxShadow: [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ],
);

/// Angka ringkas di dalam kartu sorotan.
class SpotlightStat extends StatelessWidget {
  const SpotlightStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
