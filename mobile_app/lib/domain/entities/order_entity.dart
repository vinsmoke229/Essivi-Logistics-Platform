class OrderEntity {
  final String id;
  final String status;
  final String createdAt;
  final String itemsDescription;
  final int quantityVitale;  
  final int quantityVoltic;  
  final String? preferredTime;
  final String? instructions;
  final double totalAmount;

  OrderEntity({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.itemsDescription,
    required this.quantityVitale,
    required this.quantityVoltic,
    required this.totalAmount,
    this.preferredTime,
    this.instructions,
  });
}
