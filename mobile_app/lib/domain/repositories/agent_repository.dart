import '../entities/mission_entity.dart';

abstract class AgentRepository {
  Future<String?> startTour(double lat, double lng);
  Future<String?> endTour(double lat, double lng);
  Future<void> updateLocation(double lat, double lng);
  Future<List<MissionEntity>> getMissions();
}
