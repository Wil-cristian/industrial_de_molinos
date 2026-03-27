import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_profile.dart';
import '../datasources/user_profile_datasource.dart';
import '../../core/utils/logger.dart';
import 'auth_provider.dart';

/// Estado del perfil/rol del usuario actual
class RoleState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const RoleState({this.profile, this.isLoading = false, this.error});

  bool get isAdmin => profile?.isAdmin ?? false;
  bool get isTecnico => profile?.isTecnico ?? false;
  bool get isDueno => profile?.isDueno ?? false;
  bool get isEmployee => profile?.isEmployee ?? false;
  bool get hasFullAccess => profile?.hasFullAccess ?? false;
  bool get hasProfile => profile != null;
  String? get employeeId => profile?.employeeId;
  String get role => profile?.role ?? 'admin';

  RoleState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return RoleState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier que carga el perfil/rol al autenticarse
class RoleNotifier extends Notifier<RoleState> {
  int _profileRequestId = 0;

  @override
  RoleState build() {
    // Escuchar cambios en auth para cargar/limpiar perfil
    final authState = ref.watch(authProvider);
    if (authState.isAuthenticated) {
      // Cargar perfil de forma asincrónica
      _loadProfile();
      return const RoleState(isLoading: true);
    }
    // Invalidar requests pendientes al cerrar sesión
    _profileRequestId++;
    return const RoleState();
  }

  Future<void> _loadProfile() async {
    final requestId = ++_profileRequestId;
    try {
      final profile = await UserProfileDatasource.getMyProfile();
      // Ignorar si hubo un cambio de usuario mientras cargaba
      if (requestId != _profileRequestId) return;
      if (profile != null) {
        // Verificar que la cuenta esté activa
        if (!profile.isActive) {
          state = const RoleState(
            error: 'Tu cuenta ha sido desactivada. Contacta al administrador.',
          );
          return;
        }
        state = RoleState(profile: profile);
        AppLogger.success(
          'Perfil cargado: ${profile.role} - ${profile.displayName}',
        );
      } else {
        // Si no hay perfil, asumir admin (usuario existente sin perfil)
        state = RoleState(
          profile: UserProfile(
            id: '',
            userId: '',
            role: 'admin',
            isActive: true,
          ),
        );
        AppLogger.warning('Sin perfil en DB, asumiendo admin');
      }
    } catch (e) {
      // Ignorar si hubo un cambio de usuario mientras cargaba
      if (requestId != _profileRequestId) return;
      AppLogger.error('Error cargando perfil de usuario', e);
      // En caso de error, permitir acceso como admin para no bloquear
      state = RoleState(
        profile: UserProfile(id: '', userId: '', role: 'admin', isActive: true),
      );
    }
  }

  /// Recargar perfil
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _loadProfile();
  }
}

/// Provider global de roles
final roleProvider = NotifierProvider<RoleNotifier, RoleState>(
  RoleNotifier.new,
);

/// Provider de conveniencia para verificar si es admin
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(roleProvider).isAdmin;
});

/// Provider de conveniencia para verificar si es técnico
final isTecnicoProvider = Provider<bool>((ref) {
  return ref.watch(roleProvider).isTecnico;
});

/// Provider de conveniencia para verificar si es dueño
final isDuenoProvider = Provider<bool>((ref) {
  return ref.watch(roleProvider).isDueno;
});

/// Provider de conveniencia para verificar si es empleado
final isEmployeeProvider = Provider<bool>((ref) {
  return ref.watch(roleProvider).isEmployee;
});

/// Provider: admin o dueño (acceso completo)
final hasFullAccessProvider = Provider<bool>((ref) {
  return ref.watch(roleProvider).hasFullAccess;
});
