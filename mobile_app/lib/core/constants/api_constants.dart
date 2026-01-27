import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConstants {
  // CONFIGURATION IP PC (Pour les tests sur appareil physique Android)
  static const String pcIp = '192.168.1.100'; // Remplacer par l'IP de votre PC

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (Platform.isAndroid) {
      // 10.0.2.2 est l'adresse pour accéder au localhost du PC depuis l'émulateur Android
      // Si appareil physique, utilisez pcIp
      return 'http://10.0.2.2:5000/api'; 
    }
    return 'http://127.0.0.1:5000/api';
  }
  
  static const String loginEndpoint = '/auth/login';
  static const String agentsEndpoint = '/agents';
  static const String clientsEndpoint = '/clients';
  static const String deliveriesEndpoint = '/deliveries';
  static const String ordersEndpoint = '/orders';
  static const String usersEndpoint = '/users';
}

class AppConstants {
  static const String tokenKey = 'auth_token';
  static const String userTypeKey = 'user_type';
  static const String userIdKey = 'user_id';
}
