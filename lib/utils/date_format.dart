const _monthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
const _monthsLong = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];
const _weekdaysShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _weekdaysLong = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// "17 Sep 2026"
String formatDate(DateTime date) =>
    '${date.day} ${_monthsShort[date.month - 1]} ${date.year}';

/// "17 Sep"
String formatDayMonth(DateTime date) =>
    '${date.day} ${_monthsShort[date.month - 1]}';

/// "September 2026"
String formatMonthYear(DateTime date) =>
    '${_monthsLong[date.month - 1]} ${date.year}';

/// "17 Sep 2026, 09.30"
String formatDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)}, $hour.$minute';
}

/// "1–7 Sep 2026", "29 Sep – 5 Okt 2026", atau "29 Des 2025 – 4 Jan 2026".
String formatDateRange(DateTime start, DateTime end) {
  if (start.year != end.year) {
    return '${formatDate(start)} – ${formatDate(end)}';
  }
  if (start.month != end.month) {
    return '${formatDayMonth(start)} – ${formatDate(end)}';
  }
  return '${start.day}–${formatDate(end)}';
}

/// "Sen" untuk [DateTime.monday], dst.
String weekdayShort(int weekday) => _weekdaysShort[weekday - 1];

/// "Senin" untuk [DateTime.monday], dst.
String weekdayLong(int weekday) => _weekdaysLong[weekday - 1];

/// "Senin, 8 Sep 2026"
String formatWeekdayDate(DateTime date) =>
    '${weekdayLong(date.weekday)}, ${formatDate(date)}';

/// Satu tanggal atau rentang, contoh "8 Sep 2026" / "8–14 Sep 2026".
String formatPeriod(DateTime start, DateTime end) =>
    start.year == end.year && start.month == end.month && start.day == end.day
    ? formatDate(start)
    : formatDateRange(start, end);

/// Jarak waktu singkat untuk notifikasi: "Baru saja", "5 menit lalu",
/// "3 jam lalu", "Kemarin", "3 hari lalu"; lebih dari seminggu pakai tanggal.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(time);
  if (difference.isNegative || difference.inMinutes < 1) return 'Baru saja';
  if (difference.inMinutes < 60) return '${difference.inMinutes} menit lalu';
  if (difference.inHours < 24) return '${difference.inHours} jam lalu';
  if (difference.inDays == 1) return 'Kemarin';
  if (difference.inDays < 7) return '${difference.inDays} hari lalu';
  return formatDate(time);
}
