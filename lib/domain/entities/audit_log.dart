import 'dart:convert';

/// Registro de auditoría — quién hizo qué y cuándo
class AuditLog {
  final String id;
  final String? userId;
  final String? userEmail;
  final String? userDisplayName;
  final String? userRole;
  final String? employeeName;
  final String? employeePosition;
  final String? employeeDepartment;
  final String action;
  final String module;
  final String? recordId;
  final String description;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  AuditLog({
    required this.id,
    this.userId,
    this.userEmail,
    this.userDisplayName,
    this.userRole,
    this.employeeName,
    this.employeePosition,
    this.employeeDepartment,
    required this.action,
    required this.module,
    this.recordId,
    required this.description,
    this.details,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      userDisplayName: json['user_display_name'] as String?,
      userRole: json['user_role'] as String?,
      employeeName: json['employee_name'] as String?,
      employeePosition: json['employee_position'] as String?,
      employeeDepartment: json['employee_department'] as String?,
      action: json['action'] as String,
      module: json['module'] as String,
      recordId: json['record_id'] as String?,
      description: json['description'] as String? ?? '',
      details: json['details'] is String
          ? jsonDecode(json['details'] as String) as Map<String, dynamic>?
          : json['details'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Icono según la acción
  String get actionIcon {
    switch (action) {
      case 'create':
        return '➕';
      case 'update':
        return '✏️';
      case 'delete':
        return '🗑️';
      case 'approve':
        return '✅';
      case 'cancel':
        return '❌';
      case 'print':
        return '🖨️';
      case 'login':
        return '🔑';
      case 'logout':
        return '🚪';
      default:
        return '📋';
    }
  }

  /// Etiqueta legible del módulo
  String get moduleLabel {
    switch (module) {
      case 'invoices':
        return 'Ventas';
      case 'expenses':
        return 'Compras';
      case 'materials':
        return 'Materiales';
      case 'inventory':
        return 'Inventario';
      case 'cash':
        return 'Caja';
      case 'production':
        return 'Producción';
      case 'customers':
        return 'Clientes';
      case 'employees':
        return 'Empleados';
      case 'quotations':
        return 'Cotizaciones';
      case 'assets':
        return 'Activos';
      case 'accounting':
        return 'Contabilidad';
      case 'auth':
        return 'Autenticación';
      case 'users':
        return 'Usuarios';
      case 'suppliers':
        return 'Proveedores';
      case 'products':
        return 'Productos';
      case 'activities':
        return 'Actividades';
      case 'iva':
        return 'IVA';
      case 'settings':
        return 'Configuración';
      case 'composite_products':
        return 'Prod. Compuestos';
      case 'supplier_materials':
        return 'Prov-Materiales';
      case 'material_categories':
        return 'Cat. Materiales';
      case 'recipes':
        return 'Recetas';
      default:
        return module;
    }
  }

  /// Etiqueta legible de la acción
  String get actionLabel {
    switch (action) {
      case 'create':
        return 'Creó';
      case 'update':
        return 'Editó';
      case 'delete':
        return 'Eliminó';
      case 'approve':
        return 'Aprobó';
      case 'cancel':
        return 'Anuló';
      case 'print':
        return 'Imprimió';
      case 'login':
        return 'Inició sesión';
      case 'logout':
        return 'Cerró sesión';
      default:
        return action;
    }
  }
}
