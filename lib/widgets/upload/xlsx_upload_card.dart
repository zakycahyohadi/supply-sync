import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/sales_repository.dart';
import '../../data/xlsx/sales_sheet_format.dart';
import '../../data/xlsx/sales_sheet_parser.dart';
import '../../data/xlsx/sales_template.dart';
import '../../models/app_user.dart';
import '../../models/sales_record.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency.dart';
import '../../utils/date_format.dart';
import '../dashboard/month_dropdown.dart';
import '../dashboard/section_card.dart';

/// Form upload data penjualan (.xlsx): pilih file → dicek → preview → simpan.
class XlsxUploadCard extends StatefulWidget {
  const XlsxUploadCard({super.key, required this.user});

  final AppUser user;

  @override
  State<XlsxUploadCard> createState() => _XlsxUploadCardState();
}

class _XlsxUploadCardState extends State<XlsxUploadCard> {
  static const _maxFileBytes = 5 * 1024 * 1024;
  static const _maxIssuesShown = 5;

  /// Bulan yang bisa dipilih: bulan ini dan 11 bulan sebelumnya.
  static const _monthCount = 12;

  late final List<DateTime> _months = () {
    final now = DateTime.now();
    return [
      for (var i = 0; i < _monthCount; i++) DateTime(now.year, now.month - i),
    ];
  }();

  /// Bulan laporan yang dipilih; default bulan ini.
  late DateTime _month = _months.first;

  String? _fileName;

  /// Isi file terakhir, supaya bisa dicek ulang saat bulan diganti.
  Uint8List? _bytes;
  ParsedSalesSheet? _parsed;
  int _existingRows = 0;
  String? _error;
  bool _isReading = false;
  bool _isSaving = false;

  bool get _isBusy => _isReading || _isSaving;

  void _reset() => setState(() {
    _fileName = null;
    _bytes = null;
    _parsed = null;
    _existingRows = 0;
    _error = null;
  });

