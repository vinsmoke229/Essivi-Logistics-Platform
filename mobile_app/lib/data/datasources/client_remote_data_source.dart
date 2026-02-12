import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/order_model.dart';

class ClientRemoteDataSource {
  final ApiClient apiClient;

  ClientRemoteDataSource({required this.apiClient});

  Future<List<OrderModel>> getOrders() async {
    try {
      final response = await apiClient.dio.get('${ApiConstants.ordersEndpoint}/');
      final List data = response.data;
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
       
       
      rethrow;
    }
  }

  Future<bool> createOrder({
    required List<Map<String, dynamic>> items,
    String? preferredTime,
    String? instructions,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '${ApiConstants.ordersEndpoint}/',
        data: {
          "items": items,
          "preferred_time": preferredTime,
          "instructions": instructions
        },
      );
      return response.statusCode == 201;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await apiClient.dio.get('/client/profile');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    try {
      final response = await apiClient.dio.put(
        '/client/change-pin',
        data: {
          "old_pin": oldPin,
          "new_pin": newPin
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await apiClient.dio.get('/client/stats');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}
