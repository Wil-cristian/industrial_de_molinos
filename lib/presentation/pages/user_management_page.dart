import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/employee.dart';
import '../../data/datasources/user_profile_datasource.dart';
import '../../data/datasources/employees_datasource.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../core/utils/logger.dart';

/// Pantalla de gestión de usuarios (solo admin)
class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  List<UserProfile> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    final accounts = await UserProfileDatasource.listUserAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _isLoading = false;
    });
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await SupabaseDataSource.signOut();
        AppLogger.success('Sesión cerrada');
      } catch (e) {
        AppLogger.error('Error cerrando sesión', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAccounts),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Cerrar sesión'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAccountDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Crear cuenta'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text('No hay cuentas registradas', style: tt.bodyLarge),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.base),
              itemCount: _accounts.length,
              itemBuilder: (context, index) {
                final account = _accounts[index];
                return _AccountCard(
                  account: account,
                  onToggle: () => _toggleAccount(account),
                  onViewCredentials: () => _viewCredentials(account),
                  onResetPassword: () => _resetPassword(account),
                  onChangeRole: () => _changeRole(account),
                );
              },
            ),
    );
  }

  Future<void> _changeRole(UserProfile account) async {
    final newRole = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = account.role;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar rol'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    account.displayName ?? account.email ?? 'Sin nombre',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...['employee', 'tecnico', 'dueno', 'admin'].map((role) {
                    final label = switch (role) {
                      'admin' => 'Administrador',
                      'dueno' => 'Dueño',
                      'tecnico' => 'Técnico',
                      _ => 'Empleado',
                    };
                    final icon = switch (role) {
                      'admin' => Icons.admin_panel_settings,
                      'dueno' => Icons.business,
                      'tecnico' => Icons.engineering,
                      _ => Icons.person,
                    };
                    return RadioListTile<String>(
                      value: role,
                      groupValue: selected,
                      title: Row(
                        children: [
                          Icon(icon, size: 20),
                          const SizedBox(width: 8),
                          Text(label),
                        ],
                      ),
                      onChanged: (v) => setDialogState(() => selected = v!),
                    );
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selected == account.role
                      ? null
                      : () => Navigator.pop(ctx, selected),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (newRole == null || newRole == account.role) return;

    final result = await UserProfileDatasource.updateUserRole(
      account.id,
      newRole,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rol cambiado a ${result['new_role']}'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadAccounts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al cambiar rol'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _toggleAccount(UserProfile account) async {
    final newActive = !account.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newActive ? 'Activar cuenta' : 'Desactivar cuenta'),
        content: Text(
          newActive
              ? '¿Activar la cuenta de ${account.displayName}?'
              : '¿Desactivar la cuenta de ${account.displayName}? No podrá iniciar sesión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newActive ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final success = await UserProfileDatasource.toggleUserAccount(
      account.id,
      newActive,
    );
    if (success) {
      _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta ${newActive ? "activada" : "desactivada"}'),
          ),
        );
      }
    }
  }

  Future<void> _viewCredentials(UserProfile account) async {
    final result = await UserProfileDatasource.getEmployeeCredential(
      account.id,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      _showCredentialDialog(
        context,
        name: result['display_name'] ?? account.displayName ?? '',
        email: result['email'] ?? '',
        password: result['password'],
        message: result['message'],
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al obtener credenciales'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _resetPassword(UserProfile account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetear contraseña'),
        content: Text(
          '¿Generar una nueva contraseña para ${account.displayName}?\nLa contraseña anterior dejará de funcionar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final result = await UserProfileDatasource.resetEmployeePassword(
      account.id,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      _showCredentialDialog(
        context,
        name: result['display_name'] ?? account.displayName ?? '',
        email: result['email'] ?? '',
        password: result['password'],
        title: 'Nueva contraseña generada',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al resetear'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showCredentialDialog(
    BuildContext context, {
    required String name,
    required String email,
    String? password,
    String? message,
    String title = 'Credenciales',
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.key, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.base),
                _CredentialRow(label: 'Correo', value: email),
                const SizedBox(height: AppSpacing.sm),
                if (password != null)
                  _CredentialRow(label: 'Contraseña', value: password)
                else if (message != null)
                  Text(
                    message,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: AppSpacing.base),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: cs.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Guarda estos datos. El empleado los necesita para iniciar sesión.',
                          style: tt.labelSmall?.copyWith(color: cs.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateAccountDialog(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _CreateAccountDialog(
        existingEmployeeIds: _accounts
            .map((a) => a.employeeId)
            .where((e) => e != null)
            .cast<String>()
            .toSet(),
      ),
    );
    if (result != null && result['success'] == true) {
      _loadAccounts();
      if (mounted) {
        _showCredentialDialog(
          context,
          name: result['employee_name'] ?? '',
          email: result['email'] ?? '',
          password: result['password'],
          title: 'Cuenta creada',
        );
      }
    }
  }
}

// --- Fila de credencial con botón copiar ---
class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copiar',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copiado'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- Tarjeta de cuenta ---
class _AccountCard extends StatelessWidget {
  final UserProfile account;
  final VoidCallback onToggle;
  final VoidCallback onViewCredentials;
  final VoidCallback onResetPassword;
  final VoidCallback onChangeRole;

  const _AccountCard({
    required this.account,
    required this.onToggle,
    required this.onViewCredentials,
    required this.onResetPassword,
    required this.onChangeRole,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isAdmin = account.isAdmin;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es_CO');

    // Color y label por rol
    Color roleBgColor;
    Color roleTextColor;
    String roleLabel;
    IconData roleIcon;
    switch (account.role) {
      case 'admin':
        roleBgColor = cs.primary;
        roleTextColor = cs.primary;
        roleLabel = 'Admin';
        roleIcon = Icons.admin_panel_settings;
      case 'dueno':
        roleBgColor = Colors.purple;
        roleTextColor = Colors.purple;
        roleLabel = 'Dueño';
        roleIcon = Icons.business;
      case 'tecnico':
        roleBgColor = Colors.amber.shade800;
        roleTextColor = Colors.amber.shade800;
        roleLabel = 'Técnico';
        roleIcon = Icons.engineering;
      default:
        roleBgColor = cs.tertiary;
        roleTextColor = cs.tertiary;
        roleLabel = 'Empleado';
        roleIcon = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleBgColor.withOpacity(0.15),
          child: Icon(roleIcon, color: roleBgColor),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                account.displayName ?? account.email ?? 'Sin nombre',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleTextColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleLabel,
                style: tt.labelSmall?.copyWith(
                  color: roleTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!account.isActive) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Inactivo',
                  style: tt.labelSmall?.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (account.email != null)
              Text(account.email!, style: tt.bodySmall),
            if (account.employeeName != null)
              Text(
                'Empleado: ${account.employeeName} (${account.employeePosition ?? ""})',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            if (account.lastSignInAt != null)
              Text(
                'Último acceso: ${dateFormat.format(account.lastSignInAt!)}',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
        trailing: !isAdmin
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  switch (action) {
                    case 'credentials':
                      onViewCredentials();
                    case 'reset':
                      onResetPassword();
                    case 'toggle':
                      onToggle();
                    case 'change_role':
                      onChangeRole();
                  }
                },
                itemBuilder: (ctx) => [
                  if (account.isTecnico || account.isDueno)
                    const PopupMenuItem(
                      value: 'change_role',
                      child: ListTile(
                        leading: Icon(Icons.swap_horiz, color: Colors.purple),
                        title: Text('Cambiar rol'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (account.hasStoredCredential)
                    const PopupMenuItem(
                      value: 'credentials',
                      child: ListTile(
                        leading: Icon(Icons.key),
                        title: Text('Ver credenciales'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: ListTile(
                      leading: Icon(Icons.lock_reset),
                      title: Text('Resetear contraseña'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(
                        account.isActive ? Icons.block : Icons.check_circle,
                        color: account.isActive
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                      title: Text(account.isActive ? 'Desactivar' : 'Activar'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}

/// Dialog simplificado: solo seleccionar empleado, credenciales auto-generadas
class _CreateAccountDialog extends ConsumerStatefulWidget {
  final Set<String> existingEmployeeIds;
  const _CreateAccountDialog({required this.existingEmployeeIds});

  @override
  ConsumerState<_CreateAccountDialog> createState() =>
      _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<_CreateAccountDialog> {
  List<Employee> _employees = [];
  Employee? _selectedEmployee;
  String _selectedRole = 'employee';
  bool _isLoading = false;
  bool _isLoadingEmployees = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final employees = await EmployeesDatasource.getEmployees();
    if (!mounted) return;
    setState(() {
      // Filtrar empleados que ya tienen cuenta
      _employees = employees
          .where((e) => !widget.existingEmployeeIds.contains(e.id))
          .toList();
      _isLoadingEmployees = false;
    });
  }

  Future<void> _submit() async {
    if (_selectedEmployee == null) return;
    setState(() => _isLoading = true);

    final result = await UserProfileDatasource.createEmployeeAccount(
      employeeId: _selectedEmployee!.id,
      role: _selectedRole,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pop(context, result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al crear cuenta'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Crear cuenta de empleado'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: cs.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'El correo y la contraseña se generan automáticamente de forma segura.',
                      style: tt.bodySmall?.copyWith(color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _isLoadingEmployees
                ? const LinearProgressIndicator()
                : _employees.isEmpty
                ? Text(
                    'Todos los empleados ya tienen cuenta.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  )
                : DropdownButtonFormField<Employee>(
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar empleado',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    isExpanded: true,
                    items: _employees.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(
                          '${e.fullName} — ${e.position}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (emp) => setState(() => _selectedEmployee = emp),
                    validator: (v) =>
                        v == null ? 'Selecciona un empleado' : null,
                  ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Rol',
                prefixIcon: Icon(Icons.security),
              ),
              value: _selectedRole,
              items: const [
                DropdownMenuItem(value: 'employee', child: Text('Empleado')),
                DropdownMenuItem(value: 'tecnico', child: Text('Técnico')),
                DropdownMenuItem(value: 'dueno', child: Text('Dueño')),
                DropdownMenuItem(value: 'admin', child: Text('Administrador')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedRole = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (_isLoading || _selectedEmployee == null) ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add),
          label: const Text('Crear cuenta'),
        ),
      ],
    );
  }
}
