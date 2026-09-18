import 'dart:async';

import '../models/app_user.dart';
import '../models/catalog_product.dart';
import '../models/sales_record.dart';
import '../models/sales_upload.dart';
import '../models/shipment.dart';
import 'apple_catalog.dart';
import 'sales_analytics.dart';
import 'sample_sales_data.dart';

/// Akses katalog produk, data penjualan, dan pengiriman.
///
/// `main.dart` memakai versi Firestore; test memakai versi memori.
abstract class SalesRepository {
  static SalesRepository instance = InMemorySalesRepository();

  /// Katalog produk, urut kategori lalu nama. Bisa dibaca tanpa login.
  Stream<List<CatalogProduct>> watchProducts();

  /// Admin pusat menambah ([isNew]) atau mengubah produk. Stok per toko tidak
  /// ikut diubah.
  Future<void> saveProduct({
    required AppUser user,
    required CatalogProduct product,
    required bool isNew,
  });

  /// Admin pusat menyimpan banyak produk sekaligus (hasil import JSON).
  /// Kode baru ditambahkan, kode lama diperbarui; stok per toko tetap.
  Future<void> saveProducts({
    required AppUser user,
    required List<CatalogProduct> products,
  });

  /// Upload yang periodenya berakhir sejak [since]. [storeName] null = semua.
  Stream<List<SalesUpload>> watchUploads({
    required DateTime since,
    String? storeName,
  });

  /// Simpan hasil baca XLSX sebagai satu dokumen upload untuk bulan
  /// [reportMonth], sekaligus memperbarui stok toko itu di katalog.
  Future<SalesUpload> saveUpload({
    required AppUser user,
    required String fileName,
    required DateTime reportMonth,
    required List<SalesRecord> records,
  });

  /// Pengiriman yang dibuat sejak [since]. [storeName] null = semua toko.
  Stream<List<Shipment>> watchShipments({
    required DateTime since,
    String? storeName,
  });

  Future<Shipment> createShipment({
    required AppUser user,
    required String storeName,
    required List<ShipmentItem> items,
    String? note,
  });

  /// Admin toko mengonfirmasi barang sudah diterima dan sesuai. Stok toko di
  /// katalog bertambah sesuai jumlah kirim.
  Future<void> confirmShipment({
    required AppUser user,
    required Shipment shipment,
  });

  /// Berapa baris (toko + tanggal + produk) yang sudah pernah di-upload dan
  /// akan tergantikan.
  Future<int> countExistingRecords(List<SalesRecord> records) async {
    if (records.isEmpty) return 0;
    final storeName = records.first.storeName;
    final since = records
        .map((r) => r.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final uploads = await watchUploads(
      since: since,
      storeName: storeName,
    ).first;
    final existing = latestRecords(uploads).map((r) => r.key).toSet();
    return records.where((r) => existing.contains(r.key)).length;
  }
}

class InMemorySalesRepository extends SalesRepository {
  /// Katalog selalu diisi produk Apple. [withSampleData] menambah upload
  /// contoh 6 minggu beserta stoknya.
  InMemorySalesRepository({bool withSampleData = true, DateTime? now}) {
    for (final product in appleCatalogProducts()) {
      _products[product.code] = product;
    }
    if (withSampleData) {
      final sample = buildSampleSalesData(now ?? DateTime.now());
      _uploads.addAll(sample.uploads);
      _shipments.addAll(sample.shipments);
      final levels = computeStockLevels(
        latestRecords(_uploads),
        shipments: _shipments,
      );
      for (final level in levels) {
        final product = _products[level.productCode]!;
        _products[level.productCode] = product.copyWith(
          stockByStore: {
            ...product.stockByStore,
            level.storeName: StoreStock(stock: level.stock, asOf: level.asOf),
          },
        );
      }
    }
  }

  final _products = <String, CatalogProduct>{};
  final _uploads = <SalesUpload>[];
  final _shipments = <Shipment>[];
  final _changes = StreamController<void>.broadcast();
  var _nextId = 0;

  @override
  Stream<List<CatalogProduct>> watchProducts() =>
      _watch(() => sortCatalog(_products.values));

  @override
  Future<void> saveProduct({
    required AppUser user,
    required CatalogProduct product,
    required bool isNew,
  }) async {
    if (user.role != UserRole.centralAdmin) {
      throw StateError('Hanya admin pusat yang bisa mengubah katalog.');
    }
    final existing = _products[product.code];
    if (isNew && existing != null) {
      throw StateError('Kode ${product.code} sudah dipakai.');
    }
    if (!isNew && existing == null) {
      throw StateError('Produk ${product.code} tidak ditemukan.');
    }
    _products[product.code] = product.copyWith(
      stockByStore: existing?.stockByStore ?? const {},
      updatedAt: DateTime.now(),
    );
    _changes.add(null);
  }

