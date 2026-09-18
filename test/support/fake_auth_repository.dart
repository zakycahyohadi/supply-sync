import 'package:supply_sync/data/auth_repository.dart';
import 'package:supply_sync/data/user_directory.dart';
import 'package:supply_sync/models/app_user.dart';

/// Pengganti Firebase Auth untuk test.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? signedIn}) : _currentUser = signedIn;

  static const passwords = {
    'pusat@supply.id': 'pusat123',
    'toko1@supply.id': 'toko123',
    'toko2@supply.id': '123456',
  };

  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser?> restoreSession() async => _currentUser;

  @override
  Future<AppUser> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (passwords[normalized] != password) {
      throw const AuthException('Email atau password salah.');
    }
    return _currentUser = appUserForEmail(id: normalized, email: normalized)!;
  }

  @override
  Future<void> logout() async => _currentUser = null;
}
