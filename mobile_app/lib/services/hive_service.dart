import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineDelivery {
  final int clientId;
  final int qtyVitale;
  final int qtyVoltic;
  final double amount;
  final double gpsLat;
  final double gpsLng;
  final String? photoPath;
  final String? signatureData;
  final DateTime createdAt;
  bool isSynced;

  OfflineDelivery({
    required this.clientId,
    required this.qtyVitale,
    required this.qtyVoltic,
    required this.amount,
    required this.gpsLat,
    required this.gpsLng,
    this.photoPath,
    this.signatureData,
    required this.createdAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'quantity_vitale': qtyVitale,
      'quantity_voltic': qtyVoltic,
      'amount': amount,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'photo_path': photoPath,
      'signature_data': signatureData,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory OfflineDelivery.fromJson(Map<String, dynamic> json) {
    return OfflineDelivery(
      clientId: json['client_id'],
      qtyVitale: json['quantity_vitale'],
      qtyVoltic: json['quantity_voltic'],
      amount: json['amount'],
      gpsLat: json['gps_lat'],
      gpsLng: json['gps_lng'],
      photoPath: json['photo_path'],
      signatureData: json['signature_data'],
      createdAt: DateTime.parse(json['created_at']),
      isSynced: json['is_synced'] == 1,
    );
  }
}

class HiveService {
  static const String _deliveryBoxName = 'offline_deliveries';
  late Box<OfflineDelivery> _deliveryBox;

  Future<void> init() async {
     
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(OfflineDeliveryAdapter());
    }
    _deliveryBox = await Hive.openBox<OfflineDelivery>(_deliveryBoxName);
  }

  Future<void> saveOfflineDelivery(OfflineDelivery delivery) async {
    await _deliveryBox.add(delivery);
  }

  List<OfflineDelivery> getUnsyncedDeliveries() {
    return _deliveryBox.values.where((d) => !d.isSynced).toList();
  }

  Future<void> markAsSynced(int index) async {
    final delivery = _deliveryBox.getAt(index);
    if (delivery != null) {
      final updatedDelivery = OfflineDelivery(
        clientId: delivery.clientId,
        qtyVitale: delivery.qtyVitale,
        qtyVoltic: delivery.qtyVoltic,
        amount: delivery.amount,
        gpsLat: delivery.gpsLat,
        gpsLng: delivery.gpsLng,
        photoPath: delivery.photoPath,
        signatureData: delivery.signatureData,
        createdAt: delivery.createdAt,
        isSynced: true,
      );
      await _deliveryBox.putAt(index, updatedDelivery);
    }
  }

  Future<void> deleteSyncedDeliveries() async {
    final keysToDelete = <int>[];
    for (int i = 0; i < _deliveryBox.length; i++) {
      final delivery = _deliveryBox.getAt(i);
      if (delivery?.isSynced == true) {
        keysToDelete.add(i);
      }
    }
    await _deliveryBox.deleteAll(keysToDelete);
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  int get unsyncedCount => getUnsyncedDeliveries().length;
}

 
class OfflineDeliveryAdapter extends TypeAdapter<OfflineDelivery> {
  @override
  final int typeId = 1;

  @override
  OfflineDelivery read(BinaryReader reader) {
    return OfflineDelivery(
      clientId: reader.read(),
      qtyVitale: reader.read(),
      qtyVoltic: reader.read(),
      amount: reader.read(),
      gpsLat: reader.read(),
      gpsLng: reader.read(),
      photoPath: reader.read(),
      signatureData: reader.read(),
      createdAt: DateTime.parse(reader.read()),
      isSynced: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, OfflineDelivery obj) {
    writer.write(obj.clientId);
    writer.write(obj.qtyVitale);
    writer.write(obj.qtyVoltic);
    writer.write(obj.amount);
    writer.write(obj.gpsLat);
    writer.write(obj.gpsLng);
    writer.write(obj.photoPath);
    writer.write(obj.signatureData);
    writer.write(obj.createdAt.toIso8601String());
    writer.write(obj.isSynced);
  }
}
