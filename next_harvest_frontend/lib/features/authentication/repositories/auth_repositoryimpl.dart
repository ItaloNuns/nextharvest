import 'package:dio/dio.dart';

import '../models/auth_session.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio);
  final Dio _dio;

  Uri _endpoint(String action) =>
      Uri.parse(_dio.options.baseUrl).resolve('/api/v1/auth/$action');

  @override
  Future<AuthSession> login(String email, String password) =>
      _authenticate('login', email, password);

  @override
  Future<AuthSession> register(
    String email,
    String password, {
    required String name,
  }) => _authenticate('register', email, password, name: name);

  Future<AuthSession> _authenticate(
    String action,
    String email,
    String password, {
    String? name,
  }) async {
    final response = await _dio.postUri<Map<String, dynamic>>(
      _endpoint(action),
      data: {
        if (name != null) 'name': name.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    return AuthSession.fromJson(response.data!);
  }

  @override
  Future<AuthUser> currentUser(String accessToken) async {
    final response = await _dio.getUri<Map<String, dynamic>>(
      _endpoint('me'),
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return AuthUser.fromJson(response.data!);
  }
}
