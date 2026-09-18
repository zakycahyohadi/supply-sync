import 'stores.dart';

// Balasan chat customer: aturan kata kunci sederhana, bukan AI dan tidak
// terhubung ke server mana pun. Isinya sengaja hanya hal yang memang bisa
// dijawab dari katalog, jadi tidak ada janji yang tidak bisa ditepati.
//
// Dipisah dari tampilan supaya bisa diuji tanpa merender apa pun.

/// Sapaan pertama yang sudah ada di layar saat chat dibuka.
const kChatGreeting =
    'Halo! Ada yang bisa dibantu soal produk Apple di toko kami?';

/// Pertanyaan siap-pakai yang tampil sebagai tombol.
const kChatQuickQuestions = [
  'Cek stok produk',
  'Lokasi toko',
  'Cara pesan',
  'Garansi',
];

/// Satu aturan balasan: kalau pesan memuat salah satu [keywords], jawab
/// dengan [reply].
class ChatReplyRule {
  const ChatReplyRule({required this.keywords, required this.reply});

  final List<String> keywords;
  final String reply;
}

final _rules = <ChatReplyRule>[
  ChatReplyRule(
    keywords: const ['halo', 'hai', 'hello', 'pagi', 'siang', 'sore', 'malam'],
    reply:
        'Halo! Silakan sebutkan produk yang dicari, nanti saya bantu cek '
        'stoknya.',
  ),
  ChatReplyRule(
    keywords: const ['stok', 'masih ada', 'tersedia', 'sisa', 'ready'],
    reply:
        'Stok tiap produk tertera di kartu katalog di halaman ini, lengkap '
        'dengan toko mana yang punya. Angkanya ikut berubah setiap toko '
        'mengirim laporan penjualan.',
  ),
  ChatReplyRule(
    keywords: const ['harga', 'berapa', 'price', 'diskon', 'promo'],
    reply:
        'Harga terbaru ada di katalog. Untuk penawaran khusus, silakan '
        'tanyakan langsung di toko.',
  ),
  ChatReplyRule(
    keywords: const ['lokasi', 'alamat', 'toko', 'cabang', 'tempat', 'dimana'],
    reply:
        'Saat ini kami melayani di ${kStores.join(' dan ')}. Stok kedua toko '
        'bisa dibandingkan langsung di katalog.',
  ),
  ChatReplyRule(
    keywords: const ['pesan', 'order', 'beli', 'booking', 'checkout'],
    reply:
        'Pilih produknya di katalog, lalu sebutkan nama dan toko tujuan di '
        'sini. Pesanan disiapkan untuk diambil di toko.',
  ),
  ChatReplyRule(
    keywords: const ['kirim', 'ongkir', 'antar', 'delivery', 'ekspedisi'],
    reply:
        'Pengiriman antar toko diatur admin pusat. Untuk pengiriman ke '
        'alamat Anda, silakan tanyakan ketersediaannya di toko terdekat.',
  ),
  ChatReplyRule(
    keywords: const ['garansi', 'warranty', 'servis', 'rusak', 'tukar'],
    reply:
        'Semua unit bergaransi resmi Apple. Simpan bukti pembelian untuk '
        'klaim di gerai servis resmi.',
  ),
  ChatReplyRule(
    keywords: const ['cicil', 'kredit', 'installment', 'paylater'],
    reply:
        'Pembayaran bertahap tersedia lewat kartu kredit bank tertentu. '
        'Detailnya bisa dicek di kasir toko.',
  ),
  ChatReplyRule(
    keywords: const ['terima kasih', 'makasih', 'thanks', 'oke', 'sip'],
    reply: 'Sama-sama! Kalau ada yang lain, tanya saja.',
  ),
];

/// Balasan kalau tidak ada kata kunci yang cocok.
final kChatFallbackReply =
    'Pertanyaan Anda sudah kami catat. Untuk hal yang lebih spesifik, '
    'silakan hubungi ${kStores.first} langsung — katalog di halaman ini '
    'selalu menampilkan stok terbaru.';

/// Balasan untuk [message]. Selalu mengembalikan sesuatu: kalau tidak ada
/// kata kunci yang cocok, dijawab dengan [kChatFallbackReply].
String autoReply(String message) {
  final text = message.toLowerCase();
  for (final rule in _rules) {
    if (rule.keywords.any(text.contains)) return rule.reply;
  }
  return kChatFallbackReply;
}
