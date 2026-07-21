/// The authenticated caller's identity, as returned by the auth endpoints and
/// embedded in the signed token. The mobile app only ever handles `student`.
class AppUser {
  final String email;
  final String role;
  final String name;

  const AppUser({required this.email, required this.role, required this.name});

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    final local = email.split('@').first;
    return local.isEmpty ? 'Student' : local;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        email: (json['email'] ?? '').toString(),
        role: (json['role'] ?? 'student').toString(),
        name: (json['name'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'role': role,
        'name': name,
      };
}
