import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/currency.dart';
import '../../utils/date_format.dart';
import 'chart_utils.dart';

typedef DailyRevenue = ({DateTime date, int revenue});

/// Grafik batang omzet per hari. Lebar batang dan label menyesuaikan jumlah
/// hari (seminggu atau sebulan).
class DailyRevenueChart extends StatelessWidget {
  const DailyRevenueChart({super.key, required this.days, this.height = 220});

  final List<DailyRevenue> days;
  final double height;

  static const _leftTitleWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold(0, (max, d) => math.max(max, d.revenue));
    final interval = niceInterval(maxValue.toDouble());
    final maxY = niceMaxY(maxValue.toDouble(), interval);
    final color = AppColors.series.first;
    final isWeek = days.length <= 7;
    // Maksimal ±8 label di sumbu bawah.
    final labelEvery = math.max(1, (days.length / 8).ceil());

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot =
            (constraints.maxWidth - _leftTitleWidth) / math.max(1, days.length);
        final barWidth = (slot * 0.6).clamp(4.0, 24.0);

        return SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: days[i].revenue.toDouble(),
                        color: color,
                        width: barWidth,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(math.min(4, barWidth / 2)),
                        ),
                      ),
                    ],
                  ),
              ],
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
                    reservedSize: _leftTitleWidth,
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
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 ||
                          index >= days.length ||
                          index % labelEvery != 0) {
                        return const SizedBox.shrink();
                      }
                      final date = days[index].date;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          isWeek ? weekdayShort(date.weekday) : '${date.day}',
                          style: chartAxisTextStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => AppColors.navy,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  tooltipMargin: 8,
                  maxContentWidth: 180,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = days[group.x];
                    return BarTooltipItem(
                      '${weekdayLong(day.date.weekday)}, ${formatDayMonth(day.date)}\n',
                      chartTooltipTitleStyle,
                      children: [
                        TextSpan(
                          text: formatRupiah(day.revenue),
                          style: chartTooltipValueStyle,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
