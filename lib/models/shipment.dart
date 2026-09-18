enum ShipmentStatus {
  inTransit('in_transit', 'Dalam pengiriman'),
  received('received', 'Diterima');

  const ShipmentStatus(this.value, this.label);

  /// Nilai yang disimpan di database.
  final String value;
  final String label;

  static ShipmentStatus fromValue(String value) =>
      values.firstWhere((status) => status.value == value);
}

class ShipmentItem {
  const ShipmentItem({
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.stockBefore,
  });

  factory ShipmentItem.fromJson(Map<String, Object?> json) => ShipmentItem(
    productCode: json['product_code']! as String,
    productName: json['product_name']! as String,
    quantity: (json['quantity']! as num).toInt(),
    stockBefore: (json['stock_before']! as num).toInt(),
  );

  final String productCode;
  final String productName;
  final int quantity;

  /// Stok di toko saat pengiriman diajukan.
  final int stockBefore;

  Map<String, Object?> toJson() => {
    'product_code': productCode,
    'product_name': productName,
    'quantity': quantity,
    'stock_before': stockBefore,
  };
}

/// Pengiriman barang dari pusat ke toko. Dibuat admin pusat, dikonfirmasi
/// admin toko saat barang sampai.
class Shipment {
  const Shipment({
    required this.id,
    required this.storeName,
    required this.status,
    required this.items,
    required this.createdBy,
    required this.createdByEmail,
    required this.createdAt,
    this.note,
    this.receivedBy,
    this.receivedByEmail,
    this.receivedAt,
  });

  /// [json] memakai `DateTime` untuk kolom waktu.
  factory Shipment.fromJson(String id, Map<String, Object?> json) => Shipment(
    id: id,
    storeName: json['store_name']! as String,
    status: ShipmentStatus.fromValue(json['status']! as String),
    items: [
      for (final item in json['items']! as List)
        ShipmentItem.fromJson(Map<String, Object?>.from(item as Map)),
    ],
    note: json['note'] as String?,
    createdBy: json['created_by']! as String,
    createdByEmail: json['created_by_email']! as String,
    createdAt: json['created_at']! as DateTime,
    receivedBy: json['received_by'] as String?,
    receivedByEmail: json['received_by_email'] as String?,
    receivedAt: json['received_at'] as DateTime?,
  );

  final String id;
  final String storeName;
  final ShipmentStatus status;
  final List<ShipmentItem> items;
  final String? note;
  final String createdBy;
  final String createdByEmail;
  final DateTime createdAt;
  final String? receivedBy;
  final String? receivedByEmail;
  final DateTime? receivedAt;

  int get totalUnits => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, Object?> toJson() => {
    'store_name': storeName,
    'status': status.value,
    'items': [for (final item in items) item.toJson()],
    'total_units': totalUnits,
    'note': note,
    'created_by': createdBy,
    'created_by_email': createdByEmail,
    'created_at': createdAt,
    'received_by': receivedBy,
    'received_by_email': receivedByEmail,
    'received_at': receivedAt,
  };

  Shipment markReceived({
    required String by,
    required String byEmail,
    required DateTime at,
  }) {
    return Shipment(
      id: id,
      storeName: storeName,
      status: ShipmentStatus.received,
      items: items,
      note: note,
      createdBy: createdBy,
      createdByEmail: createdByEmail,
      createdAt: createdAt,
      receivedBy: by,
      receivedByEmail: byEmail,
      receivedAt: at,
    );
  }
}
