import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
     
     
    return 'http://192.168.162.162:5000/api'; 
  }
      
  static const String loginEndpoint = '/auth/login';
  static const String deliveriesEndpoint = '/deliveries';
  static const String ordersEndpoint = '/orders';
  static const String clientsEndpoint = '/clients';
}