class AuthUser {
  const AuthUser({required this.id, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! String || id.isEmpty || email is! String || email.isEmpty) {
      throw const FormatException('Invalid user response');
    }
    return AuthUser(id: id, email: email);
  }

  final String id;
  final String email;
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'];
    if (token is! String ||
        token.trim().isEmpty ||
        json['token_type']?.toString().toLowerCase() != 'bearer') {
      throw const FormatException('Invalid authentication response');
    }
    return AuthSession(
      accessToken: token,
      user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }

  final String accessToken;
  final AuthUser user;
}
