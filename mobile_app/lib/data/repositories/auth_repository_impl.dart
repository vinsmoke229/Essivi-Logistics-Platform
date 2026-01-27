import 'package:dio/dio.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<UserEntity?> login(String identifier, String password) async {
    try {
      print("🔍 DEBUG - AuthRepositoryImpl.login appelé pour $identifier");
      final userModel = await remoteDataSource.login(identifier, password);
      print("🔍 DEBUG - Connexion réussie, mise en cache de l'utilisateur");
      await localDataSource.cacheUser(userModel);
      return userModel;
    } on DioException catch (e) {
      print("❌ DEBUG - Erreur Dio dans AuthRepositoryImpl: ${e.response?.statusCode}");
      if (e.response?.statusCode == 401) {
        throw Exception('Identifiants incorrects. Veuillez vérifier votre téléphone et votre PIN.');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Compte suspendu ou non autorisé.');
      } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Délai d\'attente dépassé. Vérifiez votre connexion internet.');
      } else {
        throw Exception('Une erreur réseau est survenue. Veuillez réessayer plus tard.');
      }
    } catch (e) {
      print("❌ DEBUG - Autre erreur dans AuthRepositoryImpl: $e");
      throw Exception('Une erreur inattendue est survenue.');
    }
  }

  Future<void> registerClient(String name, String phone, String address, {String? pin}) async {
    print("🔍 DEBUG - AuthRepositoryImpl: registerClient appelé avec PIN: $pin");
    await remoteDataSource.registerClient(name: name, phone: phone, address: address, pin: pin);
  }

  @override
  Future<void> logout() async {
    await localDataSource.clearCache();
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return await localDataSource.getLastUser();
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await localDataSource.getToken();
    return token != null;
  }
}
