import 'sales_record.dart';

/// Satu kali upload file XLSX: ringkasan + semua barisnya.
///
/// Disimpan sebagai SATU dokumen JSON (baris ada di array `rows`), jadi satu
/// upload = satu kali tulis ke database.
class SalesUpload {
  const SalesUpload({
    required this.id,
    required this.storeName,
    required this.uploadedBy,
    required this.uploadedByEmail,
    required this.uploadedAt,
    required this.fileName,
    required this.periodStart,
    required this.periodEnd,
    required this.reportMonth,
    required this.productCount,
    required this.totalRevenue,
    required this.totalQuantity,
    required this.records,
  });

  /// Ringkasan dihitung dari baris-barisnya. [reportMonth] kosong = bulan
  /// dari tanggal paling awal.
  factory SalesUpload.fromRecords({
    required String id,
    required String storeName,
    required String uploadedBy,
    required String uploadedByEmail,
    required DateTime uploadedAt,
    required String fileName,
    required List<SalesRecord> records,
    DateTime? reportMonth,
  }) {
    if (records.isEmpty) {
      throw ArgumentError.value(records, 'records', 'tidak boleh kosong');
    }
    final rows = [
      for (final record in records)
        record.copyWith(
          storeName: storeName,
          uploadId: id,
          uploadedAt: uploadedAt,
        ),
    ];
    var start = rows.first.date;
    var end = rows.first.date;
    var revenue = 0;
    var quantity = 0;
    final products = <String>{};
    for (final row in rows) {
      if (row.date.isBefore(start)) start = row.date;
      if (row.date.isAfter(end)) end = row.date;
      revenue += row.revenue;
      quantity += row.quantity;
      products.add(row.productCode);
    }

    return SalesUpload(
      id: id,
      storeName: storeName,
      uploadedBy: uploadedBy,
      uploadedByEmail: uploadedByEmail,
      uploadedAt: uploadedAt,
      fileName: fileName,
      periodStart: start,
      periodEnd: end,
      reportMonth: DateTime(
        (reportMonth ?? start).year,
        (reportMonth ?? start).month,
      ),
      productCount: products.length,
      totalRevenue: revenue,
      totalQuantity: quantity,
      records: rows,
    );
  }

  /// [json] memakai `DateTime` untuk `uploaded_at` (lapisan Firestore yang
  /// mengubah Timestamp jadi DateTime).
  factory SalesUpload.fromJson(String id, Map<String, Object?> json) {
    final storeName = json['store_name']! as String;
    final uploadedAt = json['uploaded_at']! as DateTime;
    final periodStart = DateTime.parse(json['period_start']! as String);
    // Upload lama belum punya report_month: pakai bulan tanggal awal.
    final reportMonth = json['report_month'] is String
        ? DateTime.parse('${json['report_month']}-01')
        : DateTime(periodStart.year, periodStart.month);
    return SalesUpload(
      id: id,
      storeName: storeName,
      uploadedBy: json['uploaded_by']! as String,
      uploadedByEmail: json['uploaded_by_email']! as String,
      uploadedAt: uploadedAt,
      fileName: json['file_name']! as String,
      periodStart: periodStart,
      periodEnd: DateTime.parse(json['period_end']! as String),
      reportMonth: reportMonth,
      productCount: (json['product_count']! as num).toInt(),
      totalRevenue: (json['total_revenue']! as num).toInt(),
      totalQuantity: (json['total_quantity']! as num).toInt(),
      records: [
        for (final row in json['rows']! as List)
          SalesRecord.fromRowJson(
            Map<String, Object?>.from(row as Map),
            storeName: storeName,
            uploadId: id,
            uploadedAt: uploadedAt,
          ),
      ],
    );
  }

  final String id;
  final String storeName;
  final String uploadedBy;
  final String uploadedByEmail;
  final DateTime uploadedAt;
  final String fileName;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Bulan laporan yang dipilih admin toko saat upload (tanggal 1).
  final DateTime reportMonth;
  final int productCount;
  final int totalRevenue;
  final int totalQuantity;
  final List<SalesRecord> records;

  int get rowCount => records.length;

  Map<String, Object?> toJson() => {
    'store_name': storeName,
    'uploaded_by': uploadedBy,
    'uploaded_by_email': uploadedByEmail,
    'uploaded_at': uploadedAt,
    'file_name': fileName,
    'period_start': formatIsoDate(periodStart),
    'period_end': formatIsoDate(periodEnd),
    'report_month': formatIsoDate(reportMonth).substring(0, 7),
    'row_count': rowCount,
    'product_count': productCount,
    'total_revenue': totalRevenue,
    'total_quantity': totalQuantity,
    'rows': [for (final record in records) record.toRowJson()],
  };
}

/// Gabungkan baris dari semua upload. Kalau toko + tanggal + produk sama ada
/// di beberapa upload, yang dipakai dari upload paling baru.
List<SalesRecord> latestRecords(Iterable<SalesUpload> uploads) {
  final sorted = uploads.toList()
    ..sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
  final byKey = <String, SalesRecord>{};
  for (final upload in sorted) {
    for (final record in upload.records) {
      byKey[record.key] = record;
    }
  }
  return byKey.values.toList();
}
