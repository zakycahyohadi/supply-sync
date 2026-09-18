import 'package:flutter/material.dart';

import '../../models/sales_upload.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency.dart';
import '../../utils/date_format.dart';

/// Satu baris riwayat upload file XLSX.
class UploadListTile extends StatelessWidget {
  const UploadListTile({
    super.key,
    required this.upload,
    this.showStore = true,
    this.onTap,
  });

  final SalesUpload upload;

  /// Tampilkan nama toko (untuk admin pusat yang melihat semua toko).
  final bool showStore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final period = formatPeriod(upload.periodStart, upload.periodEnd);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.table_chart_outlined,
                  color: AppColors.navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showStore
                          ? '${upload.storeName} · ${formatMonthYear(upload.reportMonth)}'
                          : 'Laporan ${formatMonthYear(upload.reportMonth)}',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        period,
                        '${upload.rowCount} baris',
                        formatCompactRupiah(upload.totalRevenue),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Diupload ${formatDateTime(upload.uploadedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
