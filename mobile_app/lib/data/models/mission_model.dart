import '../../domain/entities/mission_entity.dart';

class MissionModel extends MissionEntity {
  MissionModel({
    required int id,
    required int clientId,
    required String clientName,
    required String clientPhone,
    required String clientAddress,
    required double gpsLat,
    required double gpsLng,
    required int quantityVitale,
    required int quantityVoltic,
    required double totalAmount,
    String? instructions,
  }) : super(
          id: id,
          clientId: clientId,
          clientName: clientName,
          clientPhone: clientPhone,
          clientAddress: clientAddress,
          gpsLat: gpsLat,
          gpsLng: gpsLng,
          quantityVitale: quantityVitale,
          quantityVoltic: quantityVoltic,
          totalAmount: totalAmount,
          instructions: instructions,
        );

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      id: json['order_id'] ?? 0,
      clientId: json['client_id'] ?? 0,
      clientName: json['client_name'] ?? 'Inconnu',
      clientPhone: json['client_phone'] ?? '',
      clientAddress: json['client_address'] ?? '',
      gpsLat: (json['gps_lat'] is String) ? double.parse(json['gps_lat']) : (json['gps_lat'] ?? 0.0).toDouble(),
      gpsLng: (json['gps_lng'] is String) ? double.parse(json['gps_lng']) : (json['gps_lng'] ?? 0.0).toDouble(),
      quantityVitale: json['quantity_vitale'] ?? 0,
      quantityVoltic: json['quantity_voltic'] ?? 0,
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      instructions: json['instructions'],
    );
  }
}
