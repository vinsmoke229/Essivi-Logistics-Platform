import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    // IP locale pour téléphone sur le même Wifi (méthode la plus stable pour le debug)
    // Assurez-vous que cette IP est celle de votre PC sur le réseau partagé
    return 'http://192.168.162.162:5000/api'; 
  }
      
  static const String loginEndpoint = '/auth/login';
  static const String deliveriesEndpoint = '/deliveries';
  static const String ordersEndpoint = '/orders';
  static const String clientsEndpoint = '/clients';
}