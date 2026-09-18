# Supply Sync

Aplikasi Flutter untuk memantau penjualan produk Apple di beberapa toko:
admin toko meng-upload laporan penjualan (.xlsx), admin pusat melihat
ringkasannya, mengirim barang ke toko, dan membaca analisis AI.

## Jalankan

```bash
flutter pub get
flutter run
```

Akun contoh ada di `lib/data/user_directory.dart`.

## Test

```bash
flutter analyze
flutter test
```

## Ikon aplikasi

Semua tempat yang menampilkan logo — ikon aplikasi, layar pembuka Android &
iOS, splash screen di dalam aplikasi, header, dan widget home screen —
dibuat dari satu berkas: `assets/icon/logo_source.jpeg`.

Kalau logonya diganti, jalankan dua perintah ini supaya semuanya ikut
diperbarui:

```bash
dart run tool/generate_icons.dart
dart run flutter_launcher_icons
```

> Setelah `flutter_launcher_icons`, periksa `ios/Runner.xcodeproj/project.pbxproj`.
> Versi 0.14.4 keliru menimpa `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
> menjadi `AppIcon`; nilainya harus tetap `YES`.

## Pratinjau web

Setiap push ke `master` di-build dan di-deploy ke GitHub Pages lewat
`.github/workflows/deploy-web.yml`. Di web, aplikasi tampil di dalam bingkai
perangkat (paket `device_preview`).

Perangkatnya bisa diganti lewat query URL:

```
?device=apple-iphone-17-pro          (bawaan)
?device=google-pixel-9
?device=apple-ipad-mini&orientation=landscape
```

Daftar id lengkap ada di `DevicePresets.all`. Bingkai ini hanya menyala di
build web (`--dart-define=DEVICE_PREVIEW=true`); build Android/iOS rilis tidak
terpengaruh.

Sekali lagi di **Settings -> Pages**, pilih **Source: GitHub Actions**.

Supaya login bisa jalan di halaman Pages, tambahkan domainnya di
**Firebase Console -> Authentication -> Settings -> Authorized domains**.

## Analisis AI

Analisis tren & perkiraan bulan depan memakai Gemini lewat Firebase AI Logic,
jadi **tidak ada API key yang disimpan di dalam aplikasi**.

Sekali di Firebase Console:

1. **AI Logic** -> Get started -> pilih backend **Gemini Developer API**
2. **App Check** -> daftarkan app Android/iOS/Web
3. `firebase deploy --only firestore:rules`

Selama belum diaktifkan, aplikasi tetap jalan; hanya kartu "Analisis AI" yang
menampilkan pesan.

### Cara kerjanya

Angka dihitung aplikasi (`lib/data/sales_analytics.dart`), bukan oleh AI.
Yang dikirim ke Gemini hanya ringkasan ±3 KB
(`lib/data/ai/forecast_payload.dart`), dan balasannya dipaksa berbentuk JSON
lewat schema di `lib/data/ai/forecast_prompt.dart`. Hasilnya di-cache di
Firestore dengan id berupa sidik jari data, jadi Gemini hanya dipanggil ulang
kalau datanya berubah.
