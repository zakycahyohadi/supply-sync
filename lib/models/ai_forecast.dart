/// Hasil analisis AI untuk satu bulan.
///
/// Semua angka di sini datang dari Gemini, jadi dianggap *perkiraan*, bukan
/// kebenaran. Angka yang pasti (omzet, stok, persen naik/turun) tetap dihitung
/// `sales_analytics.dart` dan tidak pernah diambil dari sini.
library;

enum AiTrendDirection {
  up('naik', 'Naik', '📈'),
  down('turun', 'Turun', '📉'),
  flat('stabil', 'Stabil', '➡️');

  const AiTrendDirection(this.value, this.label, this.emoji);

  final String value;
  final String label;
  final String emoji;

  static AiTrendDirection fromValue(Object? value) => values.firstWhere(
    (direction) => direction.value == value,
    orElse: () => AiTrendDirection.flat,
  );
}

enum AiConfidence {
  low('rendah', 'Keyakinan rendah'),
  medium('sedang', 'Keyakinan sedang'),
  high('tinggi', 'Keyakinan tinggi');

  const AiConfidence(this.value, this.label);

  final String value;
  final String label;

  static AiConfidence fromValue(Object? value) => values.firstWhere(
    (confidence) => confidence.value == value,
    orElse: () => AiConfidence.low,
  );
}

/// Satu catatan tren: apa yang naik/turun dan kenapa.
class AiTrend {
  const AiTrend({
    required this.direction,
    required this.title,
    required this.reason,
  });

  factory AiTrend.fromJson(Map<String, Object?> json) => AiTrend(
    direction: AiTrendDirection.fromValue(json['arah']),
    title: _string(json['judul']),
    reason: _string(json['alasan']),
  );

  final AiTrendDirection direction;
  final String title;
  final String reason;

  Map<String, Object?> toJson() => {
    'arah': direction.value,
    'judul': title,
    'alasan': reason,
  };
}

/// Perkiraan bulan depan.
class AiOutlook {
  const AiOutlook({
    required this.revenue,
    required this.units,
    required this.confidence,
    required this.basis,
  });

  factory AiOutlook.fromJson(Map<String, Object?> json) => AiOutlook(
    revenue: _int(json['omzet_perkiraan']),
    units: _int(json['unit_perkiraan']),
    confidence: AiConfidence.fromValue(json['keyakinan']),
    basis: _string(json['dasar_perhitungan']),
  );

  final int revenue;
  final int units;
  final AiConfidence confidence;

  /// Kenapa angkanya segitu, ditulis AI dengan bahasa sendiri.
  final String basis;

  Map<String, Object?> toJson() => {
    'omzet_perkiraan': revenue,
    'unit_perkiraan': units,
    'keyakinan': confidence.value,
    'dasar_perhitungan': basis,
  };
}

/// Saran barang yang perlu disiapkan/dikirim bulan depan.
class AiRestock {
  const AiRestock({
    required this.productName,
    required this.storeName,
    required this.quantity,
    required this.reason,
  });

  factory AiRestock.fromJson(Map<String, Object?> json) => AiRestock(
    productName: _string(json['produk']),
    storeName: _string(json['toko']),
    quantity: _int(json['jumlah_saran']),
    reason: _string(json['alasan']),
  );

  final String productName;
  final String storeName;
  final int quantity;
  final String reason;

  Map<String, Object?> toJson() => {
    'produk': productName,
    'toko': storeName,
    'jumlah_saran': quantity,
    'alasan': reason,
  };
}

class AiForecast {
  const AiForecast({
    required this.summary,
    required this.trends,
    required this.outlook,
    required this.restocks,
    required this.recommendations,
    required this.generatedAt,
    required this.model,
  });

  /// Dipakai untuk balasan Gemini maupun hasil yang dibaca dari cache
  /// Firestore. Sengaja longgar: field yang hilang atau tipenya aneh
  /// diabaikan, bukan bikin exception, karena balasan model bisa saja meleset
  /// dari schema.
  factory AiForecast.fromJson(Map<String, Object?> json) => AiForecast(
    summary: _string(json['ringkasan']),
    trends: [for (final trend in _list(json['tren'])) AiTrend.fromJson(trend)],
    outlook: AiOutlook.fromJson(_map(json['forecast_bulan_depan'])),
    restocks: [
      for (final restock in _list(json['produk_perlu_dikirim']))
        AiRestock.fromJson(restock),
    ],
    recommendations: [
      for (final item in _rawList(json['rekomendasi']))
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ],
    generatedAt:
        DateTime.tryParse(_string(json['dibuat_pada'])) ?? DateTime.now(),
    model: _string(json['model']),
  );

  final String summary;
  final List<AiTrend> trends;
  final AiOutlook outlook;
  final List<AiRestock> restocks;
  final List<String> recommendations;

  /// Kapan analisis ini dibuat (bukan kapan dibaca dari cache).
  final DateTime generatedAt;

  /// Model yang dipakai, misalnya `gemini-3.8-flash`. Ditampilkan di kartu
  /// supaya jelas ini hasil AI, bukan hitungan aplikasi.
  final String model;

  List<AiTrend> get downTrends =>
      trends.where((t) => t.direction == AiTrendDirection.down).toList();

  List<AiTrend> get upTrends =>
      trends.where((t) => t.direction == AiTrendDirection.up).toList();

  bool get isEmpty => summary.isEmpty && trends.isEmpty && restocks.isEmpty;

  Map<String, Object?> toJson() => {
    'ringkasan': summary,
    'tren': [for (final trend in trends) trend.toJson()],
    'forecast_bulan_depan': outlook.toJson(),
    'produk_perlu_dikirim': [for (final restock in restocks) restock.toJson()],
    'rekomendasi': recommendations,
    'dibuat_pada': generatedAt.toIso8601String(),
    'model': model,
  };

  AiForecast copyWith({DateTime? generatedAt, String? model}) => AiForecast(
    summary: summary,
    trends: trends,
    outlook: outlook,
    restocks: restocks,
    recommendations: recommendations,
    generatedAt: generatedAt ?? this.generatedAt,
    model: model ?? this.model,
  );
}

String _string(Object? value) => value is String ? value.trim() : '';

int _int(Object? value) => switch (value) {
  final num number => number.round(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

List<Object?> _rawList(Object? value) => value is List ? value : const [];

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const {};

List<Map<String, Object?>> _list(Object? value) => [
  for (final item in _rawList(value))
    if (item is Map) Map<String, Object?>.from(item),
];