  @override
  Future<void> saveProducts({
    required AppUser user,
    required List<CatalogProduct> products,
  }) async {
    if (user.role != UserRole.centralAdmin) {
      throw StateError('Hanya admin pusat yang bisa mengubah katalog.');
    }
    final now = DateTime.now();
    for (final product in products) {
      final existing = _products[product.code];
      _products[product.code] = product.copyWith(
        stockByStore: existing?.stockByStore ?? const {},
        updatedAt: now,
      );
    }
    _changes.add(null);
  }

  @override
  Stream<List<SalesUpload>> watchUploads({
    required DateTime since,
    String? storeName,
  }) {
    final start = dateOnly(since);
    return _watch(
      () => [
        for (final upload in _uploads)
          if (!upload.periodEnd.isBefore(start) &&
              (storeName == null || upload.storeName == storeName))
            upload,
      ]..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt)),
    );
  }

  @override
  Future<SalesUpload> saveUpload({
    required AppUser user,
    required String fileName,
    required DateTime reportMonth,
    required List<SalesRecord> records,
  }) async {
    final storeName = user.storeName;
    if (storeName == null) {
      throw StateError('Hanya admin toko yang bisa upload data.');
    }
    final upload = SalesUpload.fromRecords(
      id: 'upload-${_nextId++}',
      storeName: storeName,
      uploadedBy: user.name,
      uploadedByEmail: user.email,
      uploadedAt: DateTime.now(),
      fileName: fileName,
      reportMonth: reportMonth,
      records: records,
    );
    _uploads.add(upload);
    for (final entry in latestStockByProduct(upload.records).entries) {
      final product = _products[entry.key];
      if (product == null) continue;
      final current = product.stockByStore[storeName]?.asOf;
      if (current != null && entry.value.asOf!.isBefore(current)) continue;
      _products[entry.key] = product.copyWith(
        stockByStore: {...product.stockByStore, storeName: entry.value},
      );
    }
    _changes.add(null);
    return upload;
  }

  @override
  Stream<List<Shipment>> watchShipments({
    required DateTime since,
    String? storeName,
  }) {
    return _watch(
      () => [
        for (final shipment in _shipments)
          if (!shipment.createdAt.isBefore(since) &&
              (storeName == null || shipment.storeName == storeName))
            shipment,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<Shipment> createShipment({
    required AppUser user,
    required String storeName,
    required List<ShipmentItem> items,
    String? note,
  }) async {
    if (user.role != UserRole.centralAdmin) {
      throw StateError('Hanya admin pusat yang bisa mengajukan pengiriman.');
    }
    final shipment = Shipment(
      id: 'shipment-${_nextId++}',
      storeName: storeName,
      status: ShipmentStatus.inTransit,
      items: items,
      note: note,
      createdBy: user.name,
      createdByEmail: user.email,
      createdAt: DateTime.now(),
    );
    _shipments.add(shipment);
    _changes.add(null);
    return shipment;
  }

  @override
  Future<void> confirmShipment({
    required AppUser user,
    required Shipment shipment,
  }) async {
    final index = _shipments.indexWhere((s) => s.id == shipment.id);
    final current = index < 0 ? null : _shipments[index];
    if (current == null ||
        current.status != ShipmentStatus.inTransit ||
        user.storeName != current.storeName) {
      throw StateError('Pengiriman tidak bisa dikonfirmasi.');
    }
    _shipments[index] = current.markReceived(
      by: user.name,
      byEmail: user.email,
      at: DateTime.now(),
    );
    for (final item in current.items) {
      final product = _products[item.productCode];
      if (product == null) continue;
      final stock = product.stockByStore[current.storeName];
      _products[item.productCode] = product.copyWith(
        stockByStore: {
          ...product.stockByStore,
          current.storeName: StoreStock(
            stock: (stock?.stock ?? 0) + item.quantity,
            asOf: stock?.asOf,
          ),
        },
      );
    }
    _changes.add(null);
  }

  /// Stream yang langsung mengirim data sekarang, lalu mengirim ulang setiap
  /// kali ada perubahan (mirip snapshot Firestore).
  Stream<T> _watch<T>(T Function() read) {
    StreamSubscription<void>? subscription;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        subscription = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}

/// Urutan katalog: kategori (urutan [ProductCategory]), lalu harga
/// tertinggi.
List<CatalogProduct> sortCatalog(Iterable<CatalogProduct> products) {
  int categoryIndex(CatalogProduct product) {
    final category = ProductCategory.fromLabel(product.category);
    return category?.index ?? ProductCategory.values.length;
  }

  return products.toList()..sort((a, b) {
    final byCategory = categoryIndex(a).compareTo(categoryIndex(b));
    return byCategory != 0 ? byCategory : b.price.compareTo(a.price);
  });
}
