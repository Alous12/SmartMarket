class User {
  const User({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String name;
  final String lastName;
  final String email;
  final String role;
  final bool isActive;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id'] as int,
      name: json['name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isActive: json['status'] == true || json['status'] == 1,
    );
  }
}
