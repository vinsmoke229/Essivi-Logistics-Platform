import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  Future<UserModel?> getLastUser();
  Future<String?> getToken();
  Future<void> clearCache();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> cacheUser(UserModel user) async {
    print("🔍 DEBUG - cacheUser appelé avec token: ${user.accessToken.isNotEmpty ? 'OUI' : 'NON'}");
    print("🔍 DEBUG - Token à sauvegarder: ${user.accessToken.substring(0, 20)}...");
    print("🔍 DEBUG - Clé utilisée: ${AppConstants.tokenKey}");
    
    await sharedPreferences.setString(AppConstants.tokenKey, user.accessToken);
    await sharedPreferences.setString('cached_user', json.encode(user.toJson()));
    
    print("🔍 DEBUG - Token sauvegardé dans SharedPreferences");
    
     
    final savedToken = sharedPreferences.getString(AppConstants.tokenKey);
    print("🔍 DEBUG - Vérification token sauvegardé: ${savedToken != null ? 'OUI' : 'NON'}");
    print("🔍 DEBUG - Token vérifié (premiers 20): ${savedToken?.substring(0, 20) ?? 'NULL'}");
  }

  @override
  Future<UserModel?> getLastUser() async {
    final jsonString = sharedPreferences.getString('cached_user');
    if (jsonString != null) {
      return UserModel.fromJson(json.decode(jsonString));
    }
    return null;
  }

  @override
  Future<String?> getToken() async {
    final token = sharedPreferences.getString(AppConstants.tokenKey);
    print("🔍 DEBUG - getToken appelé");
    print("🔍 DEBUG - Clé recherchée: ${AppConstants.tokenKey}");
    print("🔍 DEBUG - Token trouvé: ${token != null ? 'OUI' : 'NON'}");
    if (token != null) {
      print("🔍 DEBUG - Token (premiers 20 chars): ${token.substring(0, token.length > 20 ? 20 : token.length)}");
    }
    return token;
  }

  @override
  Future<void> clearCache() async {
    await sharedPreferences.remove(AppConstants.tokenKey);
    await sharedPreferences.remove('cached_user');
  }
}
