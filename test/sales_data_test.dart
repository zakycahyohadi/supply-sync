import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supply_sync/data/apple_catalog.dart';
import 'package:supply_sync/data/product_json.dart';
import 'package:supply_sync/data/sales_analytics.dart';
import 'package:supply_sync/data/sales_repository.dart';
import 'package:supply_sync/data/sample_sales_data.dart';
import 'package:supply_sync/data/widget_sales_summary.dart';
import 'package:supply_sync/data/xlsx/sales_sheet_parser.dart';
import 'package:supply_sync/data/xlsx/sales_template.dart';
import 'package:supply_sync/models/app_user.dart';
import 'package:supply_sync/models/catalog_product.dart';
import 'package:supply_sync/models/sales_record.dart';
import 'package:supply_sync/models/sales_upload.dart';
import 'package:supply_sync/models/shipment.dart';

final _today = DateTime(2026, 9, 17);

Uint8List _workbook(List<List<CellValue?>> rows, {String sheet = 'Sheet1'}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  if (defaultSheet != sheet) excel.rename(defaultSheet, sheet);
  for (final row in rows) {
    excel[sheet].appendRow(row);
  }
  return Uint8List.fromList(excel.encode()!);
}

TextCellValue _t(String text) => TextCellValue(text);

void main() {
  group('parseSalesSheet', () {
    final catalog = appleCatalogProducts();
    const header = [
      'tanggal',
      'kode_produk',
      'nama_produk',
      'qty_terjual',
      'harga_satuan',
      'stok_akhir',
    ];
    ParsedSalesSheet parse(
      List<List<CellValue?>> rows, {
      List<CatalogProduct>? products,
    }) => parseSalesSheet(
      _workbook([
        [for (final h in header) _t(h)],
        ...rows,
      ]),
      storeName: 'Toko 1',
      today: _today,
      catalog: products ?? catalog,
    );

    test('template berisi semua produk katalog; qty & stok wajib diisi', () {
      final parsed = parseSalesSheet(
        buildSalesTemplate(catalog, date: DateTime(2026, 9, 8)),
        storeName: 'Toko 1',
        today: _today,
        catalog: catalog,
      );

      expect(parsed.sheetName, 'Penjualan');
      expect(parsed.records, isEmpty);
      expect(parsed.issues, hasLength(catalog.length));
      for (final issue in parsed.issues) {
        expect(issue.message, 'qty_terjual kosong; stok_akhir kosong');
      }
    });

    test('baris valid: nama & kategori diambil dari katalog', () {
      final parsed = parse([
        [
          _t('08/09/2026'),
          _t('ip17pm'),
          _t('  iphone 17   PRO max '),
          _t('2'),
          _t('Rp 24.999.000'),
          IntCellValue(6),
        ],
        [
          IntCellValue(46274),
          _t('AWS11'),
          _t('Apple Watch Series 11'),
          IntCellValue(4),
          DoubleCellValue(7499000),
          _t('20'),
        ],
      ]);

      expect(parsed.issues, isEmpty);
      expect(parsed.records, hasLength(2));
      final first = parsed.records[0];
      expect(first.date, DateTime(2026, 9, 8));
      expect(first.productCode, 'IP17PM');
      expect(
        first.productName,
        'iPhone 17 Pro Max',
        reason: 'nama resmi katalog',
      );
      expect(first.category, 'iPhone');
      expect(first.minStock, 4, reason: 'stok_minimum kosong → dari katalog');
      expect(first.revenue, 49998000);
      expect(
        parsed.records[1].date,
        DateTime(2026, 9, 9),
        reason: 'serial Excel',
      );
    });

    test('kode tidak terdaftar, nama beda, atau produk nonaktif ditolak', () {
      final products = [
        for (final product in catalog)
          product.code == 'IP16' ? product.copyWith(isActive: false) : product,
      ];
      final parsed = parse([
        [
          _t('2026-09-08'),
          _t('IPX'),
          _t('iPhone X'),
          IntCellValue(1),
          IntCellValue(1),
          IntCellValue(1),
        ],
        [
          _t('2026-09-08'),
          _t('IP17PM'),
          _t('iPhone 17 ProMax'),
          IntCellValue(1),
          IntCellValue(1),
          IntCellValue(1),
        ],
        [
          _t('2026-09-08'),
          _t('IP16'),
          _t('iPhone 16'),
          IntCellValue(1),
          IntCellValue(1),
          IntCellValue(1),
        ],
      ], products: products);

      expect(parsed.records, isEmpty);
      expect(
        parsed.issues[0].message,
        'kode_produk "IPX" tidak ada di katalog',
      );
      expect(
        parsed.issues[1].message,
        'nama_produk untuk IP17PM harus "iPhone 17 Pro Max"',
      );
      expect(
        parsed.issues[2].message,
        'produk IP16 sudah tidak aktif di katalog',
      );
    });

    test('kategori yang diisi harus sesuai katalog', () {
      final parsed = parseSalesSheet(
        _workbook([
          [for (final h in header) _t(h), _t('kategori')],
          [
            _t('2026-09-08'),
            _t('MBA13M4'),
            _t('MacBook Air 13 M4'),
            IntCellValue(1),
            IntCellValue(1),
            IntCellValue(1),
            _t('Laptop'),
          ],
        ]),
        storeName: 'Toko 1',
        today: _today,
        catalog: catalog,
      );
      expect(
        parsed.issues.single.message,
        'kategori untuk MBA13M4 harus "MacBook"',
      );
    });

    test('tanggal harus di bulan laporan yang dipilih', () {
      final bytes = _workbook([
        [for (final h in header) _t(h)],
        [
          _t('2026-08-31'),
          _t('IP17'),
          _t('iPhone 17'),
          IntCellValue(1),
          IntCellValue(1),
          IntCellValue(5),
        ],
        [
          _t('2026-09-01'),
          _t('IP17'),
          _t('iPhone 17'),
          IntCellValue(1),
          IntCellValue(1),
          IntCellValue(4),
        ],
      ]);
      ParsedSalesSheet parseFor(DateTime? month) => parseSalesSheet(
        bytes,
        storeName: 'Toko 1',
        today: _today,
        catalog: catalog,
        month: month,
      );

      final september = parseFor(DateTime(2026, 9));
      expect(september.records.single.date, DateTime(2026, 9, 1));
      expect(
        september.issues.single.toString(),
        'Baris 2: tanggal 2026-08-31 bukan bulan September 2026',
      );
      expect(september.canSubmit, isFalse);

      expect(
        parseFor(DateTime(2026, 8)).issues.single.message,
        contains('bukan bulan Agustus 2026'),
      );
      expect(
        parseFor(null).issues,
        isEmpty,
        reason: 'tanpa bulan: tidak dicek',
      );
    });

    test('tanggal contoh template mengikuti bulan', () {
      final now = DateTime(2026, 9, 18, 10);
      expect(defaultTemplateDate(now), DateTime(2026, 9, 17));
      expect(
        defaultTemplateDate(now, month: DateTime(2026, 9)),
        DateTime(2026, 9, 17),
      );
      expect(
        defaultTemplateDate(now, month: DateTime(2026, 8)),
        DateTime(2026, 8, 31),
      );
      expect(
        defaultTemplateDate(DateTime(2026, 10, 1), month: DateTime(2026, 10)),
        DateTime(2026, 10, 1),
      );
    });

    test('mengumpulkan kesalahan per baris', () {
      final parsed = parse([
        [
          _t('2026-09-08'),
          _t('IP17'),
          _t('iPhone 17'),
          IntCellValue(1),
          IntCellValue(1000),
          IntCellValue(5),
        ],
        [
          _t('31/02/2026'),
          _t('IP17P'),
          _t('iPhone 17 Pro'),
          IntCellValue(1),
          IntCellValue(1000),
          IntCellValue(5),
        ],
        [
          _t('2026-09-08'),
          _t('IP16'),
          null,
          _t('dua'),
          IntCellValue(-5),
          IntCellValue(5),
        ],
        [
          _t('2026-09-30'),
          _t('AWU3'),
          _t('Apple Watch Ultra 3'),
          DoubleCellValue(1.5),
          IntCellValue(1000),
          IntCellValue(5),
        ],
        [
          _t('2026-09-08'),
          _t('ip17'),
          _t('iPhone 17'),
          IntCellValue(2),
          IntCellValue(1000),
          IntCellValue(3),
        ],
      ]);

      expect(parsed.records, hasLength(1));
      expect(parsed.canSubmit, isFalse);
      expect(parsed.issues.map((i) => i.rowNumber), [3, 4, 5, 6]);
      expect(parsed.issues[0].message, contains('tanggal'));
      expect(
        parsed.issues[1].message,
        allOf(
          contains('nama_produk kosong'),
          contains('qty_terjual'),
          contains('harga_satuan'),
        ),
      );
      expect(
        parsed.issues[2].message,
        allOf(contains('belum terjadi'), contains('qty_terjual')),
      );
      expect(parsed.issues[3].message, contains('sudah ada di baris 2'));
    });

    test(
      'katalog kosong, kolom tidak lengkap, atau bukan xlsx -> error jelas',
      () {
        expect(
          () => parseSalesSheet(
            _workbook([
              [_t('x')],
            ]),
            storeName: 'Toko 1',
            today: _today,
            catalog: const [],
          ),
          throwsA(
            isA<SalesSheetException>().having(
              (e) => e.message,
              'message',
              contains('Katalog'),
            ),
          ),
        );
        expect(
          () => parseSalesSheet(
            _workbook([
              [_t('tanggal'), _t('produk'), _t('qty')],
              [_t('2026-09-08'), _t('A'), IntCellValue(1)],
            ]),
            storeName: 'Toko 1',
            today: _today,
            catalog: catalog,
          ),
          throwsA(
            isA<SalesSheetException>().having(
              (e) => e.message,
              'message',
              contains('kode_produk'),
            ),
          ),
        );
        expect(
          () => parseSalesSheet(
            Uint8List.fromList([1, 2, 3]),
            storeName: 'Toko 1',
            today: _today,
            catalog: catalog,
          ),
          throwsA(isA<SalesSheetException>()),
        );
      },
    );
  });

  group('import JSON produk', () {
    final existing = appleCatalogProducts();

    test('file hasil Unduh JSON bisa di-import ulang tanpa perubahan', () {
      final parsed = parseProductJson(
        encodeProductJson(existing),
        existing: existing,
      );
      expect(parsed.issues, isEmpty);
      expect(parsed.newCount, 0);
      expect(parsed.updateCount, existing.length);
      expect(parsed.products.first.product.name, existing.first.name);
    });

    test('produk baru & update; field opsional diberi nilai default', () {
      const json = '''
{"products": [
  {"code": "ipair", "name": "iPhone  Air", "category": "iphone", "price": 19999000},
  {"code": "IP17PM", "name": "iPhone 17 Pro Max", "category": "iPhone", "price": 23999000.0,
   "min_stock": 5, "image_url": "https://contoh.id/ip17pm.png", "is_active": false}
]}
''';
      final parsed = parseProductJson(json, existing: existing);

      expect(parsed.issues, isEmpty);
      expect(parsed.newCount, 1);
      expect(parsed.updateCount, 1);
      final air = parsed.products[0].product;
      expect(air.code, 'IPAIR');
      expect(air.name, 'iPhone Air');
      expect(air.category, 'iPhone');
      expect(air.minStock, 0);
      expect(air.isActive, isTrue);
      final proMax = parsed.products[1].product;
      expect(proMax.price, 23999000);
      expect(proMax.imageUrl, 'https://contoh.id/ip17pm.png');
      expect(proMax.isActive, isFalse);
    });

    test('kesalahan per produk dikumpulkan dengan jelas', () {
      const json = '''
[
  {"code": "A B", "name": "", "category": "Tablet", "price": -1},
  {"code": "NEW1", "name": "iPhone 17", "category": "iPhone", "price": 1},
  {"code": "NEW2", "name": "Produk X", "category": "MacBook", "price": "mahal", "image_url": "ftp://x"},
  {"code": "NEW2", "name": "produk x", "category": "MacBook", "price": 1, "is_active": "ya"},
  "bukan objek"
]
''';
      final parsed = parseProductJson(json, existing: existing);

      expect(parsed.canSave, isFalse);
      expect(parsed.issues, [
        'Produk ke-1 (A B): code hanya huruf besar, angka, dan -, 2–20 karakter; '
            'name wajib diisi; category harus salah satu dari: iPhone, MacBook, '
            'Apple Watch, Audio, Accessories; price harus angka bulat ≥ 0',
        'Produk ke-2 (NEW1): name sudah dipakai produk IP17',
        'Produk ke-3 (NEW2): price harus angka bulat ≥ 0; image_url harus link https://',
        'Produk ke-4 (NEW2): code sama dengan produk ke-3; name sama dengan '
            'produk ke-3; is_active harus true atau false',
        'Produk ke-5: harus berupa objek {...}',
      ]);
    });

    test('bukan JSON / bentuk salah / kosong', () {
      expect(
        parseProductJson('{oops', existing: existing).issues.single,
        startsWith('File bukan JSON yang valid'),
      );
      expect(
        parseProductJson('{"items": []}', existing: existing).issues.single,
        contains('array produk'),
      );
      expect(
        parseProductJson('[]', existing: existing).issues.single,
        'File tidak berisi produk.',
      );
    });
  });

  group('ringkasan widget', () {
    SalesRecord row(
      String store,
      DateTime date,
      String category,
      int qty,
      int price,
    ) => SalesRecord(
      storeName: store,
      date: date,
      productCode: '$category-$price',
      productName: category,
      category: category,
      quantity: qty,
      unitPrice: price,
      stockEnd: 10,
    );

    test('omzet per kategori untuk bulan terbaru, semua toko & per toko', () {
      final summary = buildWidgetSalesSummary([
        row('Toko 1', DateTime(2026, 9, 14), 'iPhone', 2, 20000000),
        row('Toko 1', DateTime(2026, 9, 14), 'Audio', 3, 1000000),
        row('Toko 2', DateTime(2026, 9, 15), 'MacBook', 1, 30000000),
        row('Toko 2', DateTime(2026, 9, 15), 'Apple Watch', 1, 7000000),
        // Bulan lama tidak ikut dihitung.
        row('Toko 1', DateTime(2026, 8, 30), 'iPhone', 9, 20000000),
      ]);

      expect(summary['month'], 'September 2026');
      final stores = summary['stores']! as List;
      expect(stores.map((s) => (s as Map)['name']), [
        'Semua',
        'Toko 1',
        'Toko 2',
      ]);

      Map<String, Object?> item(int store, String category) =>
          ((stores[store] as Map)['items'] as List)
              .cast<Map<String, Object?>>()
              .firstWhere((i) => i['category'] == category);

      expect(item(0, 'iPhone')['revenue'], 40000000);
      expect(item(0, 'MacBook')['revenue'], 30000000);
      expect(
        item(0, 'Lainnya')['revenue'],
        10000000,
        reason: 'Audio + Apple Watch',
      );
      expect(item(0, 'Lainnya')['units'], 4);
      expect((stores[0] as Map)['total'], 'Rp80 jt');
      expect(item(1, 'MacBook')['revenue'], 0);
      expect(item(1, 'MacBook')['label'], 'Rp0');
      expect(item(2, 'iPhone')['revenue'], 0);
      expect((stores[2] as Map)['total'], 'Rp37 jt');

      // Omzet harian per kategori untuk grafik garis (14–15 Sep).
      expect(summary['days'], ['14', '15']);
      List<Object?> values(int store, String category) =>
          ((stores[store] as Map)['series'] as List)
                  .cast<Map<String, Object?>>()
                  .firstWhere((s) => s['category'] == category)['values']!
              as List;
      expect(values(0, 'iPhone'), [40000000, 0]);
      expect(values(0, 'MacBook'), [0, 30000000]);
      expect(values(0, 'Lainnya'), [3000000, 7000000]);
      expect(values(1, 'MacBook'), [0, 0]);
    });

    test('tanpa data: bulan kosong', () {
      expect(buildWidgetSalesSummary(const []), {
        'month': null,
        'stores': <Object?>[],
      });
    });
  });

  group('JSON database', () {
    test('satu upload = satu dokumen JSON berisi semua baris', () {
      final upload = SalesUpload.fromRecords(
        id: 'u1',
        storeName: 'Toko 1',
        uploadedBy: 'Admin Toko 1',
        uploadedByEmail: 'toko1@supply.id',
        uploadedAt: DateTime(2026, 9, 9, 10),
        fileName: 'a.xlsx',
        records: [
          _row('IP17PM', 8, quantity: 2, stock: 6),
          _row('AWS11', 8, quantity: 1, stock: 9, price: 7499000),
        ],
      );

      final json = upload.toJson();
      expect(json['period_start'], '2026-09-08');
      expect(json['report_month'], '2026-09');
      expect(json['row_count'], 2);
      expect(json['total_revenue'], 2 * 24999000 + 7499000);
      final rows = json['rows']! as List;
      expect(rows.first, {
        'date': '2026-09-08',
        'product_code': 'IP17PM',
        'product_name': 'IP17PM',
        'category': null,
        'quantity': 2,
        'unit_price': 24999000,
        'stock_end': 6,
        'min_stock': 4,
      });

      final copy = SalesUpload.fromJson('u1', json);
      expect(copy.records, hasLength(2));
      expect(copy.records.first.storeName, 'Toko 1');
      expect(copy.records.first.uploadedAt, DateTime(2026, 9, 9, 10));
      expect(copy.records.first.key, upload.records.first.key);
    });

    test('Shipment toJson/fromJson', () {
      final shipment = Shipment(
        id: 's1',
        storeName: 'Toko 1',
        status: ShipmentStatus.inTransit,
        items: const [
          ShipmentItem(
            productCode: 'IP17PM',
            productName: 'iPhone 17 Pro Max',
            quantity: 10,
            stockBefore: 0,
          ),
        ],
        createdBy: 'Admin Pusat',
        createdByEmail: 'pusat@supply.id',
        createdAt: DateTime(2026, 9, 10),
      );
      final json = shipment.toJson();
      expect(json['status'], 'in_transit');
      expect(json['total_units'], 10);
      final copy = Shipment.fromJson('s1', json);
      expect(copy.items.single.quantity, 10);
      expect(copy.status, ShipmentStatus.inTransit);
    });

    test('upload terbaru menggantikan baris dengan tanggal & produk sama', () {
      SalesUpload upload(String id, int hour, List<SalesRecord> rows) =>
          SalesUpload.fromRecords(
            id: id,
            storeName: 'Toko 1',
            uploadedBy: 'x',
            uploadedByEmail: 'x',
            uploadedAt: DateTime(2026, 9, 10, hour),
            fileName: '$id.xlsx',
            records: rows,
          );
      final records = latestRecords([
        upload('baru', 12, [_row('IP17PM', 9, quantity: 5, stock: 1)]),
        upload('lama', 9, [
          _row('IP17PM', 8, quantity: 1, stock: 7),
          _row('IP17PM', 9, quantity: 1, stock: 6),
        ]),
      ]);

      expect(records, hasLength(2));
      final day9 = records.firstWhere((r) => r.date.day == 9);
      expect(day9.quantity, 5);
      expect(day9.uploadId, 'baru');
    });
  });

  group('SalesAnalytics', () {
    final sample = buildSampleSalesData(_today);
    final sampleRecords = latestRecords(sample.uploads);

    test(
      'data contoh: daftar bulan, omzet harian, pembanding, status stok',
      () {
        final months = availableMonths(sampleRecords);
        expect(months, [DateTime(2026, 9), DateTime(2026, 8)]);

        final september = SalesAnalytics.from(
          sampleRecords,
          month: DateTime(2026, 9),
        );
        expect(september.days, hasLength(13), reason: 'data sampai 13 Sep');
        expect(september.revenueByStoreDay.keys, ['Toko 1', 'Toko 2']);
        expect(september.current!.start, DateTime(2026, 9));
        expect(september.current!.end, DateTime(2026, 9, 13));
        expect(september.previous!.start, DateTime(2026, 8));
        expect(september.previous!.end, DateTime(2026, 8, 13));
        expect(september.topProducts, isNotEmpty);
        expect(september.stockLevels, hasLength(16));
        expect(
          september.stockLevels.map((s) => s.status).toSet(),
          StockStatus.values.toSet(),
        );
        expect(
          september.stockAlerts.map((s) => (s.storeName, s.productCode)),
          containsAll([('Toko 1', 'IP17PM'), ('Toko 2', 'AWS11')]),
        );
        expect(
          september.restockCandidates.length,
          greaterThan(september.stockAlerts.length),
          reason: 'hampir menipis ikut jadi kandidat kirim',
        );
        final order = september.stockLevels.map((s) => s.status.index).toList();
        expect(order, orderedEquals([...order]..sort()));

        final august = SalesAnalytics.from(
          sampleRecords,
          month: DateTime(2026, 8),
        );
        expect(august.days, hasLength(31));
        expect(august.current!.start, DateTime(2026, 8));
        expect(august.previous, isNull, reason: 'tidak ada data Juli');
        expect(
          august.current!.revenue + september.current!.revenue,
          sampleRecords.fold(0, (sum, r) => sum + r.revenue),
        );

        final empty = SalesAnalytics.from(
          sampleRecords,
          month: DateTime(2026, 6),
        );
        expect(empty.hasData, isFalse);
        expect(
          empty.stockLevels,
          hasLength(16),
          reason: 'stok tetap stok terakhir',
        );
      },
    );

    test('filter toko hanya memakai data toko itu', () {
      final analytics = SalesAnalytics.from(
        sampleRecords,
        month: DateTime(2026, 9),
        storeName: 'Toko 2',
      );
      expect(analytics.revenueByStoreDay.keys, ['Toko 2']);
      expect(
        analytics.stockLevels.every((s) => s.storeName == 'Toko 2'),
        isTrue,
      );
    });

    test(
      'bulan belum lengkap dibandingkan dengan tanggal yang sama bulan lalu',
      () {
        SalesRecord row(DateTime date, int quantity) => SalesRecord(
          storeName: 'Toko 1',
          date: date,
          productCode: 'A',
          productName: 'A',
          quantity: quantity,
          unitPrice: 1000,
          stockEnd: 100,
        );
        final records = [
          for (var d = 1; d <= 31; d++) row(DateTime(2026, 8, d), 10),
          for (var d = 1; d <= 15; d++) row(DateTime(2026, 9, d), 12),
        ];

        final analytics = SalesAnalytics.from(
          records,
          month: DateTime(2026, 9),
        );
        expect(analytics.current!.revenue, 15 * 12000);
        expect(
          analytics.previous!.revenue,
          15 * 10000,
          reason: 'hanya 1–15 Agustus',
        );
        expect(analytics.risers.single.changePercent, closeTo(20, 0.001));

        // 31 Maret dibanding Februari: dibatasi sampai 28 Februari.
        final march = SalesAnalytics.from([
          for (var d = 1; d <= 28; d++) row(DateTime(2027, 2, d), 1),
          row(DateTime(2027, 3, 31), 1),
        ], month: DateTime(2027, 3));
        expect(march.previous!.end, DateTime(2027, 2, 28));
        expect(march.previous!.quantity, 28);
      },
    );

    test('status stok: habis, menipis, hampir menipis, aman', () {
      final levels = computeStockLevels([
        _row('HABIS', 10, quantity: 2, stock: 0),
        _row('MIN', 10, quantity: 0, stock: 3, minStock: 3),
        _row('CEPAT', 9, quantity: 2, stock: 12, minStock: null),
        _row('CEPAT', 10, quantity: 2, stock: 10, minStock: null),
        _row('HAMPIR', 9, quantity: 2, stock: 22, minStock: null),
        _row('HAMPIR', 10, quantity: 2, stock: 20, minStock: null),
        _row('DUAKALIMIN', 10, quantity: 0, stock: 6, minStock: 3),
        _row('AMAN', 10, quantity: 1, stock: 50, minStock: 3),
      ]);
      final byCode = {for (final level in levels) level.productCode: level};

      expect(byCode['HABIS']!.status, StockStatus.out);
      expect(byCode['MIN']!.status, StockStatus.low);
      expect(
        byCode['CEPAT']!.status,
        StockStatus.low,
        reason: '10 / 2 per hari = 5 hari',
      );
      expect(byCode['CEPAT']!.daysLeft, 5);
      expect(
        byCode['HAMPIR']!.status,
        StockStatus.nearLow,
        reason: '20 / 2 = 10 hari',
      );
      expect(
        byCode['DUAKALIMIN']!.status,
        StockStatus.nearLow,
        reason: '≤ 2x minimum',
      );
      expect(byCode['AMAN']!.status, StockStatus.ok);
      expect(levels.first.productCode, 'HABIS');
      expect(levels.last.productCode, 'AMAN');
    });

    test(
      'pengiriman diterima setelah upload menambah stok; sebelum upload tidak',
      () {
        final uploadedAt = DateTime(2026, 9, 11, 9);
        final records = [
          _row('IP17PM', 10, quantity: 1, stock: 0, uploadedAt: uploadedAt),
        ];
        Shipment shipment(
          ShipmentStatus status,
          DateTime? receivedAt,
          int qty,
        ) => Shipment(
          id: 's$qty',
          storeName: 'Toko 1',
          status: status,
          items: [
            ShipmentItem(
              productCode: 'IP17PM',
              productName: 'iPhone',
              quantity: qty,
              stockBefore: 0,
            ),
          ],
          createdBy: 'Admin Pusat',
          createdByEmail: 'pusat@supply.id',
          createdAt: DateTime(2026, 9, 10),
          receivedAt: receivedAt,
        );

        final level = computeStockLevels(
          records,
          shipments: [
            shipment(ShipmentStatus.received, DateTime(2026, 9, 11, 15), 12),
            shipment(ShipmentStatus.received, DateTime(2026, 9, 11, 8), 5),
            shipment(ShipmentStatus.inTransit, null, 3),
          ],
        ).single;

        expect(
          level.stock,
          12,
          reason: 'yang diterima jam 8 sudah termasuk di stok_akhir',
        );
        expect(level.receivedSinceUpload, 12);
        expect(level.incoming, 3);
        expect(
          level.status,
          StockStatus.nearLow,
          reason: '12 unit / 1 per hari = 12 hari',
        );
      },
    );

    test('saran jumlah kirim membuat status kembali aman', () {
      final records = [
        for (var d = 1; d <= 14; d++)
          _row('IP17PM', d, quantity: 2, stock: d == 14 ? 1 : 30),
      ];
      final before = computeStockLevels(records).single;
      expect(before.status, StockStatus.low);

      final after = computeStockLevels(
        records,
        shipments: [
          Shipment(
            id: 's',
            storeName: 'Toko 1',
            status: ShipmentStatus.received,
            items: [
              ShipmentItem(
                productCode: 'IP17PM',
                productName: 'iPhone',
                quantity: before.suggestedRestock,
                stockBefore: 1,
              ),
            ],
            createdBy: 'Admin Pusat',
            createdByEmail: 'pusat@supply.id',
            createdAt: DateTime(2026, 9, 14),
            receivedAt: DateTime(2026, 9, 15),
          ),
        ],
      ).single;
      expect(after.status, StockStatus.ok);
    });
  });

  group('InMemorySalesRepository', () {
    const storeAdmin = AppUser(
      id: 'u',
      name: 'Admin Toko 1',
      email: 'toko1@supply.id',
      role: UserRole.storeAdmin,
      storeName: 'Toko 1',
    );
    const centralAdmin = AppUser(
      id: 'p',
      name: 'Admin Pusat',
      email: 'pusat@supply.id',
      role: UserRole.centralAdmin,
    );

    test(
      'simpan upload, hitung baris yang tergantikan, stream ikut update',
      () async {
        final repository = InMemorySalesRepository(withSampleData: false);
        final updates = <int>[];
        final subscription = repository
            .watchUploads(since: DateTime(2026, 9, 1))
            .listen((uploads) => updates.add(uploads.length));

        await repository.saveUpload(
          user: storeAdmin,
          fileName: 'a.xlsx',
          reportMonth: DateTime(2026, 9),
          records: [
            _row('IP17PM', 8, quantity: 1, stock: 2),
            _row('IP17PM', 9, quantity: 1, stock: 1),
          ],
        );
        expect(
          await repository.countExistingRecords([
            _row('IP17PM', 9, quantity: 0, stock: 10),
            _row('IP17PM', 10, quantity: 0, stock: 10),
          ]),
          1,
        );
        await Future<void>.delayed(Duration.zero);
        expect(updates, [0, 1]);
        await subscription.cancel();
      },
    );

    test(
      'pengiriman: pusat membuat, toko mengonfirmasi, toko lain ditolak',
      () async {
        final repository = InMemorySalesRepository(withSampleData: false);
        final items = [
          const ShipmentItem(
            productCode: 'IP17PM',
            productName: 'iPhone 17 Pro Max',
            quantity: 10,
            stockBefore: 0,
          ),
        ];

        expect(
          () => repository.createShipment(
            user: storeAdmin,
            storeName: 'Toko 1',
            items: items,
          ),
          throwsStateError,
        );
        final shipment = await repository.createShipment(
          user: centralAdmin,
          storeName: 'Toko 1',
          items: items,
        );
        expect(
          () => repository.confirmShipment(
            user: centralAdmin,
            shipment: shipment,
          ),
          throwsStateError,
        );

        await repository.confirmShipment(user: storeAdmin, shipment: shipment);
        final stored = await repository
            .watchShipments(since: DateTime(2000), storeName: 'Toko 1')
            .first;
        expect(stored.single.status, ShipmentStatus.received);
        expect(stored.single.receivedBy, 'Admin Toko 1');
        expect(
          () =>
              repository.confirmShipment(user: storeAdmin, shipment: shipment),
          throwsStateError,
          reason: 'tidak bisa dikonfirmasi dua kali',
        );
      },
    );

    test(
      'katalog: hanya pusat yang bisa menambah/mengubah; kode tidak dobel',
      () async {
        final repository = InMemorySalesRepository(withSampleData: false);
        const product = CatalogProduct(
          code: 'IPAIR',
          name: 'iPhone Air',
          category: 'iPhone',
          price: 19999000,
          minStock: 3,
        );

        expect(
          () => repository.saveProduct(
            user: storeAdmin,
            product: product,
            isNew: true,
          ),
          throwsStateError,
        );
        await repository.saveProduct(
          user: centralAdmin,
          product: product,
          isNew: true,
        );
        expect(
          () => repository.saveProduct(
            user: centralAdmin,
            product: product,
            isNew: true,
          ),
          throwsStateError,
        );
        await repository.saveProduct(
          user: centralAdmin,
          product: product.copyWith(price: 18999000),
          isNew: false,
        );

        final catalog = await repository.watchProducts().first;
        expect(catalog, hasLength(9));
        expect(catalog.firstWhere((p) => p.code == 'IPAIR').price, 18999000);
        expect(
          catalog.map((p) => p.category).toList().indexOf('MacBook'),
          greaterThan(
            catalog.map((p) => p.category).toList().lastIndexOf('iPhone'),
          ),
          reason: 'urut per kategori',
        );
      },
    );

    test(
      'stok di katalog ikut upload terbaru dan pengiriman yang diterima',
      () async {
        final repository = InMemorySalesRepository(withSampleData: false);
        Future<int?> stockOf(String code) async =>
            (await repository.watchProducts().first)
                .firstWhere((p) => p.code == code)
                .stockByStore['Toko 1']
                ?.stock;

        await repository.saveUpload(
          user: storeAdmin,
          fileName: 'baru.xlsx',
          reportMonth: DateTime(2026, 9),
          records: [
            _row('IP17PM', 9, quantity: 1, stock: 3),
            _row('IP17PM', 10, quantity: 1, stock: 2),
          ],
        );
        expect(await stockOf('IP17PM'), 2);

        await repository.saveUpload(
          user: storeAdmin,
          fileName: 'lama.xlsx',
          reportMonth: DateTime(2026, 9),
          records: [_row('IP17PM', 1, quantity: 0, stock: 40)],
        );
        expect(
          await stockOf('IP17PM'),
          2,
          reason: 'data tanggal lama tidak menimpa',
        );

        final shipment = await repository.createShipment(
          user: centralAdmin,
          storeName: 'Toko 1',
          items: const [
            ShipmentItem(
              productCode: 'IP17PM',
              productName: 'iPhone 17 Pro Max',
              quantity: 10,
              stockBefore: 2,
            ),
          ],
        );
        expect(await stockOf('IP17PM'), 2, reason: 'belum diterima');
        await repository.confirmShipment(user: storeAdmin, shipment: shipment);
        expect(await stockOf('IP17PM'), 12);
      },
    );
    test(
      'simpan banyak produk: baru ditambah, lama diperbarui, stok tetap',
      () async {
        final repository = InMemorySalesRepository();
        final before = await repository.watchProducts().first;
        final proMax = before.firstWhere((p) => p.code == 'IP17PM');

        expect(
          () => repository.saveProducts(user: storeAdmin, products: const []),
          throwsStateError,
        );
        await repository.saveProducts(
          user: centralAdmin,
          products: [
            const CatalogProduct(
              code: 'IPAIR',
              name: 'iPhone Air',
              category: 'iPhone',
              price: 19999000,
              minStock: 2,
            ),
            CatalogProduct(
              code: 'IP17PM',
              name: proMax.name,
              category: proMax.category,
              price: 1,
              minStock: proMax.minStock,
            ),
          ],
        );

        final after = await repository.watchProducts().first;
        expect(after, hasLength(before.length + 1));
        final updated = after.firstWhere((p) => p.code == 'IP17PM');
        expect(updated.price, 1);
        expect(
          updated.totalStock,
          proMax.totalStock,
          reason: 'stok per toko tidak berubah',
        );
      },
    );
  });
}

SalesRecord _row(
  String code,
  int day, {
  required int quantity,
  required int stock,
  int price = 24999000,
  int? minStock = 4,
  DateTime? uploadedAt,
}) => SalesRecord(
  storeName: 'Toko 1',
  date: DateTime(2026, 9, day),
  productCode: code,
  productName: code,
  quantity: quantity,
  unitPrice: price,
  stockEnd: stock,
  minStock: minStock,
  uploadedAt: uploadedAt,
);
