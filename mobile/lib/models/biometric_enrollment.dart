/// Device-local biometric quick-login enrollment (secure storage + local_auth).
/// Web uses WebAuthn in `biometric_credentials`; native apps use this model instead.
class BiometricEnrollment {
  const BiometricEnrollment({
    required this.id,
    required this.role,
    required this.userDbId,
    required this.displayName,
    required this.societyId,
    required this.societyName,
    this.flatId,
    this.flatNumber,
    this.guardId,
    required this.createdAt,
  });

  final String id;
  final String role;
  final String userDbId;
  final String displayName;
  final String societyId;
  final String societyName;
  final String? flatId;
  final String? flatNumber;
  final String? guardId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'userDbId': userDbId,
        'displayName': displayName,
        'societyId': societyId,
        'societyName': societyName,
        'flatId': flatId,
        'flatNumber': flatNumber,
        'guardId': guardId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BiometricEnrollment.fromJson(Map<String, dynamic> json) =>
      BiometricEnrollment(
        id: json['id'] as String,
        role: json['role'] as String,
        userDbId: json['userDbId'] as String,
        displayName: json['displayName'] as String,
        societyId: json['societyId'] as String,
        societyName: json['societyName'] as String,
        flatId: json['flatId'] as String?,
        flatNumber: json['flatNumber'] as String?,
        guardId: json['guardId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  bool matchesLogin({
    required String societyId,
    required String role,
    String? flatId,
  }) {
    if (this.societyId != societyId || this.role != role) return false;
    if (role == 'resident') return flatId != null && this.flatId == flatId;
    return true;
  }
}
