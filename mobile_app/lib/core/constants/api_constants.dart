import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConstants {
  // CONFIGURATION IP PC (IP Locale Fixe)
  static const String pcIp = '192.168.162.162'; 

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    return 'http://${pcIp}:5000/api';
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
