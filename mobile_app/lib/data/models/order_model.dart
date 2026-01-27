import '../../domain/entities/order_entity.dart';

class OrderModel extends OrderEntity {
  OrderModel({
    required String id,
    required String status,
    required String createdAt,
    required String itemsDescription,
    required int quantityVitale,
    required int quantityVoltic,
    required double totalAmount,
    String? preferredTime,
    String? instructions,
  }) : super(
          id: id,
          status: status,
          createdAt: createdAt,
          itemsDescription: itemsDescription,
          quantityVitale: quantityVitale,
          quantityVoltic: quantityVoltic,
          totalAmount: totalAmount,
          preferredTime: preferredTime,
          instructions: instructions,
        );

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'].toString(),
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
      itemsDescription: json['items_description'] ?? '',
      quantityVitale: json['quantity_vitale'] ?? 0,
      quantityVoltic: json['quantity_voltic'] ?? 0,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      preferredTime: json['preferred_time'],
      instructions: json['instructions'],
    );
  }
}
