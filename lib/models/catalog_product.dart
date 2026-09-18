import 'sales_record.dart';

/// Stok satu produk di satu toko, untuk ditampilkan di katalog publik.
class StoreStock {
  const StoreStock({required this.stock, this.asOf});

  factory StoreStock.fromJson(Map<String, Object?> json) => StoreStock(
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    asOf: json['as_of'] == null
        ? null
        : DateTime.parse(json['as_of']! as String),
  );

  final int stock;

  /// Tanggal data upload terakhir yang mengisi stok ini.
  final DateTime? asOf;

  Map<String, Object?> toJson() => {
    'stock': stock,
    'as_of': asOf == null ? null : formatIsoDate(asOf!),
  };
}

/// Produk resmi di katalog (koleksi `products`, ID dokumen = kode produk).
///
/// Admin toko hanya bisa meng-upload data produk yang ada di sini, dengan
/// kode & nama yang sama persis.
class CatalogProduct {
  const CatalogProduct({
    required this.code,
    required this.name,
    required this.category,
    required this.price,
    required this.minStock,
    this.imageUrl,
    this.isActive = true,
    this.stockByStore = const {},
    this.updatedAt,
  });

  /// [json] memakai `DateTime` untuk `updated_at`.
  factory CatalogProduct.fromJson(String code, Map<String, Object?> json) {
    final stock = json['stock_by_store'] as Map? ?? const {};
    return CatalogProduct(
      code: code,
      name: json['name']! as String,
      category: json['category']! as String,
      price: (json['price']! as num).toInt(),
      minStock: (json['min_stock'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      stockByStore: {
        for (final entry in stock.entries)
          entry.key as String: StoreStock.fromJson(
            Map<String, Object?>.from(entry.value as Map),
          ),
      },
      updatedAt: json['updated_at'] as DateTime?,
    );
  }

  final String code;
  final String name;

  /// Salah satu label [ProductCategory], misalnya iPhone atau Audio.
  final String category;

  /// Harga jual dalam Rupiah.
  final int price;
  final int minStock;
  final String? imageUrl;

  /// Produk nonaktif tidak tampil di homepage dan tidak bisa di-upload.
  final bool isActive;

  /// Nama toko → stok terakhir.
  final Map<String, StoreStock> stockByStore;
  final DateTime? updatedAt;

  int get totalStock =>
      stockByStore.values.fold(0, (sum, stock) => sum + stock.stock);

  /// Toko yang stoknya masih ada.
  List<String> get storesInStock => [
    for (final entry in stockByStore.entries)
      if (entry.value.stock > 0) entry.key,
  ]..sort();

  /// Data katalog yang diedit admin pusat (tanpa stok).
  Map<String, Object?> toCatalogJson() => {
    'code': code,
    'name': name,
    'category': category,
    'price': price,
    'min_stock': minStock,
    'image_url': imageUrl,
    'is_active': isActive,
    'updated_at': updatedAt,
  };

  Map<String, Object?> toJson() => {
    ...toCatalogJson(),
    'stock_by_store': {
      for (final entry in stockByStore.entries) entry.key: entry.value.toJson(),
    },
  };

  CatalogProduct copyWith({
    String? name,
    String? category,
    int? price,
    int? minStock,
    String? imageUrl,
    bool clearImageUrl = false,
    bool? isActive,
    Map<String, StoreStock>? stockByStore,
    DateTime? updatedAt,
  }) {
    return CatalogProduct(
      code: code,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      minStock: minStock ?? this.minStock,
      imageUrl: clearImageUrl ? null : imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      stockByStore: stockByStore ?? this.stockByStore,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Untuk membandingkan nama: huruf besar/kecil dan spasi ganda diabaikan.
String normalizeProductName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Stok terakhir per kode produk dari baris-baris upload (tanggal terbaru).
Map<String, StoreStock> latestStockByProduct(Iterable<SalesRecord> records) {
  final latest = <String, SalesRecord>{};
  for (final record in records) {
    final current = latest[record.productCode];
    if (current == null || !record.date.isBefore(current.date)) {
      latest[record.productCode] = record;
    }
  }
  return {
    for (final entry in latest.entries)
      entry.key: StoreStock(
        stock: entry.value.stockEnd,
        asOf: entry.value.date,
      ),
  };
}
