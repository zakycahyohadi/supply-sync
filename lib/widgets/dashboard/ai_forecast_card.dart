import 'package:flutter/material.dart';

import '../../models/ai_forecast.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency.dart';
import '../../utils/date_format.dart';
import 'section_card.dart';

/// Kartu hasil analisis AI di dashboard admin pusat.
///
/// Tiga keadaan: sedang menganalisis, gagal (dashboard tetap jalan dengan
/// catatan otomatis biasa), dan berhasil.
class AiForecastCard extends StatelessWidget {
  const AiForecastCard({
    super.key,
    required this.forecast,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
  });

  final AiForecast? forecast;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final forecast = this.forecast;
    final errorMessage = this.errorMessage;

    return SectionCard(
      title: 'Analisis AI',
      subtitle: forecast == null
          ? 'Membaca tren dan menyiapkan perkiraan bulan depan'
          : 'Dibuat ${forecast.model} · ${formatRelativeTime(forecast.generatedAt)}',
      icon: Icons.auto_awesome_rounded,
      trailing: onRetry == null || isLoading
          ? null
          : IconButton(
              tooltip: 'Analisis ulang',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: AppColors.textSecondary,
            ),
      child: switch ((isLoading, forecast, errorMessage)) {
        (true, _, _) => const _Loading(),
        (_, final AiForecast result, _) => _Result(forecast: result),
        (_, _, final String message) => _Error(message: message),
        _ => const _Error(message: 'Analisis AI belum tersedia.'),
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Menganalisis data penjualan…',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.cloud_off_rounded,
          size: 20,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Catatan otomatis di bawah tetap bisa dipakai.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.forecast});

  final AiForecast forecast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Yang turun ditaruh dulu: itu yang perlu ditindak.
    final trends = [...forecast.downTrends, ...forecast.upTrends];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (forecast.summary.isNotEmpty) ...[
          Text(
            forecast.summary,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _OutlookBox(outlook: forecast.outlook),
        if (trends.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _Label('Yang bergerak bulan ini'),
          const SizedBox(height: 8),
          for (final (index, trend) in trends.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            _TrendRow(trend: trend),
          ],
        ],
        if (forecast.restocks.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _Label('Siapkan untuk bulan depan'),
          const SizedBox(height: 8),
          for (final (index, restock) in forecast.restocks.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            _RestockRow(restock: restock),
          ],
        ],
        if (forecast.recommendations.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _Label('Saran tindakan'),
          const SizedBox(height: 8),
          for (final recommendation in forecast.recommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 14),
        const Text(
          'Perkiraan dibuat AI dari ringkasan data yang sudah dihitung '
          'aplikasi. Angka pasti tetap ada di bagian lain dashboard.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// Perkiraan bulan depan; bagian yang paling dicari, jadi dibedakan.
class _OutlookBox extends StatelessWidget {
  const _OutlookBox({required this.outlook});

  final AiOutlook outlook;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final confidenceColor = switch (outlook.confidence) {
      AiConfidence.high => AppColors.statusGood,
      AiConfidence.medium => AppColors.statusWarning,
      AiConfidence.low => AppColors.textMuted,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                size: 16,
                color: AppColors.navy,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Perkiraan bulan depan',
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: confidenceColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  outlook.confidence.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Wrap, bukan Row: di layar kecil jumlah unit turun ke baris
          // berikutnya, tidak memaksa keluar layar.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                formatCompactRupiah(outlook.revenue),
                style: textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '± ${formatThousands(outlook.units)} unit',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (outlook.basis.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              outlook.basis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});

  final AiTrend trend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = switch (trend.direction) {
      AiTrendDirection.up => AppColors.deltaUp,
      AiTrendDirection.down => AppColors.deltaDown,
      AiTrendDirection.flat => AppColors.textSecondary,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: 8),
          child: Text(
            trend.direction.emoji,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trend.title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (trend.reason.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  trend.reason,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RestockRow extends StatelessWidget {
  const _RestockRow({required this.restock});

  final AiRestock restock;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          margin: const EdgeInsets.only(right: 10, top: 1),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${restock.quantity}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restock.storeName.isEmpty
                    ? restock.productName
                    : '${restock.productName} · ${restock.storeName}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (restock.reason.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  restock.reason,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
      ),
    );
  }
}
