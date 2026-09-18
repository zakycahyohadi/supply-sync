import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/store_colors.dart';
import '../../utils/currency.dart';
import '../../utils/date_format.dart';
import 'chart_utils.dart';

/// Grafik garis omzet harian, satu garis per toko.
class StoreTrendChart extends StatelessWidget {
  const StoreTrendChart({
    super.key,
    required this.days,
    required this.revenueByStore,
    this.height = 240,
  });

  /// Tanggal, urut lama ke baru. Jadi sumbu X.
  final List<DateTime> days;

  /// Omzet per toko per hari.
  final Map<String, Map<DateTime, int>> revenueByStore;

  final double height;

  @override
  Widget build(BuildContext context) {
    final stores = revenueByStore.keys.toList();
    final isSingleSeries = stores.length == 1;

    var maxValue = 0;
    for (final storeWeeks in revenueByStore.values) {
      for (final value in storeWeeks.values) {
        if (value > maxValue) maxValue = value;
      }
    }
    final interval = niceInterval(maxValue.toDouble());
    final maxY = niceMaxY(maxValue.toDouble(), interval);

    final bars = [
      for (final store in stores)
        _lineFor(
          color: storeColor(store),
          spots: [
            for (var i = 0; i < days.length; i++)
              if (revenueByStore[store]![days[i]] != null)
                FlSpot(
                  i.toDouble(),
                  revenueByStore[store]![days[i]]!.toDouble(),
                ),
          ],
          showArea: isSingleSeries,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend hanya perlu kalau ada lebih dari satu toko.
        if (!isSingleSeries) ...[
          ChartLegend(
            items: [
              for (final store in stores)
                (label: store, color: storeColor(store)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: days.length <= 1 ? 1 : (days.length - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              lineBarsData: bars,
              clipData: const FlClipData.none(),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (value) =>
                    const FlLine(color: AppColors.chartGrid, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  bottom: BorderSide(color: AppColors.chartBaseline),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: interval,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        value == 0 ? '0' : formatCompactNumber(value),
                        style: chartAxisTextStyle,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      // Maksimal ±7 label supaya tidak berdempetan.
                      final every = (days.length / 7).ceil().clamp(1, 31);
                      if (value != index ||
                          index < 0 ||
                          index >= days.length ||
                          index % every != 0) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${days[index].day}',
                          style: chartAxisTextStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                getTouchedSpotIndicator: (barData, spotIndexes) => [
                  for (final _ in spotIndexes)
                    TouchedSpotIndicatorData(
                      const FlLine(
                        color: AppColors.chartBaseline,
                        strokeWidth: 1,
                      ),
                      FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 5,
                              color: bar.color ?? AppColors.navy,
                              strokeWidth: 2,
                              strokeColor: AppColors.surface,
                            ),
                      ),
                    ),
                ],
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppColors.navy,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  maxContentWidth: 180,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    final sorted = [...touchedSpots]
                      ..sort((a, b) => a.barIndex.compareTo(b.barIndex));
                    return [
                      for (final spot in touchedSpots)
                        () {
                          final isFirst = spot == sorted.first;
                          final store = stores[spot.barIndex];
                          final day = days[spot.x.round()];
                          return LineTooltipItem(
                            isFirst
                                ? '${weekdayLong(day.weekday)}, ${formatDayMonth(day)}\n'
                                : '',
                            chartTooltipTitleStyle,
                            textAlign: TextAlign.left,
                            children: [
                              TextSpan(
                                text: '● ',
                                style: TextStyle(color: storeColor(store)),
                              ),
                              TextSpan(
                                text: '$store  ${formatCompactRupiah(spot.y)}',
                                style: chartTooltipValueStyle,
                              ),
                            ],
                          );
                        }(),
                    ];
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  LineChartBarData _lineFor({
    required Color color,
    required List<FlSpot> spots,
    required bool showArea,
  }) {
    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2,
      isCurved: true,
      preventCurveOverShooting: true,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      // Titik hanya di data terakhir, dengan cincin putih.
      dotData: FlDotData(
        checkToShowDot: (spot, barData) => spot == barData.spots.last,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: AppColors.surface,
        ),
      ),
      belowBarData: BarAreaData(
        show: showArea,
        color: color.withValues(alpha: 0.10),
      ),
    );
  }
}
