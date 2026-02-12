import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String identifier, String password);
  Future<UserModel?> registerClient({required String name, required String phone, required String address, String? responsibleName, String? pin});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<UserModel> login(String identifier, String password) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.loginEndpoint,
        data: {
          'identifier': identifier,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        print("🔍 DEBUG - Réponse backend login: $data");
        return UserModel.fromJson(data);
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel?> registerClient({
    required String name,
    required String phone,
    required String address,
    String? responsibleName,
    String? pin,
  }) async {
    try {
      print("🔍 DEBUG - AuthRemoteDataSourceImpl: registerClient appelé");
      
      final data = {
        'name': name,
        'phone': phone,
        'address': address,
        'responsible_name': responsibleName ?? '',
      };
      
      if (pin != null && pin.isNotEmpty) {
        data['pin'] = pin;
      }
      
      final response = await apiClient.dio.post(
        ApiConstants.clientsEndpoint,
        data: data,
      );
      
      if (response.statusCode == 201) {
        final resData = response.data;
        print("🔍 DEBUG - Inscription réussie: $resData");
        
        final token = resData['access_token'] ?? '';
        print("✅ TOKEN REÇU APRÈS INSCRIPTION: $token");
        
        // On construit un UserModel à partir du retour (access_token, role, name, identifier)
        return UserModel(
          id: resData['id']?.toString() ?? '0',
          name: resData['name'] ?? name,
          accessToken: token,
          role: resData['role'] ?? 'client',
          identifier: resData['identifier'] ?? phone,
        );
      }
      return null;
    } catch (e) {
      print("❌ DEBUG - AuthRemoteDataSourceImpl: Erreur registerClient: $e");
      rethrow;
    }
  }
}
