import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  final String accessToken;

  UserModel({
    required String id,
    required String name,
    required String role,
    String? identifier,
    required this.accessToken,
  }) : super(id: id, name: name, role: role, identifier: identifier);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    print("🔍 DEBUG - UserModel.fromJson appelé avec: $json");
    final accessToken = json['access_token'] ?? json['token'] ?? '';
    print("🔍 DEBUG - Token extrait: ${accessToken.isNotEmpty ? 'OUI' : 'NON'}");
    
    return UserModel(
      id: json['identity'] ?? json['id']?.toString() ?? json['sub']?.toString() ?? '0',  
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      identifier: json['identifier'],
      accessToken: accessToken,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'identifier': identifier,
      'access_token': accessToken,
    };
  }
}
