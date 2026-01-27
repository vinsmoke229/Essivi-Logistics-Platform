import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'database_helper.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Lance la synchronisation des données pendientes
  Future<void> syncDeliveries() async {
    // ÉTAPE A : Vérifier la connexion internet
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      print("📴 Pas de connexion internet. Synchronisation reportée.");
      return;
    }

    print("🔄 Démarrage de la synchronisation...");

    // ÉTAPE B : Récupérer les livraisons non synchronisées
    final unsyncedDeliveries = await _dbHelper.getUnsyncedDeliveries();
    
    if (unsyncedDeliveries.isEmpty) {
      print("✅ Aucune donnée à synchroniser.");
      return;
    }

    print("📦 ${unsyncedDeliveries.length} livraison(s) à envoyer au serveur.");

    // Récupérer le token pour l'auth
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print("⛔ Erreur Sync: Utilisateur non connecté (Pas de token).");
      return;
    }

    // ÉTAPE C : Boucler et envoyer chaque livraison
    for (var delivery in unsyncedDeliveries) {
      try {
        await _uploadDelivery(delivery, token);
      } catch (e) {
        print("❌ Erreur sync livraison #${delivery['id']}: $e");
        // On continue avec la prochaine livraison même si celle-ci échoue
      }
    }
  }

  Future<void> _uploadDelivery(Map<String, dynamic> delivery, String token) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/deliveries/');
    
    var request = http.MultipartRequest('POST', uri);
    
    // Headers
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    // Champs Texte
    request.fields['client_id'] = delivery['client_id']?.toString() ?? '';
    // Si pas de client_id (nouveau client), on peut envoyer le nom/tel pour création auto côté backend
    if (delivery['client_id'] == null) {
        request.fields['client_name_temp'] = delivery['client_name'] ?? '';
        request.fields['client_phone_temp'] = delivery['client_phone'] ?? '';
    }
    
    request.fields['quantity_vitale'] = delivery['quantity_vitale'].toString();
    request.fields['quantity_voltic'] = delivery['quantity_voltic'].toString();
    request.fields['amount'] = delivery['amount'].toString();
    request.fields['gps_lat'] = delivery['gps_lat']?.toString() ?? '0.0';
    request.fields['gps_lng'] = delivery['gps_lng']?.toString() ?? '0.0';
    request.fields['created_at'] = delivery['created_at'];

    // Gestion des Fichiers (Photos & Signature)
    if (delivery['photo_url'] != null && delivery['photo_url'].isNotEmpty) {
      final photoFile = File(delivery['photo_url']);
      if (await photoFile.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'photo',
          photoFile.path,
        ));
      }
    }

    if (delivery['signature_url'] != null && delivery['signature_url'].isNotEmpty) {
      final sigFile = File(delivery['signature_url']);
      if (await sigFile.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'signature',
          sigFile.path,
        ));
      }
    }

    // Envoi de la requête
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // ÉTAPE D : Gestion Succès
    if (response.statusCode == 200 || response.statusCode == 201) {
      print("✅ Livraison #${delivery['id']} synchronisée avec succès !");
      
      // Marquer comme synchronisé en base locale
      await _dbHelper.markAsSynced(delivery['id']);
    } 
    // ÉTAPE E : Gestion Échec
    else {
      print("⚠️ Échec upload livraison #${delivery['id']} - Code: ${response.statusCode}");
      print("Réponse: ${response.body}");
      // On ne fait rien, is_synced reste à 0 pour la prochaine tentative
    }
  }
}
