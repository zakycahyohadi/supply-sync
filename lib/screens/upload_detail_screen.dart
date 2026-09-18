import 'package:flutter/material.dart';

import '../data/sales_analytics.dart';
import '../models/sales_record.dart';
import '../models/sales_upload.dart';
import '../theme/app_colors.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import '../widgets/charts/daily_revenue_chart.dart';
import '../widgets/charts/ranked_bars.dart';
import '../widgets/dashboard/page_body.dart';
import '../widgets/dashboard/section_card.dart';
import '../widgets/dashboard/stat_tile.dart';
import '../widgets/dashboard/stock_level_tile.dart';
import '../widgets/app_header.dart';
import '../widgets/dashboard/spotlight.dart';

/// Isi satu upload: omzet harian, rincian produk, dan stok akhirnya.
class UploadDetailScreen extends StatelessWidget {
  const UploadDetailScreen({super.key, required this.upload});

  final SalesUpload upload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Detail Upload',
        subtitle: upload.storeName,
        showBackButton: true,
      ),
      body: PageBody(
        children: [
          _UploadHeader(upload: upload),
          const SizedBox(height: 16),
          ..._buildContent(upload.records),
        ],
      ),
    );
  }

  List<Widget> _buildContent(List<SalesRecord> records) {
    final dailyTotals = <DateTime, int>{};
    final products = <String, ({String name, int quantity, int revenue})>{};
    for (final record in records) {
      dailyTotals.update(
        record.date,
        (v) => v + record.revenue,
        ifAbsent: () => record.revenue,
      );
      final current = products[record.productCode];
      products[record.productCode] = (
        name: record.productName,
        quantity: (current?.quantity ?? 0) + record.quantity,
        revenue: (current?.revenue ?? 0) + record.revenue,
      );
    }
    final days = [
      for (final entry in dailyTotals.entries)
        (date: entry.key, revenue: entry.value),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final productList = products.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final stockLevels = computeStockLevels(records);

    return [
      StatTileGrid(
        children: [
          StatTile(
            label: 'Omzet',
            value: formatCompactRupiah(days.fold(0, (s, d) => s + d.revenue)),
            icon: Icons.payments_outlined,
          ),
          StatTile(
            label: 'Unit terjual',
            value: formatThousands(
              productList.fold(0, (s, p) => s + p.quantity),
            ),
            icon: Icons.shopping_bag_outlined,
          ),
          StatTile(
            label: 'Produk',
            value: '${productList.length}',
            icon: Icons.category_outlined,
          ),
          StatTile(
            label: 'Baris data',
            value: '${records.length}',
            icon: Icons.table_rows_outlined,
          ),
        ],
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Omzet harian',
        subtitle: 'Ketuk batang untuk melihat angka lengkap (Rp)',
        icon: Icons.bar_chart_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DailyRevenueChart(days: days),
            const SizedBox(height: 8),
            _DailyTable(days: days),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Rincian produk',
        subtitle: 'Berdasarkan omzet',
        icon: Icons.local_fire_department_outlined,
        child: RankedBars(
          items: [
            for (final product in productList)
              RankedBarItem(
                label: product.name,
                detail: '${product.quantity} unit',
                value: product.revenue,
                valueLabel: formatCompactRupiah(product.revenue),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Stok akhir',
        subtitle: 'Per ${formatDate(upload.periodEnd)}',
        icon: Icons.inventory_2_outlined,
        child: StockLevelList(levels: stockLevels, showStore: false),
      ),
    ];
  }
}

class _UploadHeader extends StatelessWidget {
  const _UploadHeader({required this.upload});

  final SalesUpload upload;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: spotlightDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            upload.storeName,
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Laporan ${formatMonthYear(upload.reportMonth)} · '
            '${formatPeriod(upload.periodStart, upload.periodEnd)}',
            style: textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _HeaderInfo(icon: Icons.table_chart_outlined, text: upload.fileName),
          const SizedBox(height: 6),
          _HeaderInfo(
            icon: Icons.person_outline_rounded,
            text: '${upload.uploadedBy} · ${formatDateTime(upload.uploadedAt)}',
          ),
        ],
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  const _HeaderInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Angka lengkap di bawah grafik, supaya bisa dibaca tanpa menyentuh grafik.
class _DailyTable extends StatelessWidget {
  const _DailyTable({required this.days});

  final List<DailyRevenue> days;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'Lihat tabel',
          style: textTheme.labelLarge?.copyWith(color: AppColors.navy),
        ),
        children: [
          for (final day in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatWeekdayDate(day.date),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    formatRupiah(day.revenue),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
