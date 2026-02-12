import 'package:dio/dio.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
       
      final userModel = await remoteDataSource.login(identifier, password);
      
       
      if (userModel == null) {
        print("⚠️ REPOSITORY - Retour NULL du serveur");
        return null;
      }

      print("🔍 DEBUG - Connexion réussie, mise en cache de l'utilisateur: ${userModel.name}");
      await localDataSource.cacheUser(userModel);

       
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', userModel.accessToken);
      await prefs.setString('role', userModel.role);
      await prefs.setString('name', userModel.name);
      
      print("💾 REPOSITORY SAVED: ${userModel.role} - ${userModel.name}");

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

  @override
  Future<UserEntity?> registerClient(String name, String phone, String address, {String? responsibleName, String? pin}) async {
    try {
      print("🔍 DEBUG - AuthRepositoryImpl: registerClient appelé avec Gérant: $responsibleName, PIN: $pin");
      final userModel = await remoteDataSource.registerClient(
        name: name, 
        phone: phone, 
        address: address, 
        responsibleName: responsibleName, 
        pin: pin
      );

      if (userModel != null) {
        print("🔍 DEBUG - Inscription + Auto-Login réussi: ${userModel.name}");
        await localDataSource.cacheUser(userModel);

         
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', userModel.accessToken);
        await prefs.setString('role', userModel.role);
        await prefs.setString('name', userModel.name);
        if (userModel.identifier != null) {
          await prefs.setString('identifier', userModel.identifier!);
        }
        
        return userModel;
      }
      return null;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 409) {
        throw Exception('Ce numéro est déjà enregistré.');
      } else if (statusCode == 400) {
        throw Exception('Veuillez remplir tous les champs correctement.');
      } else {
        throw Exception('Erreur de connexion au serveur.');
      }
    } catch (e) {
      throw Exception('Une erreur inattendue est survenue.');
    }
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
