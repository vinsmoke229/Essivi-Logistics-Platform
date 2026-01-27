import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_remote_data_source.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientRemoteDataSource remoteDataSource;

  ClientRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<OrderEntity>> getOrders() async {
    return await remoteDataSource.getOrders();
  }

  @override
  Future<bool> createOrder({
    required List<Map<String, dynamic>> items,
    String? preferredTime,
    String? instructions,
  }) async {
    return await remoteDataSource.createOrder(
      items: items,
      preferredTime: preferredTime,
      instructions: instructions,
    );
  }

  @override
  Future<Map<String, dynamic>> getStats() async {
    return await remoteDataSource.getStats();
  }
}
