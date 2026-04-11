import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/permissions/screen_permissions.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/datasources/user_profile_datasource.dart';
import '../../domain/entities/user_profile.dart';
import '../../core/utils/logger.dart';

/// Widget para administrar permisos de pantalla por usuario.
/// Solo visible para Wil (admin con acceso a auditoría).
class ScreenPermissionsManager extends ConsumerStatefulWidget {
  const ScreenPermissionsManager({super.key});

  @override
  ConsumerState<ScreenPermissionsManager> createState() =>
      _ScreenPermissionsManagerState();
}

class _ScreenPermissionsManagerState
    extends ConsumerState<ScreenPermissionsManager> {
  List<UserProfile> _users = [];
  // userId → {screenKey → isAllowed}
  Map<String, Map<String, bool>> _userOverrides = {};
  // Track changes: userId → {screenKey → isAllowed}
  Map<String, Map<String, bool>> _pendingChanges = {};
  bool _isLoading = true;
  String? _error;
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await UserProfileDatasource.listUserAccounts();
      // Cargar overrides de todos los usuarios (admin access via RLS)
      final client = SupabaseDataSource.client;
      final rows = await client
          .from('screen_permissions')
          .select('user_id, screen_key, is_allowed');

      final overrides = <String, Map<String, bool>>{};
      for (final row in rows) {
        final uid = row['user_id'] as String;
        final key = row['screen_key'] as String;
        final allowed = row['is_allowed'] as bool;
        overrides.putIfAbsent(uid, () => {});
        overrides[uid]![key] = allowed;
      }

      setState(() {
        _users = users.where((u) => u.isActive).toList()
          ..sort(
            (a, b) => (a.displayName ?? a.email ?? '').compareTo(
              b.displayName ?? b.email ?? '',
            ),
          );
        _userOverrides = overrides;
        _pendingChanges = {};
        _isLoading = false;
        if (_selectedUserId == null && _users.isNotEmpty) {
          _selectedUserId = _users.first.userId;
        }
      });
    } catch (e) {
      AppLogger.error('Error cargando permisos', e);
      setState(() {
        _error = 'Error cargando datos: $e';
        _isLoading = false;
      });
    }
  }

  /// Calcula si un screen está habilitado para un usuario
  bool _isScreenEnabled(String userId, String screenKey) {
    // Primero revisar cambios pendientes
    final pending = _pendingChanges[userId]?[screenKey];
    if (pending != null) return pending;

    // Luego overrides de BD
    final dbOverride = _userOverrides[userId]?[screenKey];
    if (dbOverride != null) return dbOverride;

    // Luego default del rol
    final user = _users.firstWhere(
      (u) => u.userId == userId,
      orElse: () => _users.first,
    );
    final roleDefaults = AppScreen.defaultPermissions[user.role] ?? <String>{};
    return roleDefaults.contains(screenKey);
  }

  /// Marca un cambio pendiente
  void _togglePermission(String userId, String screenKey) {
    final current = _isScreenEnabled(userId, screenKey);
    setState(() {
      _pendingChanges.putIfAbsent(userId, () => {});
      _pendingChanges[userId]![screenKey] = !current;
    });
  }

  bool get _hasPendingChanges =>
      _pendingChanges.values.any((m) => m.isNotEmpty);

  /// Guarda todos los cambios pendientes en BD
  Future<void> _saveChanges() async {
    if (!_hasPendingChanges) return;

    setState(() => _isLoading = true);
    try {
      final client = SupabaseDataSource.client;

      for (final entry in _pendingChanges.entries) {
        final userId = entry.key;
        for (final perm in entry.value.entries) {
          final screenKey = perm.key;
          final isAllowed = perm.value;

          // Revisar si es igual al default del rol (entonces borrar el override)
          final user = _users.firstWhere(
            (u) => u.userId == userId,
            orElse: () => _users.first,
          );
          final roleDefaults =
              AppScreen.defaultPermissions[user.role] ?? <String>{};
          final isDefault = roleDefaults.contains(screenKey) == isAllowed;

          if (isDefault) {
            // Borrar override si existe
            await client
                .from('screen_permissions')
                .delete()
                .eq('user_id', userId)
                .eq('screen_key', screenKey);
          } else {
            // Upsert override
            await client.from('screen_permissions').upsert({
              'user_id': userId,
              'screen_key': screenKey,
              'is_allowed': isAllowed,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'user_id,screen_key');
          }
        }
      }

      // Recargar permisos del usuario actual
      ref.read(screenPermissionsProvider.notifier).reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permisos actualizados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      AppLogger.error('Error guardando permisos', e);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error guardando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(child: Text('No hay usuarios registrados'));
    }

    final selectedUser = _users.firstWhere(
      (u) => u.userId == _selectedUserId,
      orElse: () => _users.first,
    );

    return Column(
      children: [
        // Barra superior con selector de usuario y botón guardar
        _buildToolbar(context, selectedUser),
        const SizedBox(height: 8),
        // Grilla de permisos
        Expanded(child: _buildPermissionGrid(context, selectedUser)),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, UserProfile selectedUser) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withAlpha(80)),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Selector de usuario
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedUserId,
                underline: const SizedBox.shrink(),
                items: _users.map((u) {
                  final label = u.displayName ?? u.email ?? u.userId;
                  final roleBadge = _roleBadge(u.role);
                  return DropdownMenuItem(
                    value: u.userId,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: theme.textTheme.bodyMedium),
                        const SizedBox(width: 8),
                        roleBadge,
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedUserId = v),
              ),
            ],
          ),
          // Info del rol y botón guardar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rol: ${selectedUser.role.toUpperCase()}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _hasPendingChanges ? _saveChanges : null,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Guardar'),
              ),
              const SizedBox(width: 8),
              if (_hasPendingChanges)
                TextButton.icon(
                  onPressed: () => setState(() => _pendingChanges.clear()),
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('Deshacer'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionGrid(BuildContext context, UserProfile selectedUser) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userId = selectedUser.userId;
    final roleDefaults =
        AppScreen.defaultPermissions[selectedUser.role] ?? <String>{};

    // Agrupar pantallas por categoría
    final categories = <String, List<MapEntry<String, String>>>{
      'Operaciones': [
        MapEntry(AppScreen.dailyCash, 'Caja Diaria'),
        MapEntry(AppScreen.expenses, 'Compras'),
        MapEntry(AppScreen.compositeProducts, 'Productos'),
        MapEntry(AppScreen.productionOrders, 'Producción'),
        MapEntry(AppScreen.materials, 'Materiales'),
        MapEntry(AppScreen.shipments, 'Remisiones'),
      ],
      'Ventas': [
        MapEntry(AppScreen.invoices, 'Ventas/Facturas'),
        MapEntry(AppScreen.customers, 'Clientes'),
        MapEntry(AppScreen.quotations, 'Cotizaciones'),
      ],
      'Finanzas': [
        MapEntry(AppScreen.reports, 'Reportes'),
        MapEntry(AppScreen.accounting, 'Contabilidad'),
        MapEntry(AppScreen.ivaControl, 'Control IVA'),
      ],
      'Sistema': [
        MapEntry(AppScreen.dashboard, 'Dashboard'),
        MapEntry(AppScreen.calendar, 'Calendario'),
        MapEntry(AppScreen.employees, 'Empleados'),
        MapEntry(AppScreen.assets, 'Activos'),
        MapEntry(AppScreen.userManagement, 'Usuarios'),
        MapEntry(AppScreen.auditPanel, 'Auditoría'),
      ],
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Leyenda
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _legendItem(cs, Icons.check_circle, Colors.green, 'Habilitado'),
            _legendItem(cs, Icons.remove_circle, Colors.red, 'Deshabilitado'),
            _legendItem(
              cs,
              Icons.circle_outlined,
              Colors.grey,
              'Por defecto del rol',
            ),
            _legendItem(
              cs,
              Icons.edit,
              Colors.orange,
              'Override (personalizado)',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Categorías
        ...categories.entries.map((cat) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat.key,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const Divider(),
                  ...cat.value.map((screen) {
                    final screenKey = screen.key;
                    final label = screen.value;
                    final isEnabled = _isScreenEnabled(userId, screenKey);
                    final isDefaultValue = roleDefaults.contains(screenKey);
                    final hasDbOverride =
                        _userOverrides[userId]?.containsKey(screenKey) == true;
                    final hasPending =
                        _pendingChanges[userId]?.containsKey(screenKey) == true;
                    final isCustomized = hasDbOverride || hasPending;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isEnabled
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_rounded,
                        color: isEnabled ? Colors.green : Colors.red.shade300,
                        size: 24,
                      ),
                      title: Text(label),
                      subtitle: Text(
                        isCustomized
                            ? 'Personalizado'
                            : isDefaultValue
                            ? 'Por defecto (${selectedUser.role})'
                            : 'Sin acceso por rol',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isCustomized
                              ? Colors.orange.shade700
                              : cs.onSurfaceVariant,
                          fontStyle: isCustomized
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      trailing: Switch(
                        value: isEnabled,
                        onChanged: (v) => _togglePermission(userId, screenKey),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _legendItem(ColorScheme cs, IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _roleBadge(String role) {
    final colors = {
      'admin': Colors.blue,
      'dueno': Colors.purple,
      'tecnico': Colors.amber.shade800,
      'employee': Colors.teal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (colors[role] ?? Colors.grey).withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (colors[role] ?? Colors.grey).withAlpha(100)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: colors[role] ?? Colors.grey,
        ),
      ),
    );
  }
}
