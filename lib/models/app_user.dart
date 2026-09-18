enum UserRole {
  centralAdmin('Admin Pusat'),
  storeAdmin('Admin Toko');

  const UserRole(this.label);

  final String label;
}

/// Pengguna yang sedang login.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.storeName,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;

  /// Toko yang dipegang; hanya terisi untuk [UserRole.storeAdmin].
  final String? storeName;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}
