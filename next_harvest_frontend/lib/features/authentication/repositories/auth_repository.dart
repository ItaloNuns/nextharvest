import '../models/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> register(String email, String password);
  Future<AuthUser> currentUser(String accessToken);
}
