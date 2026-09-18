import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Interval sumbu Y yang "bulat" (1, 2, 5 × 10^n) untuk kira-kira 4 garis.
double niceInterval(double maxValue, {int targetTicks = 4}) {
  if (maxValue <= 0) return 1;
  final raw = maxValue / targetTicks;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final residual = raw / magnitude;
  final nice = residual <= 1
      ? 1
      : residual <= 2
      ? 2
      : residual <= 5
      ? 5
      : 10;
  return nice * magnitude;
}

/// Batas atas sumbu Y: kelipatan [interval] di atas nilai terbesar.
double niceMaxY(double maxValue, double interval) =>
    math.max(interval, (maxValue / interval).ceil() * interval);

const chartAxisTextStyle = TextStyle(color: AppColors.textMuted, fontSize: 11);

const chartTooltipTitleStyle = TextStyle(
  color: Colors.white70,
  fontSize: 11,
  fontWeight: FontWeight.w500,
);

const chartTooltipValueStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

/// Legend: penanda warna di samping teks (teksnya tetap warna netral).
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<({String label, Color color})> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
