import 'package:firebase_auth/firebase_auth.dart';

import '../../models/app_user.dart';
import '../auth_repository.dart';
import '../user_directory.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser?> restoreSession() async {
    final user = await _auth.authStateChanges().first;
    final email = user?.email;
    if (user == null || email == null) return _currentUser = null;

    final appUser = appUserForEmail(id: user.uid, email: email);
    if (appUser == null) await _auth.signOut();
    return _currentUser = appUser;
  }

  @override
  Future<AppUser> login(String email, String password) async {
    final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' => 'Email atau password salah.',
        'user-disabled' => 'Akun ini dinonaktifkan.',
        'too-many-requests' =>
          'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
        'network-request-failed' => 'Tidak ada koneksi internet.',
        _ => 'Login gagal (${e.code}). Coba lagi.',
      });
    }

    final user = credential.user!;
    final appUser = appUserForEmail(id: user.uid, email: user.email ?? '');
    if (appUser == null) {
      await _auth.signOut();
      throw const AuthException('Akun ini belum punya akses ke aplikasi.');
    }
    return _currentUser = appUser;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    await _auth.signOut();
  }
}
