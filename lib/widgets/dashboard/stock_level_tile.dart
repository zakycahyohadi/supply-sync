import 'package:flutter/material.dart';

import '../../data/sales_analytics.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../product_card.dart';
import 'stock_status_chip.dart';

/// Keterangan singkat stok, contoh "Sisa 2 unit (min 4) · habis ±3 hari lagi".
String stockForecastText(StockLevel level) {
  final daysLeft = level.daysLeft;
  return switch (level.status) {
    StockStatus.out => 'Habis per ${formatDayMonth(level.asOf)}',
    _ when daysLeft == null =>
      'Tidak ada penjualan $kSalesVelocityDays hari terakhir',
    _ => 'Perkiraan habis ±${daysLeft.floor()} hari lagi',
  };
}

/// Satu baris stok produk: sisa stok, perkiraan habis, dan statusnya.
class StockLevelTile extends StatelessWidget {
  const StockLevelTile({super.key, required this.level, this.showStore = true});

  final StockLevel level;
  final bool showStore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final minStock = level.minStock;

    final stockLine = [
      if (showStore) level.storeName,
      'Sisa ${level.stock} unit${minStock == null ? '' : ' (min $minStock)'}',
    ].join(' · ');

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              productCategoryIcon(level.category),
              size: 20,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        level.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StockStatusChip(status: level.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stockLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  stockForecastText(level),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (level.incoming > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          size: 14,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${level.incoming} unit sedang dikirim',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

/// Daftar stok. Kosong = pesan "semua aman".
class StockLevelList extends StatelessWidget {
  const StockLevelList({
    super.key,
    required this.levels,
    this.showStore = true,
    this.emptyMessage = 'Semua stok aman.',
  });

  final List<StockLevel> levels;
  final bool showStore;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) {
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

    return Column(
      children: [
        for (var i = 0; i < levels.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          StockLevelTile(level: levels[i], showStore: showStore),
        ],
      ],
    );
  }
}
