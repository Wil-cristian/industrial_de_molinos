import '../../core/utils/colombia_time.dart';
/// Perfil de usuario con rol y vínculo a empleado
class UserProfile {
  final String id;
  final String userId;
  final String? employeeId;
  final String role; // 'admin' | 'tecnico' | 'dueno' | 'employee'
  final String? displayName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Campos extras que vienen del RPC
  final String? employeeName;
  final String? employeePosition;
  final String? employeeDepartment;

  // Campos extras que vienen de list_user_accounts
  final String? email;
  final DateTime? lastSignInAt;
  final bool hasStoredCredential;

  UserProfile({
    required this.id,
    required this.userId,
    this.employeeId,
    required this.role,
    this.displayName,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
    this.employeeName,
    this.employeePosition,
    this.employeeDepartment,
    this.email,
    this.lastSignInAt,
    this.hasStoredCredential = false,
  }) : createdAt = createdAt ?? ColombiaTime.now();

  bool get isAdmin => role == 'admin';
  bool get isTecnico => role == 'tecnico';
  bool get isDueno => role == 'dueno';
  bool get isEmployee => role == 'employee';
  bool get hasFullAccess => isAdmin || isDueno;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      employeeId: json['employee_id'] as String?,
      role: json['role'] as String? ?? 'admin',
      displayName: json['display_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : ColombiaTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      employeeName: json['employee_name'] as String?,
      employeePosition: json['employee_position'] as String?,
      employeeDepartment: json['employee_department'] as String?,
      email: json['email'] as String?,
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.parse(json['last_sign_in_at'] as String)
          : null,
      hasStoredCredential: json['has_credential'] as bool? ?? false,
    );
  }
}
