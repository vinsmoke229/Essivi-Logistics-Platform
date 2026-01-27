import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ProfileService {
  final String _baseUrl = ApiConstants.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, String>> _getMultipartHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Authorization': 'Bearer $token',
    };
  }

  // Mettre à jour la photo de profil
  Future<bool> updateProfilePhoto(File imageFile) async {
    try {
      final headers = await _getMultipartHeaders();
      
      // Créer une requête multipart
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/agents/profile/photo'),
      );
      
      // Ajouter les headers
      request.headers.addAll(headers);
      
      // Ajouter l'image
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'profile_photo',
        imageBytes,
        filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      request.files.add(multipartFile);
      
      // Envoyer la requête
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);
      
      if (response.statusCode == 200) {
        // Sauvegarder l'URL de la photo localement
        final prefs = await SharedPreferences.getInstance();
        if (responseData['photo_url'] != null) {
          await prefs.setString('profile_photo_url', responseData['photo_url']);
        }
        return true;
      } else {
        print('Erreur upload photo: ${response.statusCode} - $responseData');
        return false;
      }
    } catch (e) {
      print('Exception upload photo: $e');
      return false;
    }
  }

  // Récupérer les informations du profil
  Future<Map<String, dynamic>?> getProfileInfo() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/agents/profile'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Erreur récupération profil: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception récupération profil: $e');
      return null;
    }
  }

  // Mettre à jour les informations du profil
  Future<bool> updateProfileInfo({
    String? name,
    String? phone,
    String? email,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      });
      
      final response = await http.put(
        Uri.parse('$_baseUrl/agents/profile'),
        headers: headers,
        body: body,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Exception mise à jour profil: $e');
      return false;
    }
  }

  // Récupérer l'URL de la photo de profil sauvegardée localement
  Future<String?> getLocalProfilePhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile_photo_url');
  }

  // Sauvegarder localement le chemin de la photo
  Future<void> saveLocalProfilePhotoPath(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_profile_photo_path', filePath);
  }

  // Récupérer le chemin local de la photo
  Future<String?> getLocalProfilePhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('local_profile_photo_path');
  }

  // Supprimer la photo de profil locale
  Future<void> clearLocalProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_photo_url');
    await prefs.remove('local_profile_photo_path');
  }
}
