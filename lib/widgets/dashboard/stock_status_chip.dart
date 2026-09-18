import 'package:flutter/material.dart';

import '../../data/sales_analytics.dart';
import '../../theme/app_colors.dart';

/// Warna & ikon tiap status stok. Selalu dipakai bersama labelnya.
(Color, IconData) stockStatusStyle(StockStatus status) => switch (status) {
  StockStatus.out => (AppColors.statusCritical, Icons.error_rounded),
  StockStatus.low => (AppColors.statusSerious, Icons.warning_rounded),
  StockStatus.nearLow => (AppColors.statusWarning, Icons.info_rounded),
  StockStatus.ok => (AppColors.statusGood, Icons.check_circle_rounded),
};

/// Status stok: selalu ikon + label, tidak hanya warna.
class StockStatusChip extends StatelessWidget {
  const StockStatusChip({super.key, required this.status});

  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = stockStatusStyle(status);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
