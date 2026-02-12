class UserEntity {
  final String id;
  final String name;
  final String role;  
  final String? identifier;  

  UserEntity({
    required this.id,
    required this.name,
    required this.role,
    this.identifier,
  });
}
