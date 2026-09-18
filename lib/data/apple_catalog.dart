import '../models/catalog_product.dart';

/// Kategori produk yang dijual.
enum ProductCategory {
  iphone('iPhone'),
  macbook('MacBook'),
  appleWatch('Apple Watch'),
  audio('Audio'),
  accessories('Accessories');

  const ProductCategory(this.label);

  final String label;

  static ProductCategory? fromLabel(String? label) {
    for (final category in values) {
      if (category.label.toLowerCase() == label?.trim().toLowerCase()) {
        return category;
      }
    }
    return null;
  }
}

typedef AppleCatalogItem = ({
  String code,
  String name,
  ProductCategory category,
  int price,
  int minStock,
});

/// Isi awal koleksi `products` (dan data contoh untuk test). Katalog yang
/// dipakai app dibaca dari database, bukan dari sini.
const appleCatalog = <AppleCatalogItem>[
  (
    code: 'IP17PM',
    name: 'iPhone 17 Pro Max',
    category: ProductCategory.iphone,
    price: 24999000,
    minStock: 4,
  ),
  (
    code: 'IP17P',
    name: 'iPhone 17 Pro',
    category: ProductCategory.iphone,
    price: 21999000,
    minStock: 4,
  ),
  (
    code: 'IP17',
    name: 'iPhone 17',
    category: ProductCategory.iphone,
    price: 16999000,
    minStock: 4,
  ),
  (
    code: 'IP16',
    name: 'iPhone 16',
    category: ProductCategory.iphone,
    price: 13999000,
    minStock: 3,
  ),
  (
    code: 'MBA13M4',
    name: 'MacBook Air 13 M4',
    category: ProductCategory.macbook,
    price: 17999000,
    minStock: 2,
  ),
  (
    code: 'MBP14M5',
    name: 'MacBook Pro 14 M5',
    category: ProductCategory.macbook,
    price: 28999000,
    minStock: 2,
  ),
  (
    code: 'AWS11',
    name: 'Apple Watch Series 11',
    category: ProductCategory.appleWatch,
    price: 7499000,
    minStock: 3,
  ),
  (
    code: 'AWU3',
    name: 'Apple Watch Ultra 3',
    category: ProductCategory.appleWatch,
    price: 14999000,
    minStock: 2,
  ),
];

/// [appleCatalog] sebagai produk katalog (tanpa stok).
List<CatalogProduct> appleCatalogProducts() => [
  for (final item in appleCatalog)
    CatalogProduct(
      code: item.code,
      name: item.name,
      category: item.category.label,
      price: item.price,
      minStock: item.minStock,
    ),
];
