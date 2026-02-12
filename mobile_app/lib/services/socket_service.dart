import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';

 
 
class SocketService {
   
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

   
  IO.Socket? _socket;
  bool _isConnected = false;
  
   
  final _positionController = StreamController<AgentPosition>.broadcast();
  
   
  final _errorController = StreamController<String>.broadcast();

   
  bool get isConnected => _isConnected;
  Stream<AgentPosition> get positionStream => _positionController.stream;
  Stream<String> get errorStream => _errorController.stream;

   
  
   
   
   
  void connect({
    required String token,
    String? orderId,
  }) {
    if (_socket != null && _isConnected) {
      debugPrint('⚠️ Socket déjà connecté');
      return;
    }

    try {
       
       
      final socketUrl = ApiConstants.baseUrl.replaceAll('/api', '');
      
      _socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'auth': {'token': token},
      });

      _setupListeners(orderId);
      _socket!.connect();
      
      debugPrint('🔌 Connexion Socket.IO initiée vers: $socketUrl');
    } catch (e) {
      debugPrint('❌ Erreur connexion Socket: $e');
      _errorController.add('Erreur de connexion: $e');
    }
  }

   
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      debugPrint('🔌 Socket déconnecté');
    }
  }

   
  void joinOrderRoom(String orderId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join_order', {'order_id': orderId});
      debugPrint('🚪 Rejoint la room: order_$orderId');
    } else {
      debugPrint('⚠️ Impossible de rejoindre la room: Socket non connecté');
    }
  }

   
  void leaveOrderRoom(String orderId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leave_order', {'order_id': orderId});
      debugPrint('🚪 Quitté la room: order_$orderId');
    }
  }

   
  
  void _setupListeners(String? orderId) {
     
    _socket!.on('connect', (_) {
      _isConnected = true;
      debugPrint('✅ Socket connecté !');
      
       
      if (orderId != null) {
        joinOrderRoom(orderId);
      }
    });

     
    _socket!.on('disconnect', (_) {
      _isConnected = false;
      debugPrint('❌ Socket déconnecté');
    });

     
    _socket!.on('error', (error) {
      debugPrint('❌ Erreur Socket: $error');
      _errorController.add('Erreur: $error');
    });

     
    _socket!.on('reconnect', (attempt) {
      debugPrint('🔄 Reconnecté après $attempt tentative(s)');
      _isConnected = true;
      
       
      if (orderId != null) {
        joinOrderRoom(orderId);
      }
    });

     
    _socket!.on('agent_position_update', (data) {
      try {
        final position = AgentPosition.fromJson(data);
        _positionController.add(position);
        debugPrint('📍 Position reçue: ${position.lat}, ${position.lng}');
      } catch (e) {
        debugPrint('❌ Erreur parsing position: $e');
        debugPrint('Données reçues: $data');
      }
    });
  }

   
  void dispose() {
    disconnect();
    _positionController.close();
    _errorController.close();
  }
}

 
 
class AgentPosition {
  final int agentId;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String? orderId;

  AgentPosition({
    required this.agentId,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.orderId,
  });

  factory AgentPosition.fromJson(Map<String, dynamic> json) {
    return AgentPosition(
      agentId: json['agent_id'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      orderId: json['order_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent_id': agentId,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp.toIso8601String(),
      'order_id': orderId,
    };
  }
}
