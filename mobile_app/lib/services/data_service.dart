import 'dart:convert';
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
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // 1. Récupérer la liste des Clients
  Future<List<dynamic>> getClients() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clients/');
    final headers = await _getHeaders();

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        // Optionnel: On pourrait aussi cacher les clients en local, 
        // mais pour l'instant on se concentre sur l'envoi de livraisons offline.
        return [];
      }

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur chargement clients');
      }
    } catch (e) {
      print("Erreur API Clients: $e");
      return [];
    }
  }

  // 2. Envoyer une Livraison (avec support Offline)
  Future<bool> sendDelivery({
    required int clientId,
    required int qtyVitale,
    required int qtyVoltic,
    required double amount,
    required double gpsLat,
    required double gpsLng,
    String? photoUrl,
    String? signatureUrl,
    bool isSyncing = false,
  }) async {
    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      if (isSyncing) return false; // Ne pas re-sauver si on est déjà en train de synchroniser
      
      // MODE OFFLINE : Sauvegarde locale
      print("Pas d'internet, sauvegarde locale...");
      await _dbHelper.insertDelivery({
        'client_id': clientId,
        'quantity_vitale': qtyVitale,
        'quantity_voltic': qtyVoltic,
        'amount': amount,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'photo_url': photoUrl,
        'signature_url': signatureUrl,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0
      });
      return true; // On retourne true pour fermer l'écran
    }

    // MODE ONLINE : Tentative d'envoi immédiat
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deliveriesEndpoint}/');
    final headers = await _getHeaders();
    final body = jsonEncode({
      "client_id": clientId,
      "quantity_vitale": qtyVitale,
      "quantity_voltic": qtyVoltic,
      "total_amount": amount,
      "gps_lat": gpsLat,
      "gps_lng": gpsLng,
      "photo_url": photoUrl,
      "signature_url": signatureUrl
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      if (isSyncing) return false;
      
      // Erreur réseau imprévue -> Sauvegarde locale
      print("Erreur réseau imprévue, sauvegarde locale: $e");
      await _dbHelper.insertDelivery({
        'client_id': clientId,
        'quantity_vitale': qtyVitale,
        'quantity_voltic': qtyVoltic,
        'amount': amount,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'photo_url': photoUrl,
        'signature_url': signatureUrl,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0
      });
      return true;
    }
  }

  // Synchronisation des données locales vers le serveur
  Future<void> syncOfflineDeliveries() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    final unsynced = await _dbHelper.getUnsyncedDeliveries();
    if (unsynced.isEmpty) return;

    print("Début Synchronisation (${unsynced.length} livraisons)...");

    for (var delivery in unsynced) {
      bool success = await sendDelivery(
        clientId: delivery['client_id'],
        qtyVitale: delivery['quantity_vitale'],
        qtyVoltic: delivery['quantity_voltic'],
        amount: delivery['amount'],
        gpsLat: delivery['gps_lat'],
        gpsLng: delivery['gps_lng'],
        photoUrl: delivery['photo_url'],
        signatureUrl: delivery['signature_url'],
        isSyncing: true, // IMPORTANT: Dit à la méthode de ne pas re-sauver en local
      );

      if (success) {
        await _dbHelper.markAsSynced(delivery['id']);
      }
    }
    
    // Nettoyage après sync réussi
    await _dbHelper.deleteSyncedDeliveries();
    print("Synchronisation terminée.");
  }

  // 3. Créer un nouveau client
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
      final response = await http.post(url, headers: headers, body: body);
      return response.statusCode == 201;
    } catch (e) {
      print("Erreur création client: $e");
      return false;
    }
  }

  // 4. Récupérer l'historique des livraisons de l'agent connecté
  Future<List<dynamic>> getMyDeliveries() async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deliveriesEndpoint}/');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print("Erreur historique: $e");
      return [];
    }
  }

  // 5. Démarrer Tournée
  Future<int?> startTour(double lat, double lng) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/tours/start');
    final headers = await _getHeaders();
    final body = jsonEncode({"lat": lat, "lng": lng});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 201 || response.statusCode == 400) {
        final data = jsonDecode(response.body);
        return data['tour_id'];
      }
    } catch (e) {
      print("Erreur Start Tour: $e");
    }
    return null;
  }

  // 6. Terminer Tournée
  Future<Map<String, dynamic>?> endTour(double lat, double lng) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/tours/end');
    final headers = await _getHeaders();
    final body = jsonEncode({"lat": lat, "lng": lng});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Erreur End Tour: $e");
    }
    return null;
  }

  // 7. Passer une Commande (Client)
  Future<bool> sendOrder({
    required int qtyVitale,
    required int qtyVoltic,
    String? preferredTime,
    String? instructions,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/orders/');
    final headers = await _getHeaders();
    final body = jsonEncode({
      "quantity_vitale": qtyVitale,
      "quantity_voltic": qtyVoltic,
      "preferred_time": preferredTime,
      "instructions": instructions
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      return response.statusCode == 201;
    } catch (e) {
      print("Erreur Order API: $e");
      return false;
    }
  }

  // 8. Récupérer les commandes (Client ou Agent)
  Future<List<dynamic>> getOrders() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/orders/');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Erreur Fetch Orders: $e");
    }
    return [];
  }
}