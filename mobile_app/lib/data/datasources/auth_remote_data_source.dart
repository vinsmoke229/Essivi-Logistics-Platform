import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String identifier, String password);
  Future<void> registerClient({required String name, required String phone, required String address, String? pin});
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
  Future<void> registerClient({
    required String name,
    required String phone,
    required String address,
    String? pin,
  }) async {
    try {
      print("🔍 DEBUG - AuthRemoteDataSourceImpl: registerClient appelé");
      print("Nom: $name");
      print("Téléphone: $phone");
      print("Adresse: $address");
      print("PIN: $pin");
      
      final data = {
        'name': name,
        'phone': phone,
        'address': address,
      };
      
      // Ajouter le PIN s'il est fourni
      if (pin != null && pin.isNotEmpty) {
        data['pin'] = pin;
      }
      
      print("🔍 DEBUG - Données envoyées: $data");
      
      final response = await apiClient.dio.post(
        ApiConstants.clientsEndpoint,
        data: data,
      );
      
      print("🔍 DEBUG - Response status: ${response.statusCode}");
      print("🔍 DEBUG - Response data: ${response.data}");
      
    } catch (e) {
      print("❌ DEBUG - AuthRemoteDataSourceImpl: Erreur registerClient: $e");
      rethrow;
    }
  }
}
