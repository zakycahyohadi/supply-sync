/// Format kolom file XLSX penjualan yang di-upload admin toko.
enum SalesColumn {
  date(
    'tanggal',
    aliases: ['date', 'tgl'],
    description: 'Tanggal penjualan. Contoh: 2026-09-08 atau 08/09/2026.',
  ),
  productCode(
    'kode_produk',
    aliases: ['kode', 'sku'],
    description: 'Kode produk dari katalog (sheet "Produk"). Contoh: IP17PM.',
  ),
  productName(
    'nama_produk',
    aliases: ['produk', 'nama'],
    description: 'Nama produk, harus sama persis dengan katalog.',
  ),
  category(
    'kategori',
    isRequired: false,
    description: 'Kategori sesuai katalog (boleh dikosongkan).',
  ),
  quantity(
    'qty_terjual',
    aliases: ['qty', 'jumlah_terjual', 'terjual'],
    description: 'Jumlah unit terjual hari itu (angka bulat).',
  ),
  unitPrice(
    'harga_satuan',
    aliases: ['harga'],
    description:
        'Harga jual per unit dalam Rupiah, tanpa titik. Contoh: 24999000.',
  ),
  stockEnd(
    'stok_akhir',
    aliases: ['stok', 'sisa_stok'],
    description: 'Sisa stok di akhir hari (angka bulat).',
  ),
  minStock(
    'stok_minimum',
    aliases: ['stok_min', 'min_stok'],
    isRequired: false,
    description: 'Batas stok minimum untuk peringatan (boleh dikosongkan).',
  );

  const SalesColumn(
    this.header, {
    this.aliases = const [],
    this.isRequired = true,
    required this.description,
  });

  /// Judul kolom di baris pertama file.
  final String header;
  final List<String> aliases;
  final bool isRequired;
  final String description;

  bool matches(String normalizedHeader) =>
      normalizedHeader == header || aliases.contains(normalizedHeader);
}

/// Nama sheet yang dicari lebih dulu. Kalau tidak ada, dipakai sheet pertama
/// yang punya judul kolom lengkap.
const kSalesSheetName = 'Penjualan';

/// Batas jumlah baris per file. Semua baris disimpan dalam satu dokumen
/// database (maks. 1 MB), jadi dibatasi.
const kMaxSalesRows = 2000;

/// "Qty Terjual" / "qty-terjual" -> "qty_terjual"
String normalizeHeader(String header) => header
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\s\-]+'), '_')
    .replaceAll(RegExp(r'[^a-z0-9_]'), '');