  Future<void> _pickFile() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'File tidak bisa dibuka. Coba lagi.');
      }
      return;
    }
    if (file == null || !mounted) return;

    setState(() {
      _isReading = true;
      _fileName = file!.name;
      _parsed = null;
      _error = null;
    });

    try {
      if (file.extension?.toLowerCase() != 'xlsx') {
        throw const SalesSheetException('File harus berformat .xlsx.');
      }
      final size = file.lengthSync() ?? await file.length();
      if (size != null && size > _maxFileBytes) {
        throw const SalesSheetException('Ukuran file maksimal 5 MB.');
      }

      final bytes = await file.readAsBytes();
      _bytes = bytes;
      await _check(bytes);
    } on SalesSheetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'File tidak bisa dibaca. Pastikan formatnya .xlsx.',
        );
      }
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  /// Baca & cek isi file terhadap katalog dan bulan yang dipilih.
  Future<void> _check(Uint8List bytes) async {
    final catalog = await SalesRepository.instance.watchProducts().first;
    final parsed = await compute(parseSalesSheetInBackground, (
      bytes: bytes,
      storeName: widget.user.storeName!,
      today: DateTime.now(),
      catalog: catalog,
      month: _month,
    ));
    final existing = await SalesRepository.instance.countExistingRecords(
      parsed.records,
    );
    if (!mounted) return;
    setState(() {
      _parsed = parsed;
      _existingRows = existing;
    });
  }

  Future<void> _changeMonth(DateTime month) async {
    if (month == _month) return;
    setState(() => _month = month);
    final bytes = _bytes;
    if (bytes == null) return;

    setState(() {
      _isReading = true;
      _parsed = null;
      _error = null;
    });
    try {
      await _check(bytes);
    } on SalesSheetException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  Future<void> _save() async {
    final parsed = _parsed;
    final fileName = _fileName;
    if (parsed == null || fileName == null || !parsed.canSubmit) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final upload = await SalesRepository.instance.saveUpload(
        user: widget.user,
        fileName: fileName,
        reportMonth: _month,
        records: parsed.records,
      );
      if (!mounted) return;
      _reset();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Tersimpan: laporan ${formatMonthYear(upload.reportMonth)}, '
              '${upload.rowCount} baris '
              '(${formatPeriod(upload.periodStart, upload.periodEnd)}).',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan data. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveTemplate() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final catalog = await SalesRepository.instance.watchProducts().first;
      final monthKey = formatIsoDate(_month).substring(0, 7);
      final uri = await FilePicker.saveFile(
        fileName: 'template_penjualan_$monthKey.xlsx',
        bytes: buildSalesTemplate(catalog, month: _month),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (uri == null) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Template tersimpan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Template gagal disimpan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final error = _error;
    final fileName = _fileName;

    return SectionCard(
      title: 'Upload data penjualan',
      subtitle: 'File .xlsx, satu baris per produk per hari',
      icon: Icons.upload_file_rounded,
      trailing: TextButton.icon(
        onPressed: _isBusy ? null : _saveTemplate,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Template'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Periode laporan',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          AbsorbPointer(
            absorbing: _isBusy,
            child: MonthDropdown(
              months: _months,
              selected: _month,
              onChanged: _changeMonth,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Semua tanggal di file harus di '
            '${formatPeriod(_month, DateTime(_month.year, _month.month + 1, 0))}.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          if (fileName == null)
            _DropZone(onTap: _isBusy ? null : _pickFile)
          else
            _SelectedFile(
              name: fileName,
              isLoading: _isReading,
              onChange: _isBusy ? null : _pickFile,
              onRemove: _isBusy ? null : _reset,
            ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _MessageBox(
              color: AppColors.danger,
              icon: Icons.error_outline_rounded,
              title: 'File tidak bisa diproses',
              lines: [error],
            ),
          ],
          if (parsed != null) ...[
            const SizedBox(height: 16),
            if (parsed.issues.isNotEmpty)
              _MessageBox(
                color: AppColors.danger,
                icon: Icons.error_outline_rounded,
                title: '${parsed.issues.length} baris perlu diperbaiki',
                lines: [
                  for (final issue in parsed.issues.take(_maxIssuesShown))
                    issue.toString(),
                  if (parsed.issues.length > _maxIssuesShown)
                    '...dan ${parsed.issues.length - _maxIssuesShown} baris lainnya.',
                  'Perbaiki di file lalu pilih ulang.',
                ],
              )
            else ...[
              _PreviewSummary(month: _month, records: parsed.records),
              if (_existingRows > 0) ...[
                const SizedBox(height: 12),
                _MessageBox(
                  color: AppColors.statusWarning,
                  icon: Icons.info_outline_rounded,
                  title: 'Sebagian data akan diganti',
                  lines: [
                    '$_existingRows baris untuk tanggal & produk yang sama sudah '
                        'ada. Data lama akan diganti dengan isi file ini.',
                  ],
                ),
              ],
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: parsed.canSubmit && !_isBusy ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_done_outlined, size: 20),
                label: Text(_isSaving ? 'Menyimpan...' : 'Simpan ke database'),
              ),
            ),
          ],
          if (fileName == null) ...[
            const SizedBox(height: 12),
            const _ColumnGuide(),
          ],
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.navy.withValues(alpha: 0.35),
            radius: 14,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.navy,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pilih file .xlsx',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Maksimal 5 MB · data dicek sebelum disimpan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedFile extends StatelessWidget {
  const _SelectedFile({
    required this.name,
    required this.isLoading,
    required this.onChange,
    required this.onRemove,
  });

  final String name;
  final bool isLoading;
  final VoidCallback? onChange;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart_rounded, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isLoading ? 'Membaca file...' : 'Siap dicek',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Ganti')),
          IconButton(
            tooltip: 'Batal',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({required this.month, required this.records});

  final DateTime month;
  final List<SalesRecord> records;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    var start = records.first.date;
    var end = records.first.date;
    var revenue = 0;
    var quantity = 0;
    final products = <String, ({String name, int quantity, int revenue})>{};
    for (final record in records) {
      if (record.date.isBefore(start)) start = record.date;
      if (record.date.isAfter(end)) end = record.date;
      revenue += record.revenue;
      quantity += record.quantity;
      final current = products[record.productCode];
      products[record.productCode] = (
        name: record.productName,
        quantity: (current?.quantity ?? 0) + record.quantity,
        revenue: (current?.revenue ?? 0) + record.revenue,
      );
    }
    final topProducts = products.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusGood.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.statusGood.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.statusGood,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Format benar, siap disimpan',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Laporan bulan', value: formatMonthYear(month)),
          _SummaryRow(label: 'Tanggal data', value: formatPeriod(start, end)),
          _SummaryRow(label: 'Baris data', value: '${records.length}'),
          _SummaryRow(label: 'Produk', value: '${products.length}'),
          _SummaryRow(label: 'Unit terjual', value: formatThousands(quantity)),
          _SummaryRow(label: 'Total omzet', value: formatRupiah(revenue)),
          const SizedBox(height: 8),
          Text(
            'Produk terlaris di file ini',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          for (final product in topProducts.take(3))
            _SummaryRow(
              label: '${product.name} (${product.quantity} unit)',
              value: formatCompactRupiah(product.revenue),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.color,
    required this.icon,
    required this.title,
    required this.lines,
  });

  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 1.4,
                      ),
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

/// Penjelasan kolom yang dibutuhkan, bisa dibuka-tutup.
class _ColumnGuide extends StatelessWidget {
  const _ColumnGuide();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        title: Text(
          'Kolom yang dibutuhkan',
          style: textTheme.labelLarge?.copyWith(color: AppColors.navy),
        ),
        children: [
          for (final column in SalesColumn.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      column.header,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${column.isRequired ? '' : '(Opsional) '}${column.description}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          Radius.circular(radius),
        ),
      );

    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
