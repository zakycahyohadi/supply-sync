import '../models/app_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  /// Pesan yang bisa langsung ditampilkan ke pengguna.
  final String message;

  @override
  String toString() => message;
}

/// Login admin. `main.dart` memakai Firebase Auth; test memakai versi palsu.
abstract class AuthRepository {
  static late AuthRepository instance;

  AppUser? get currentUser;

  /// Pulihkan sesi login sebelumnya (dipanggil di splash screen).
  Future<AppUser?> restoreSession();

  /// Melempar [AuthException] kalau gagal.
  Future<AppUser> login(String email, String password);

  Future<void> logout();
}
