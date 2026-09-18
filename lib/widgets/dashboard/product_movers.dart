import 'package:flutter/material.dart';

import '../../data/sales_analytics.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency.dart';
import 'stat_tile.dart';

/// Produk yang omzetnya paling naik dan paling turun.
class ProductMovers extends StatelessWidget {
  const ProductMovers({super.key, required this.risers, required this.fallers});

  final List<ProductChange> risers;
  final List<ProductChange> fallers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MoverGroup(
          title: 'Naik',
          icon: Icons.trending_up_rounded,
          color: AppColors.deltaUp,
          changes: risers,
          emptyMessage: 'Tidak ada produk yang naik.',
        ),
        const Divider(height: 28, color: AppColors.border),
        _MoverGroup(
          title: 'Turun',
          icon: Icons.trending_down_rounded,
          color: AppColors.deltaDown,
          changes: fallers,
          emptyMessage: 'Tidak ada produk yang turun.',
        ),
      ],
    );
  }
}

class _MoverGroup extends StatelessWidget {
  const _MoverGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.changes,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<ProductChange> changes;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (changes.isEmpty)
          Text(
            emptyMessage,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          )
        else
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          change.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${formatCompactRupiah(change.currentRevenue)} · '
                          'bulan lalu ${formatCompactRupiah(change.previousRevenue)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DeltaPill(percent: change.changePercent),
                ],
              ),
            ),
      ],
    );
  }
}
