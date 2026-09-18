import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/apple_catalog.dart';
import '../../data/sales_repository.dart';
import '../../models/app_user.dart';
import '../../models/catalog_product.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard/page_body.dart';
import '../../widgets/dashboard/section_card.dart';
import '../../widgets/product_card.dart';
import '../../widgets/app_header.dart';

/// Form admin pusat untuk menambah atau mengubah produk katalog.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.user,
    required this.existingProducts,
    this.product,
  });

  final AppUser user;

  /// Semua produk sekarang, untuk cek kode & nama tidak dobel.
  final List<CatalogProduct> existingProducts;

  /// Null = tambah produk baru.
  final CatalogProduct? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.product?.code);
  late final _name = TextEditingController(text: widget.product?.name);
  late final _price = TextEditingController(
    text: widget.product?.price.toString(),
  );
  late final _minStock = TextEditingController(
    text: (widget.product?.minStock ?? 2).toString(),
  );
  late final _imageUrl = TextEditingController(text: widget.product?.imageUrl);
  late String _category =
      widget.product?.category ?? ProductCategory.iphone.label;
  late bool _isActive = widget.product?.isActive ?? true;
  bool _isSaving = false;

  bool get _isNew => widget.product == null;

  @override
  void dispose() {
    for (final controller in [_code, _name, _price, _minStock, _imageUrl]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateCode(String? value) {
    final code = value?.trim().toUpperCase() ?? '';
    if (code.isEmpty) return 'Kode wajib diisi';
    if (!RegExp(r'^[A-Z0-9-]{2,20}$').hasMatch(code)) {
      return 'Hanya huruf besar, angka, dan tanda -, 2–20 karakter';
    }
    if (widget.existingProducts.any((p) => p.code == code)) {
      return 'Kode $code sudah dipakai';
    }
    return null;
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Nama wajib diisi';
    final duplicate = widget.existingProducts.any(
      (p) =>
          p.code != widget.product?.code &&
          normalizeProductName(p.name) == normalizeProductName(name),
    );
    return duplicate ? 'Nama ini sudah dipakai produk lain' : null;
  }

  String? _validateWholeNumber(String? value, String label) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null) return '$label wajib angka';
    if (number < 0) return '$label tidak boleh negatif';
    return null;
  }

  String? _validateImageUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    final valid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return valid ? null : 'Link harus diawali https://';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final imageUrl = _imageUrl.text.trim();
    final product = CatalogProduct(
      code: widget.product?.code ?? _code.text.trim().toUpperCase(),
      name: _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
      category: _category,
      price: int.parse(_price.text.trim()),
      minStock: int.parse(_minStock.text.trim()),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      isActive: _isActive,
    );

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SalesRepository.instance.saveProduct(
        user: widget.user,
        product: product,
        isNew: _isNew,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isNew
                ? '${product.name} ditambahkan ke katalog.'
                : '${product.name} disimpan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan produk. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _decoration(String label, {String? hint, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: _isNew ? 'Tambah Produk' : 'Edit Produk',
        subtitle: _isNew ? 'Produk baru di katalog' : widget.product!.code,
        showBackButton: true,
      ),
      body: Form(
        key: _formKey,
        child: PageBody(
          maxWidth: 720,
          children: [
            SectionCard(
              title: 'Data produk',
              subtitle:
                  'Kode & nama ini yang wajib dipakai admin toko di file XLSX',
              icon: Icons.inventory_2_outlined,
              child: Column(
                children: [
                  TextFormField(
                    controller: _code,
                    enabled: _isNew && !_isSaving,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
                    ],
                    validator: _isNew ? _validateCode : null,
                    decoration: _decoration(
                      'Kode produk',
                      hint: 'IP17PM',
                      helper: _isNew
                          ? 'Tidak bisa diubah setelah disimpan'
                          : 'Kode tidak bisa diubah',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    enabled: !_isSaving,
                    validator: _validateName,
                    decoration: _decoration(
                      'Nama produk',
                      hint: 'iPhone 17 Pro Max',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: _decoration('Kategori'),
                    items: [
                      for (final category in ProductCategory.values)
                        DropdownMenuItem(
                          value: category.label,
                          child: Row(
                            children: [
                              Icon(
                                productCategoryIcon(category.label),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(category.label),
                            ],
                          ),
                        ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _category = value!),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _price,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) => _validateWholeNumber(v, 'Harga'),
                          decoration: _decoration(
                            'Harga (Rp)',
                            hint: '24999000',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _minStock,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) =>
                              _validateWholeNumber(v, 'Stok minimum'),
                          decoration: _decoration('Stok minimum'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Foto',
              subtitle: 'Tempel link gambar (https://...)',
              icon: Icons.image_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _imageUrl,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.url,
                    validator: _validateImageUrl,
                    onChanged: (_) => setState(() {}),
                    decoration: _decoration(
                      'Link foto (opsional)',
                      helper: 'Kosongkan untuk memakai ikon kategori',
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 160,
                      child: ProductImage(
                        imageUrl: _validateImageUrl(_imageUrl.text) == null
                            ? _imageUrl.text.trim()
                            : null,
                        category: _category,
                        iconSize: 56,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Status',
              icon: Icons.toggle_on_outlined,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _isActive = value),
                activeThumbColor: AppColors.navy,
                title: const Text('Aktif'),
                subtitle: const Text(
                  'Produk nonaktif tidak tampil di homepage dan tidak bisa '
                  'di-upload admin toko.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_isNew ? 'Tambah produk' : 'Simpan perubahan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
