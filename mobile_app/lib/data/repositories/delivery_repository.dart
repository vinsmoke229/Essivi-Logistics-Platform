import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/delivery_remote_data_source.dart';
import '../../core/network/api_client.dart';
import '../../presentation/providers/core_providers.dart';

abstract class DeliveryRepository {
  Future<bool> sendDelivery({
    required int clientId,
    required int qtyVitale,
    required int qtyVoltic,
    required double amount,
    required double gpsLat,
    required double gpsLng,
    String? photoUrl,
    String? signatureUrl,
  });
}

class DeliveryRepositoryImpl implements DeliveryRepository {
  final DeliveryRemoteDataSource remoteDataSource;

  DeliveryRepositoryImpl({required this.remoteDataSource});

  @override
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
    return await remoteDataSource.sendDelivery(
      clientId: clientId,
      qtyVitale: qtyVitale,
      qtyVoltic: qtyVoltic,
      amount: amount,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      photoUrl: photoUrl,
      signatureUrl: signatureUrl,
    );
  }
}

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return DeliveryRepositoryImpl(
    remoteDataSource: DeliveryRemoteDataSource(apiClient: apiClient),
  );
});
