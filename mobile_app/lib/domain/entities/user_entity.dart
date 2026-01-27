class UserEntity {
  final String id;
  final String name;
  final String role; // agent, client, admin
  final String? identifier; // phone or matricule

  UserEntity({
    required this.id,
    required this.name,
    required this.role,
    this.identifier,
  });
}
