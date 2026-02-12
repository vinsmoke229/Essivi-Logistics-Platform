import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/constants/api_constants.dart';

@pragma('vm:entry-point')
class BackgroundLocationService {
  static Future<void> initializeService() async {
    if (kIsWeb) return;
    
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'essivi_tracking',
        initialNotificationTitle: 'Suivi GPS Actif',
        initialNotificationContent: 'Récupération de votre position...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

     
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
      
       
      await service.setForegroundNotificationInfo(
        title: "Suivi GPS Actif",
        content: "Service de localisation en cours...",
      );
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

     
    Timer.periodic(const Duration(seconds: 60), (timer) async {
      try {
         
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          print("Background location skipped: Permissions missing.");
          return;
        }

        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
        } catch (e) {
          print("⚠️ Erreur récupération GPS (non bloquant): $e");
          return;  
        }

        if (position == null) return;

         
        if (position.latitude == 0.0 && position.longitude == 0.0) {
          print("GPS FAIL: Coordonnées nulles ou à 0. Envoi annulé.");
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        if (token != null) {
          final url = Uri.parse('${ApiConstants.baseUrl}/agents/location');
          try {
            await http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'lat': position.latitude,
                'lng': position.longitude,
              }),
            ).timeout(const Duration(seconds: 10));
            print("Background Location Sent: ${position.latitude}, ${position.longitude}");
          } catch (e) {
             print("Network error sending location: $e");
          }
        }
      } catch (e) {
        print("Error in background tracking loop: $e");
      }
    });
  }
}
