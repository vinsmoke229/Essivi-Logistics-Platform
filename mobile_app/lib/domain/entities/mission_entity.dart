class MissionEntity {
  final int id;
  final int clientId;
  final String clientName;
  final String clientPhone;
  final String clientAddress;
  final double gpsLat;
  final double gpsLng;
  final int quantityVitale;
  final int quantityVoltic;
  final double totalAmount;
  final String? instructions;

  MissionEntity({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.clientAddress,
    required this.gpsLat,
    required this.gpsLng,
    required this.quantityVitale,
    required this.quantityVoltic,
    required this.totalAmount,
    this.instructions,
  });
}
