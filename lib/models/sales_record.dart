/// Satu baris data penjualan: satu produk, di satu toko, pada satu tanggal.
class SalesRecord {
  const SalesRecord({
    required this.storeName,
    required this.date,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.stockEnd,
    this.category,
    this.minStock,
    this.uploadId,
    this.uploadedAt,
  });

  /// Membaca satu baris dari array `rows` di dokumen upload.
  factory SalesRecord.fromRowJson(
    Map<String, Object?> json, {
    required String storeName,
    String? uploadId,
    DateTime? uploadedAt,
  }) {
    return SalesRecord(
      storeName: storeName,
      date: DateTime.parse(json['date']! as String),
      productCode: json['product_code']! as String,
      productName: json['product_name']! as String,
      category: json['category'] as String?,
      quantity: (json['quantity']! as num).toInt(),
      unitPrice: (json['unit_price']! as num).toInt(),
      stockEnd: (json['stock_end']! as num).toInt(),
      minStock: (json['min_stock'] as num?)?.toInt(),
      uploadId: uploadId,
      uploadedAt: uploadedAt,
    );
  }

  final String storeName;

  /// Tanggal saja (jam diabaikan).
  final DateTime date;
  final String productCode;
  final String productName;
  final String? category;
  final int quantity;
  final int unitPrice;

  /// Sisa stok di akhir hari.
  final int stockEnd;

  /// Batas stok minimum; kalau stok di bawah ini muncul peringatan.
  final int? minStock;

  /// Upload asal baris ini.
  final String? uploadId;

  /// Waktu upload asal baris ini. Pengiriman yang diterima setelah waktu ini
  /// ditambahkan ke [stockEnd].
  final DateTime? uploadedAt;

  int get revenue => quantity * unitPrice;

  /// Kunci unik per toko + tanggal + produk. Kalau ada beberapa upload dengan
  /// kunci sama, yang dipakai upload terbaru.
  String get key => '${storeName}_${formatIsoDate(date)}_$productCode';

  /// Satu baris di array `rows` dokumen upload. Toko & waktu upload tidak
  /// diulang per baris supaya dokumen tetap kecil.
  Map<String, Object?> toRowJson() => {
    'date': formatIsoDate(date),
    'product_code': productCode,
    'product_name': productName,
    'category': category,
    'quantity': quantity,
    'unit_price': unitPrice,
    'stock_end': stockEnd,
    'min_stock': minStock,
  };

  SalesRecord copyWith({
    String? storeName,
    String? uploadId,
    DateTime? uploadedAt,
  }) {
    return SalesRecord(
      storeName: storeName ?? this.storeName,
      date: date,
      productCode: productCode,
      productName: productName,
      category: category,
      quantity: quantity,
      unitPrice: unitPrice,
      stockEnd: stockEnd,
      minStock: minStock,
      uploadId: uploadId ?? this.uploadId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}

/// "2026-09-08"
String formatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Buang jam, sisakan tanggal.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Senin di minggu yang sama.
DateTime weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));
