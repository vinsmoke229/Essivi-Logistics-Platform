import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';

class DeliveryRemoteDataSource {
  final ApiClient apiClient;

  DeliveryRemoteDataSource({required this.apiClient});

  Future<bool> sendDelivery({
    required int clientId,
    required int qtyVitale,
    required int qtyVoltic,
    required double amount,
    required double gpsLat,
    required double gpsLng,
    String? photoUrl,
    String? signatureUrl,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '${ApiConstants.deliveriesEndpoint}/', // Ensure trailing slash if backend needs it (flask strict slashes)
        data: {
          "client_id": clientId,
          "quantity_vitale": qtyVitale,
          "quantity_voltic": qtyVoltic,
          "total_amount": amount,
          "gps_lat": gpsLat,
          "gps_lng": gpsLng,
          "photo_url": photoUrl,
          "signature_url": signatureUrl
        },
      );
      return response.statusCode == 201;
    } catch (e) {
      throw e;
    }
  }
}
