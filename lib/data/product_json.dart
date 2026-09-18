import 'dart:convert';

import '../models/catalog_product.dart';
import 'apple_catalog.dart';

/// Hasil baca file JSON katalog.
class ParsedProductJson {
  const ParsedProductJson({required this.products, required this.issues});

  /// Produk valid; `isNew` = kode belum ada di katalog.
  final List<({CatalogProduct product, bool isNew})> products;
  final List<String> issues;

  bool get canSave => issues.isEmpty && products.isNotEmpty;
  int get newCount => products.where((p) => p.isNew).length;
  int get updateCount => products.length - newCount;
}

final _codePattern = RegExp(r'^[A-Z0-9-]{2,20}$');

/// Membaca JSON katalog. Format yang diterima: array produk, atau objek
/// `{"products": [...]}`. Tiap produk:
///
/// ```json
/// {
///   "code": "IP17PM",
///   "name": "iPhone 17 Pro Max",
///   "category": "iPhone",
///   "price": 24999000,
///   "min_stock": 4,
///   "image_url": "https://...",
///   "is_active": true
/// }
/// ```
///
/// `min_stock` (default 0), `image_url`, dan `is_active` (default true)
/// boleh tidak ada. Produk dengan kode yang sudah ada akan diperbarui; stok
/// per toko tidak ikut berubah.
ParsedProductJson parseProductJson(
  String text, {
  required List<CatalogProduct> existing,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    return ParsedProductJson(
      products: const [],
      issues: ['File bukan JSON yang valid: ${e.message}'],
    );
  }

  final list = switch (decoded) {
    List<Object?>() => decoded,
    {'products': final List<Object?> products} => products,
    _ => null,
  };
  if (list == null) {
    return const ParsedProductJson(
      products: [],
      issues: ['Isi file harus berupa array produk atau {"products": [...]}.'],
    );
  }
  if (list.isEmpty) {
    return const ParsedProductJson(
      products: [],
      issues: ['File tidak berisi produk.'],
    );
  }

  final existingByCode = {for (final p in existing) p.code: p};
  final products = <({CatalogProduct product, bool isNew})>[];
  final issues = <String>[];
  final seenCodes = <String, int>{};
  final seenNames = <String, int>{};

  for (var i = 0; i < list.length; i++) {
    final number = i + 1;
    final item = list[i];
    if (item is! Map) {
      issues.add('Produk ke-$number: harus berupa objek {...}');
      continue;
    }

    final problems = <String>[];
    final code = (item['code'] is String)
        ? (item['code'] as String).trim().toUpperCase()
        : null;
    final label = code == null || code.isEmpty
        ? 'Produk ke-$number'
        : 'Produk ke-$number ($code)';

    if (code == null || code.isEmpty) {
      problems.add('code wajib diisi');
    } else if (!_codePattern.hasMatch(code)) {
      problems.add('code hanya huruf besar, angka, dan -, 2–20 karakter');
    } else if (seenCodes.containsKey(code)) {
      problems.add('code sama dengan produk ke-${seenCodes[code]}');
    }

    final rawName = item['name'];
    final name = rawName is String
        ? rawName.trim().replaceAll(RegExp(r'\s+'), ' ')
        : null;
    if (name == null || name.isEmpty) {
      problems.add('name wajib diisi');
    } else {
      final key = normalizeProductName(name);
      if (seenNames.containsKey(key)) {
        problems.add('name sama dengan produk ke-${seenNames[key]}');
      } else {
        final clash = existing.where(
          (p) => p.code != code && normalizeProductName(p.name) == key,
        );
        if (clash.isNotEmpty) {
          problems.add('name sudah dipakai produk ${clash.first.code}');
        }
      }
    }

    final category = ProductCategory.fromLabel(
      item['category'] is String ? item['category'] as String : null,
    );
    if (category == null) {
      final allowed = ProductCategory.values.map((c) => c.label).join(', ');
      problems.add('category harus salah satu dari: $allowed');
    }

    int? wholeNumber(String key, {required bool required}) {
      final value = item[key];
      if (value == null) {
        if (required) problems.add('$key wajib diisi');
        return null;
      }
      final number = switch (value) {
        int() => value,
        double() when value == value.roundToDouble() => value.toInt(),
        _ => null,
      };
      if (number == null || number < 0) {
        problems.add('$key harus angka bulat ≥ 0');
        return null;
      }
      return number;
    }

    final price = wholeNumber('price', required: true);
    final minStock = wholeNumber('min_stock', required: false) ?? 0;

    final rawImage = item['image_url'];
    String? imageUrl;
    if (rawImage is String && rawImage.trim().isNotEmpty) {
      final uri = Uri.tryParse(rawImage.trim());
      if (uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http') ||
          uri.host.isEmpty) {
        problems.add('image_url harus link https://');
      } else {
        imageUrl = rawImage.trim();
      }
    } else if (rawImage != null && rawImage is! String) {
      problems.add('image_url harus teks');
    }

    final rawActive = item['is_active'];
    if (rawActive != null && rawActive is! bool) {
      problems.add('is_active harus true atau false');
    }

    if (code != null && code.isNotEmpty) {
      seenCodes.putIfAbsent(code, () => number);
    }
    if (name != null && name.isNotEmpty) {
      seenNames.putIfAbsent(normalizeProductName(name), () => number);
    }

    if (problems.isNotEmpty) {
      issues.add('$label: ${problems.join('; ')}');
      continue;
    }

    products.add((
      product: CatalogProduct(
        code: code!,
        name: name!,
        category: category!.label,
        price: price!,
        minStock: minStock,
        imageUrl: imageUrl,
        isActive: rawActive as bool? ?? true,
      ),
      isNew: !existingByCode.containsKey(code),
    ));
  }

  return ParsedProductJson(products: products, issues: issues);
}

/// Katalog sebagai JSON rapi (format sama dengan yang dibaca
/// [parseProductJson]), tanpa stok.
String encodeProductJson(List<CatalogProduct> products) {
  return const JsonEncoder.withIndent('  ').convert([
    for (final p in products)
      {
        'code': p.code,
        'name': p.name,
        'category': p.category,
        'price': p.price,
        'min_stock': p.minStock,
        'image_url': p.imageUrl,
        'is_active': p.isActive,
      },
  ]);
}
