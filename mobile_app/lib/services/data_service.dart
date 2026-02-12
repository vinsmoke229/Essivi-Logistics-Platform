import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import './database_helper.dart';

class DataService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Helper pour les headers avec Token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  
  // --- RÉCUPÉRER LES MISSIONS DE L'AGENT ---
  Future<List<dynamic>> getMyMissions() async {
    // Petit délai pour laisser l'UI respirer au démarrage
    await Future.delayed(const Duration(milliseconds: 500));
    final url = Uri.parse('${ApiConstants.baseUrl}/orders/my-missions');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Erreur serveur (${response.statusCode})');
    } on TimeoutException {
      throw Exception('Serveur injoignable, le réseau est lent.');
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  // 1. Récupérer la liste des Clients
  Future<List<dynamic>> getClients() async {
    // Petit délai pour laisser l'UI respirer
    await Future.delayed(const Duration(milliseconds: 500));
    
    // D'abord renvoyer le cache pour affichage instantané, puis rafraîchir
    final url = Uri.parse('${ApiConstants.baseUrl}/clients/');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur chargement clients');
      }
    } on TimeoutException {
      throw Exception('Serveur injoignable, le réseau est lent.');
    } catch (e) {
      print("Erreur API Clients: $e");
      rethrow;
    }
  }

  // 2. Envoyer une Livraison (avec support Offline & Produits Dynamiques)
  Future<bool> sendDelivery({
    required int clientId,
    List<Map<String, dynamic>> items = const [],
    required double amount,
    required double gpsLat,
    required double gpsLng,
    Uint8List? photoBytes,
    Uint8List? signatureBytes,
    String? photoUrl,
    String? signatureUrl,
    bool isSyncing = false,
  }) async {
    String? finalPhoto = photoUrl;
    if (photoBytes != null) {
      finalPhoto = 'data:image/jpeg;base64,${base64Encode(photoBytes)}';
    }

    String? finalSignature = signatureUrl;
    if (signatureBytes != null) {
      finalSignature = 'data:image/png;base64,${base64Encode(signatureBytes)}';
    }

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (isSyncing) return false; 
        print("SAD - Pas d'internet, sauvegarde locale...");
        await _saveLocally(clientId, items, amount, gpsLat, gpsLng, finalPhoto, finalSignature);
        return true; 
      }

      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deliveriesEndpoint}/');
      final headers = await _getHeaders();
      
      final body = jsonEncode({
        "client_id": clientId,
        "items": items,
        "total_amount": amount,
        "gps_lat": gpsLat,
        "gps_lng": gpsLng,
        "photo_url": finalPhoto,
        "signature_url": finalSignature
      });

      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));
      if (response.statusCode == 201) {
        return true;
      } else {
        print("Erreur API (${response.statusCode}): ${response.body}");
        return false;
      }
    } on TimeoutException {
      if (!isSyncing) await _saveLocally(clientId, items, amount, gpsLat, gpsLng, finalPhoto, finalSignature);
      return !isSyncing;
    } catch (e) {
      if (isSyncing) return false;
      print("Erreur réseau, sauvegarde locale: $e");
      await _saveLocally(clientId, items, amount, gpsLat, gpsLng, finalPhoto, finalSignature);
      return true;
    }
  }

  Future<void> _saveLocally(int clientId, List<Map<String, dynamic>> items, double amount, double gpsLat, double gpsLng, String? photo, String? signature) async {
    await _dbHelper.insertDelivery({
      'client_id': clientId,
      'items_json': jsonEncode(items), 
      'amount': amount,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'photo_url': photo,
      'signature_url': signature,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0
    });
  }

  // Synchronisation des données locales vers le serveur
  Future<void> syncOfflineDeliveries() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    final unsynced = await _dbHelper.getUnsyncedDeliveries();
    if (unsynced.isEmpty) return;

    for (var delivery in unsynced) {
      try {
        List<Map<String, dynamic>> items = [];
        if (delivery['items_json'] != null) {
             items = List<Map<String, dynamic>>.from(jsonDecode(delivery['items_json']));
        }

        bool success = await sendDelivery(
          clientId: int.tryParse(delivery['client_id'].toString()) ?? 0,
          items: items,
          amount: double.tryParse(delivery['amount'].toString()) ?? 0.0,
          gpsLat: double.tryParse(delivery['gps_lat'].toString()) ?? 0.0,
          gpsLng: double.tryParse(delivery['gps_lng'].toString()) ?? 0.0,
          photoUrl: delivery['photo_url']?.toString(),
          signatureUrl: delivery['signature_url']?.toString(),
          isSyncing: true, 
        );

        if (success) {
          await _dbHelper.markAsSynced(int.parse(delivery['id'].toString()));
        }
      } catch (e) {
        print("Sync error: $e");
      }
    }
    await _dbHelper.deleteSyncedDeliveries();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedDeliveries() async {
    return await _dbHelper.getUnsyncedDeliveries();
  }

  // CLIENT API METHODS
  Future<List<dynamic>> getClientOrders() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/client/orders');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      throw Exception('Serveur injoignable, vérifiez votre connexion.');
    }
  }

  Future<List<dynamic>> getClientDeliveries() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/client/deliveries');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      throw Exception('Serveur injoignable, vérifiez votre connexion.');
    }
  }

  Future<List<dynamic>> getClientInvoices() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/client/invoices');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      throw Exception('Serveur injoignable, vérifiez votre connexion.');
    }
  }

  Future<bool> createClient({
    required String name,
    required String responsible,
    required String phone,
    required String address,
    required double lat,
    required double lng,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clients/');
    final headers = await _getHeaders();
    final body = jsonEncode({
      "name": name,
      "responsible_name": responsible,
      "phone": phone,
      "address": address,
      "gps_lat": lat,
      "gps_lng": lng
    });

    try {
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getMyDeliveries() async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deliveriesEndpoint}/');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      throw Exception('Serveur injoignable, vérifiez votre connexion.');
    }
  }

  Future<int?> startTour(double lat, double lng, {List<Map<String, dynamic>> items = const []}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/tours/start');
    final headers = await _getHeaders();
    final body = jsonEncode({
      "lat": lat, 
      "lng": lng,
      "items": items // ✅ Envoi de la liste des items
    });

    try {
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));
      // ✅ 200 = Success (Recovery), 201 = Success (Created), 400 = Error but maybe handled
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['tour_id'];
      }
    } catch (e) {
      print("Tour start error: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> endTour(double lat, double lng) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/tours/end');
    final headers = await _getHeaders();
    final body = jsonEncode({"lat": lat, "lng": lng});

    try {
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Tour end error: $e");
    }
    return null;
  }

  Future<List<dynamic>> getProducts() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/products/');
    final headers = await _getHeaders();
    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {}
    return [];
  }

  Future<bool> sendOrder({
    List<Map<String, dynamic>> items = const [],
    String? preferredTime,
    String? instructions,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/orders/');
    final headers = await _getHeaders();
    final body = jsonEncode({
      "items": items,
      "preferred_time": preferredTime,
      "instructions": instructions
    });

    try {
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 30));
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getOrders() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/orders/');
    final headers = await _getHeaders();
    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {}
    return [];
  }

  Future<void> updateLocation(double lat, double lng) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/agents/location');
    final headers = await _getHeaders();
    try {
      await http.post(
        url,
        headers: headers,
        body: jsonEncode({'lat': lat, 'lng': lng}),
      ).timeout(const Duration(seconds: 5)); // Shorter for location
    } catch (e) {}
  }

  Future<bool> postEvaluation(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/evaluations/');
    final headers = await _getHeaders();
    try {
      final response = await http.post(url, headers: headers, body: jsonEncode(data)).timeout(const Duration(seconds: 30));
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}