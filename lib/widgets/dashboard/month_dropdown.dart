import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';

/// Pilihan periode per bulan, contoh "September 2026".
class MonthDropdown extends StatelessWidget {
  const MonthDropdown({
    super.key,
    required this.months,
    required this.selected,
    required this.onChanged,
  });

  /// Bulan (tanggal 1) yang bisa dipilih, terbaru dulu.
  final List<DateTime> months;
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: selected,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: AppColors.surface,
          icon: const Icon(
            Icons.expand_more_rounded,
            color: AppColors.textSecondary,
          ),
          items: [
            for (final month in months)
              DropdownMenuItem(
                value: month,
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        formatMonthYear(month),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (month) {
            if (month != null) onChanged(month);
          },
        ),
      ),
    );
  }
}
