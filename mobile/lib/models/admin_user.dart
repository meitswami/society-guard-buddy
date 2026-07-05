import '../services/admin_permissions.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.adminId,
    required this.societyId,
    required this.permissions,
  });

  final String id;
  final String name;
  final String adminId;
  final String? societyId;
  final AdminPanelPermissions permissions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'adminId': adminId,
        'societyId': societyId,
        'permissions': permissions.toJson(),
      };

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        name: json['name'] as String,
        adminId: json['adminId'] as String,
        societyId: json['societyId'] as String?,
        permissions: AdminPanelPermissions.fromJson(
          json['permissions'] as Map<String, dynamic>?,
        ),
      );
}
