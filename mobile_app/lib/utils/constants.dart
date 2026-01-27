import 'package:flutter/foundation.dart';

class ApiConstants {
  // COLLE LE LIEN DE TA DERNIÈRE CAPTURE NGROK
  static String baseUrl = kIsWeb 
      ? 'http://localhost:5000/api' 
      : 'https://unepauletted-fibrillar-flo.ngrok-free.dev/api'; 
      
  static const String loginEndpoint = '/auth/login';
  static const String deliveriesEndpoint = '/deliveries';
  static const String ordersEndpoint = '/orders';
  static const String clientsEndpoint = '/clients';
}