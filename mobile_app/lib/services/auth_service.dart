import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
   
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.loginEndpoint}');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
         
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['access_token']);
        await prefs.setString('role', data['role']); 
        await prefs.setString('name', data['name'] ?? 'Utilisateur');

        print("💾 PERSISTENCE OK: ${data['role']} pour ${data['name']}");
        
        return {'success': true, 'data': data};
      } else {
         
        final errorData = jsonDecode(response.body);
        return {'success': false, 'message': errorData['msg'] ?? 'Erreur inconnue'};
      }
    } catch (e) {
       
      return {'success': false, 'message': 'Erreur de connexion : $e'};
    }
  }

   
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token');
  }

   
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}