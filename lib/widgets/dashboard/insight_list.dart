import 'package:flutter/material.dart';

import '../../data/insights_engine.dart';
import '../../theme/app_colors.dart';

/// Daftar insight (naik/turun, stok, pindah barang, perkiraan kebutuhan).
class InsightList extends StatelessWidget {
  const InsightList({
    super.key,
    required this.insights,
    this.maxItems,
    this.emptyMessage = 'Belum ada catatan untuk periode ini.',
  });

  final List<Insight> insights;

  /// Batas jumlah yang ditampilkan; sisanya diringkas jadi satu baris.
  final int? maxItems;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppColors.statusGood,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(emptyMessage)),
        ],
      );
    }

    final limit = maxItems;
    final shown = limit == null || insights.length <= limit
        ? insights
        : insights.take(limit).toList();
    final hidden = insights.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _InsightTile(insight: shown[i]),
        ],
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '+$hidden catatan lain',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

Color insightToneColor(InsightTone tone) => switch (tone) {
  InsightTone.positive => AppColors.statusGood,
  InsightTone.negative => AppColors.deltaDown,
  InsightTone.warning => AppColors.statusWarning,
  InsightTone.info => AppColors.navy,
};

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = insightToneColor(insight.tone);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(insight.emoji, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.detail,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
