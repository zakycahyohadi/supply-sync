import '../models/app_user.dart';

/// Akun yang boleh masuk dan role-nya, berdasarkan email Firebase Auth.
///
/// SAMAKAN dengan fungsi `centralAdmins()` & `storeAdmins()` di
/// `firestore.rules`. Untuk menambah admin toko: buat akunnya di Firebase
/// Console → Authentication, tambahkan di sini dan di rules, lalu deploy rules.
// TODO(firebase): pindahkan ke koleksi `users` kalau akun makin banyak.
const kUserDirectory =
    <String, ({String name, UserRole role, String? storeName})>{
      'pusat@supply.id': (
        name: 'Admin Pusat',
        role: UserRole.centralAdmin,
        storeName: null,
      ),
      'toko1@supply.id': (
        name: 'Admin Toko 1',
        role: UserRole.storeAdmin,
        storeName: 'Toko 1',
      ),
      'toko2@supply.id': (
        name: 'Admin Toko 2',
        role: UserRole.storeAdmin,
        storeName: 'Toko 2',
      ),
    };

/// Null kalau email tidak terdaftar.
AppUser? appUserForEmail({required String id, required String email}) {
  final normalized = email.trim().toLowerCase();
  final entry = kUserDirectory[normalized];
  if (entry == null) return null;
  return AppUser(
    id: id,
    name: entry.name,
    email: normalized,
    role: entry.role,
    storeName: entry.storeName,
  );
}
