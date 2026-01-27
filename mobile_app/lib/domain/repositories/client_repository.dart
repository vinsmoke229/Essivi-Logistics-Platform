import '../entities/order_entity.dart';

abstract class ClientRepository {
  Future<List<OrderEntity>> getOrders();
  Future<bool> createOrder({
    required List<Map<String, dynamic>> items,
    String? preferredTime,
    String? instructions,
  });
  Future<Map<String, dynamic>> getStats();
}
