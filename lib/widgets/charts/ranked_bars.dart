import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class RankedBarItem {
  const RankedBarItem({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.detail,
    this.color,
  });

  final String label;
  final num value;

  /// Teks nilai di ujung kanan, contoh "Rp98 jt".
  final String valueLabel;

  /// Keterangan kecil di bawah label, contoh "12 unit".
  final String? detail;

  /// Penanda warna untuk entitas (misalnya toko). Null = warna seri pertama.
  final Color? color;
}

/// Daftar batang horizontal yang diurutkan, nilainya ditulis di setiap baris.
class RankedBars extends StatelessWidget {
  const RankedBars({super.key, required this.items});

  final List<RankedBarItem> items;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold<num>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _RankedBarRow(
            item: items[i],
            fraction: maxValue == 0 ? 0 : items[i].value / maxValue,
            textTheme: textTheme,
          ),
        ],
      ],
    );
  }
}

class _RankedBarRow extends StatelessWidget {
  const _RankedBarRow({
    required this.item,
    required this.fraction,
    required this.textTheme,
  });

  final RankedBarItem item;
  final double fraction;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? AppColors.series.first;
    final detail = item.detail;

    return Semantics(
      label: '${item.label}: ${item.valueLabel}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (item.color != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: item.label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      if (detail != null)
                        TextSpan(
                          text: '  $detail',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item.valueLabel,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 8,
                width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
