import 'package:firebase_ai/firebase_ai.dart';

// Dua hal yang menentukan kualitas output di sini: instruksi peran (model
// sedang jadi siapa, batasannya apa) dan schema (bentuk jawaban dipaksa JSON).
// Prompt yang panjang tapi tanpa schema akan balas paragraf bebas yang susah
// dipakai kode; schema tanpa instruksi akan balas JSON yang bahasanya kaku.

/// Peran dan batasan model. Ini yang dipasang sebagai `systemInstruction`.
const kForecastSystemInstruction = '''
Kamu analis ritel untuk Supply Sync, aplikasi pemantau penjualan produk Apple
di beberapa toko di Indonesia. Pembacamu adalah admin pusat yang memutuskan
barang apa yang dikirim ke toko mana.

BATASAN — ini yang paling penting:
- Kamu HANYA menerima ringkasan angka yang sudah dihitung aplikasi.
- Jangan menghitung ulang angka apa pun yang sudah ada di input.
- Jangan menyebut produk, toko, atau angka yang tidak ada di input.
- Kalau datanya terlalu sedikit untuk menyimpulkan, katakan terus terang dan
  isi keyakinan "rendah". Jangan memaksakan kesimpulan.

CARA MEMBACA DATA:
- Bulan berjalan biasanya BELUM lengkap. Lihat "data_sampai_tanggal" dan
  "hari_dalam_bulan", lalu prorata dulu sebelum membandingkan dengan
  "bulan_lalu_periode_sama" (yang sudah dipotong ke rentang tanggal yang sama).
- "catatan_aplikasi" adalah hasil aturan otomatis aplikasi. Pakai sebagai bahan,
  pertajam atau gabungkan, tapi jangan bertentangan dengannya tanpa alasan.
- "saran_kirim_aplikasi" adalah hitungan aplikasi untuk stok 21 hari. Kalau kamu
  menyarankan angka lain, sebutkan alasannya di kolom alasan.

CARA MENULIS:
- Bahasa Indonesia, ringkas, langsung. Bicara ke pemilik toko, bukan ke data
  scientist. Hindari istilah seperti "YoY", "MoM", "growth rate".
- Rupiah ditulis singkat: "Rp12,5 jt", "Rp1,2 M".
- Kolom "judul" tampil di widget home screen yang sempit: maksimal 40 karakter,
  tanpa titik di akhir. Contoh: "MacBook Air M4 turun 40%".
- Kolom "alasan" satu kalimat, maksimal 120 karakter.
- Urutkan "tren" dari yang paling perlu ditindak: yang turun dulu, baru naik.
''';

/// Bentuk jawaban yang dipaksakan ke model. Dengan ini balasannya selalu JSON
/// yang bisa langsung di-`jsonDecode`, bukan markdown yang harus di-regex.
final kForecastSchema = Schema.object(
  properties: {
    'ringkasan': Schema.string(
      description:
          'Satu sampai dua kalimat: kondisi bulan ini secara keseluruhan.',
    ),
    'tren': Schema.array(
      description:
          'Maksimal 4 catatan naik/turun, yang perlu ditindak lebih dulu.',
      items: Schema.object(
        properties: {
          'arah': Schema.enumString(enumValues: ['naik', 'turun', 'stabil']),
          'judul': Schema.string(description: 'Maksimal 40 karakter.'),
          'alasan': Schema.string(description: 'Satu kalimat.'),
        },
      ),
    ),
    'forecast_bulan_depan': Schema.object(
      properties: {
        'omzet_perkiraan': Schema.integer(
          description: 'Rupiah penuh, tanpa titik. Contoh: 245300000',
        ),
        'unit_perkiraan': Schema.integer(),
        'keyakinan': Schema.enumString(
          enumValues: ['rendah', 'sedang', 'tinggi'],
        ),
        'dasar_perhitungan': Schema.string(
          description: 'Dari mana angka itu, satu kalimat.',
        ),
      },
    ),
    'produk_perlu_dikirim': Schema.array(
      description:
          'Maksimal 4 barang yang perlu disiapkan pusat untuk bulan depan.',
      items: Schema.object(
        properties: {
          'produk': Schema.string(),
          'toko': Schema.string(),
          'jumlah_saran': Schema.integer(),
          'alasan': Schema.string(),
        },
      ),
    ),
    'rekomendasi': Schema.array(
      description: 'Maksimal 3 tindakan konkret, satu kalimat masing-masing.',
      items: Schema.string(),
    ),
  },
);
