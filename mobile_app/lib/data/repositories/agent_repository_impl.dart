import '../../domain/entities/mission_entity.dart';
import '../../domain/repositories/agent_repository.dart';
import '../datasources/agent_remote_data_source.dart';

class AgentRepositoryImpl implements AgentRepository {
  final AgentRemoteDataSource remoteDataSource;

  AgentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<String?> startTour(double lat, double lng) async {
    return await remoteDataSource.startTour(lat, lng);
  }

  @override
  Future<String?> endTour(double lat, double lng) async {
    return await remoteDataSource.endTour(lat, lng);
  }

  @override
  Future<void> updateLocation(double lat, double lng) async {
    await remoteDataSource.updateLocation(lat, lng);
  }

  @override
  Future<List<MissionEntity>> getMissions() async {
    return await remoteDataSource.getMissions();
  }
}
