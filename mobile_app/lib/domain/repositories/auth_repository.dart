import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> login(String identifier, String password);
  Future<void> logout();
  Future<UserEntity?> getCurrentUser();
  Future<bool> isAuthenticated();
  Future<UserEntity?> registerClient(String name, String phone, String address, {String? responsibleName, String? pin});
}
