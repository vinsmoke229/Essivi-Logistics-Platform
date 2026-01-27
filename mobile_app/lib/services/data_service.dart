import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
    final token = prefs.getString('auth_token'); // Utiliser la clé directement
    print("🔍 DEBUG - Token récupéré (direct): ${token != null ? 'OUI' : 'NON'}");
    print("🔍 DEBUG - Clé recherchée: auth_token");
    if (token != null) {
      print("🔍 DEBUG - Token (premiers 20 chars): ${token.substring(0, token.length > 20 ? 20 : token.length)}");
    } else {
      // Debug : lister toutes les clés disponibles
      final keys = prefs.getKeys();
      print("🔍 DEBUG - Clés disponibles dans SharedPreferences: $keys");
      for (String key in keys) {
        final value = prefs.getString(key);
        if (value != null && value.length > 20) {
          print("🔍 DEBUG - $key: ${value.substring(0, 20)}...");
        } else {
          print("🔍 DEBUG - $key: $value");
        }
      }
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  
  // --- RÉCUPÉRER LES MISSIONS DE L'AGENT ---
  Future<List<dynamic>> getMyMissions() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/orders/my-missions');
    final headers = await _getHeaders();

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Erreur missions: $e");
    }
    return [];
  }

  // 1. Récupérer la liste des Clients
  Future<List<dynamic>> getClients() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/clients/');
    final headers = await _getHeaders();

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
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

  // 2. Envoyer une Livraison (avec support Offline & Produits Dynamiques)
  Future<bool> sendDelivery({
    required int clientId,
    List<Map<String, dynamic>> items = const [],
    required double amount,
    required double gpsLat,
    required double gpsLng,
    Uint8List? photoBytes,
    Uint8List? signatureBytes,
    String? photoUrl, // Chemin ou Base64 (pour la synchro)
    String? signatureUrl,
    bool isSyncing = false,
  }) async {
    // 1. Préparation des URLs / Base64
    String? finalPhoto = photoUrl;
    if (photoBytes != null) {
      finalPhoto = 'data:image/jpeg;base64,${base64Encode(photoBytes)}';
    }

    String? finalSignature = signatureUrl;
    if (signatureBytes != null) {
      finalSignature = 'data:image/png;base64,${base64Encode(signatureBytes)}';
    }

    final connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      if (isSyncing) return false; 
      
      print("Pas d'internet, sauvegarde locale (Base64)...");
      await _dbHelper.insertDelivery({
        'client_id': clientId,
        'items_json': jsonEncode(items), 
        'amount': amount,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'photo_url': finalPhoto, // On stocke le Base64
        'signature_url': finalSignature,
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0
      });
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

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 201) {
        return true;
      } else {
        print("Erreur API (${response.statusCode}): ${response.body}");
        return false;
      }
    } catch (e) {
      if (isSyncing) return false;
      
      print("Erreur réseau, sauvegarde locale (Base64): $e");
      await _dbHelper.insertDelivery({
        'client_id': clientId,
        'items_json': jsonEncode(items),
        'amount': amount,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'photo_url': finalPhoto,
        'signature_url': finalSignature,
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
      try {
        print("Tentative sync livraison #${delivery['id']}");
        
        // Conversion Legacy DB -> Items
        List<Map<String, dynamic>> items = [];
        if (delivery['items_json'] != null) {
             items = List<Map<String, dynamic>>.from(jsonDecode(delivery['items_json']));
        } else {
             // Fallback pour vieilles données non migrées
             if ((delivery['quantity_vitale'] ?? 0) > 0) items.add({'product_id': 1, 'quantity': delivery['quantity_vitale']});
             if ((delivery['quantity_voltic'] ?? 0) > 0) items.add({'product_id': 2, 'quantity': delivery['quantity_voltic']});
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
          print("✅ Livraison #${delivery['id']} synchronisée.");
        } else {
          print("⚠️ Échec sync livraison #${delivery['id']}");
        }
      } catch (e) {
        print("❌ Erreur critique sync livraison #${delivery['id']}: $e");
        // On continue la boucle pour les autres livraisons
      }
    }
    
    await _dbHelper.deleteSyncedDeliveries();
    print("Synchronisation terminée.");
  }

  // Récupérer les livraisons non synchronisées pour l'indicateur
  Future<List<Map<String, dynamic>>> getUnsyncedDeliveries() async {
    try {
      return await _dbHelper.getUnsyncedDeliveries();
    } catch (e) {
      print("Erreur getUnsyncedDeliveries: $e");
      return [];
    }
  }

  // CLIENT API METHODS
  Future<List<dynamic>> getClientOrders() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/client/orders');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Erreur getClientOrders: $e");
      return [];
    }
  }

  Future<List<dynamic>> getClientDeliveries() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/client/deliveries');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Erreur getClientDeliveries: $e");
      return [];
    }
  }

  Future<List<dynamic>> getClientInvoices() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/client/invoices');
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Erreur getClientInvoices: $e");
      return [];
    }
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

  // 1.1 Récupérer la liste des Produits
  Future<List<dynamic>> getProducts() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/products/');
    final headers = await _getHeaders();
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Erreur fetch products: $e");
    }
    return [];
  }

  // 7. Passer une Commande (Client)
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

  // 9. Mise à jour position temps réel (Suivi Admin)
  Future<void> updateLocation(double lat, double lng) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/agents/location');
    final headers = await _getHeaders();

    try {
      await http.post(
        url,
        headers: headers,
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );
    } catch (e) {
      print("Erreur envoi position: $e");
    }
  }

  // 10. Envoyer une évaluation
  Future<bool> postEvaluation(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/evaluations/');
    final headers = await _getHeaders();
    final response = await http.post(url, headers: headers, body: jsonEncode(data));
    return response.statusCode == 201;
  }
}