import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/catalog_product.dart';
import '../../models/sales_record.dart';
import '../../models/sales_upload.dart';
import '../../models/shipment.dart';
import '../sales_repository.dart';

/// Data penjualan & pengiriman di Cloud Firestore.
///
/// Koleksi:
/// - `products`: katalog; ID dokumen = kode produk. Juga menyimpan stok
///   terakhir per toko (`stock_by_store`) untuk homepage.
/// - `uploads`: satu dokumen per file XLSX; semua baris di array `rows`.
/// - `shipments`: satu dokumen per pengiriman pusat → toko.
class FirestoreSalesRepository extends SalesRepository {
  FirestoreSalesRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');
  CollectionReference<Map<String, dynamic>> get _uploads =>
      _db.collection('uploads');
  CollectionReference<Map<String, dynamic>> get _shipments =>
      _db.collection('shipments');

  @override
  Stream<List<CatalogProduct>> watchProducts() {
    return _products.snapshots().map(
      (snapshot) => sortCatalog([
        for (final doc in snapshot.docs)
          CatalogProduct.fromJson(doc.id, _withDateTimes(doc.data())),
      ]),
    );
  }

  @override
  Future<void> saveProduct({
    required AppUser user,
    required CatalogProduct product,
    required bool isNew,
  }) async {
    final doc = _products.doc(product.code);
    final data = product.copyWith(updatedAt: DateTime.now()).toCatalogJson();
    if (!isNew) {
      // update() hanya mengubah field katalog; stok per toko tetap.
      await doc.update(data);
      return;
    }
    await _db.runTransaction((transaction) async {
      if ((await transaction.get(doc)).exists) {
        throw StateError('Kode ${product.code} sudah dipakai.');
      }
      transaction.set(doc, {...data, 'stock_by_store': <String, Object?>{}});
    });
  }

  @override
  Future<void> saveProducts({
    required AppUser user,
    required List<CatalogProduct> products,
  }) async {
    final now = DateTime.now();
    // Maksimal 500 tulis per batch.
    for (var start = 0; start < products.length; start += 500) {
      final batch = _db.batch();
      for (final product in products.skip(start).take(500)) {
        // merge: produk baru dibuat, produk lama hanya field katalognya yang
        // berubah (stock_by_store tidak disentuh).
        batch.set(
          _products.doc(product.code),
          product.copyWith(updatedAt: now).toCatalogJson(),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  @override
  Stream<List<SalesUpload>> watchUploads({
    required DateTime since,
    String? storeName,
  }) {
    Query<Map<String, dynamic>> query = _uploads.where(
      'period_end',
      isGreaterThanOrEqualTo: formatIsoDate(since),
    );
    if (storeName != null) {
      query = query.where('store_name', isEqualTo: storeName);
    }
    return query.snapshots().map(
      (snapshot) => [
        for (final doc in snapshot.docs)
          SalesUpload.fromJson(doc.id, _withDateTimes(doc.data())),
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
    final doc = _uploads.doc();
    final upload = SalesUpload.fromRecords(
      id: doc.id,
      storeName: storeName,
      uploadedBy: user.name,
      uploadedByEmail: user.email,
      uploadedAt: DateTime.now(),
      fileName: fileName,
      reportMonth: reportMonth,
      records: records,
    );
    // Satu commit: dokumen upload + stok terbaru toko ini di katalog.
    final latestStock = latestStockByProduct(upload.records);
    final productDocs = await Future.wait(
      latestStock.keys.map((code) => _products.doc(code).get()),
    );
    final batch = _db.batch()..set(doc, upload.toJson());
    for (final productDoc in productDocs) {
      if (!productDoc.exists) continue;
      final next = latestStock[productDoc.id]!;
      final stored = productDoc.data()?['stock_by_store'] as Map?;
      final storedAsOf = (stored?[storeName] as Map?)?['as_of'] as String?;
      // Upload data lama (tanggal lebih awal) tidak menimpa stok yang lebih baru.
      if (storedAsOf != null &&
          formatIsoDate(next.asOf!).compareTo(storedAsOf) < 0) {
        continue;
      }
      batch.update(productDoc.reference, {
        FieldPath(['stock_by_store', storeName]): next.toJson(),
      });
    }
    await batch.commit();
    return upload;
  }

  @override
  Stream<List<Shipment>> watchShipments({
    required DateTime since,
    String? storeName,
  }) {
    Query<Map<String, dynamic>> query = _shipments.where(
      'created_at',
      isGreaterThanOrEqualTo: Timestamp.fromDate(since),
    );
    if (storeName != null) {
      query = query.where('store_name', isEqualTo: storeName);
    }
    return query.snapshots().map(
      (snapshot) => [
        for (final doc in snapshot.docs)
          Shipment.fromJson(doc.id, _withDateTimes(doc.data())),
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
    final doc = _shipments.doc();
    final shipment = Shipment(
      id: doc.id,
      storeName: storeName,
      status: ShipmentStatus.inTransit,
      items: items,
      note: note,
      createdBy: user.name,
      createdByEmail: user.email,
      createdAt: DateTime.now(),
    );
    await doc.set(shipment.toJson());
    return shipment;
  }

  @override
  Future<void> confirmShipment({
    required AppUser user,
    required Shipment shipment,
  }) async {
    final productDocs = await Future.wait(
      shipment.items.map((item) => _products.doc(item.productCode).get()),
    );
    final batch = _db.batch()
      ..update(_shipments.doc(shipment.id), {
        'status': ShipmentStatus.received.value,
        'received_by': user.name,
        'received_by_email': user.email,
        'received_at': DateTime.now(),
      });
    for (final item in shipment.items) {
      final exists = productDocs.any(
        (doc) => doc.id == item.productCode && doc.exists,
      );
      if (!exists) continue;
      batch.update(_products.doc(item.productCode), {
        FieldPath(['stock_by_store', shipment.storeName, 'stock']):
            FieldValue.increment(item.quantity),
      });
    }
    await batch.commit();
  }

  /// Firestore mengembalikan waktu sebagai [Timestamp]; model memakai
  /// [DateTime].
  static Map<String, Object?> _withDateTimes(Map<String, dynamic> data) => {
    for (final entry in data.entries)
      entry.key: entry.value is Timestamp
          ? (entry.value as Timestamp).toDate()
          : entry.value,
  };
}
