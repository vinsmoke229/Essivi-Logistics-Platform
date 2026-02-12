import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/mission_model.dart';

class AgentRemoteDataSource {
  final ApiClient apiClient;

  AgentRemoteDataSource({required this.apiClient});

  Future<String?> startTour(double lat, double lng) async {
     
     
     
     
     
     
     
    
     
     
     
     
     
    
     
     
     
     
    
    try {
       final response = await apiClient.dio.post('/tours/start', data: {'lat': lat, 'lng': lng});
       return response.data['tour_id']?.toString(); 
    } catch (e) {
        
       throw e;
    }
  }

  Future<String?> endTour(double lat, double lng) async {
    try {
       final response = await apiClient.dio.post('/tours/end', data: {'lat': lat, 'lng': lng});
       return response.data['id']?.toString();
    } catch (e) {
       throw e;
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
    await apiClient.dio.post(
      '${ApiConstants.agentsEndpoint}/location',
      data: {'lat': lat, 'lng': lng},
    );
  }

  Future<List<MissionModel>> getMissions() async {
    final response = await apiClient.dio.get('/orders/my-missions');
    final List data = response.data;
    return data.map((json) => MissionModel.fromJson(json)).toList();
  }
}
