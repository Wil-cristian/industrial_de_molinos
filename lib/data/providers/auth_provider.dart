import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/supabase_datasource.dart';
import '../datasources/audit_log_datasource.dart';
import '../datasources/user_profile_datasource.dart';
import '../../core/utils/logger.dart';
import 'role_provider.dart';

/// Estado de autenticación
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier de autenticación
class AuthNotifier extends Notifier<AuthState> {
  Timer? _heartbeatTimer;

  @override
  AuthState build() {
    // Verificar si ya hay sesión activa
    final currentUser = SupabaseDataSource.currentUser;
    if (currentUser != null) {
      AppLogger.success('Sesión activa encontrada: ${currentUser.email}');
      // Registrar sesión y arrancar heartbeat
      _registerAndStartHeartbeat();
    }

    // Escuchar cambios de auth
    SupabaseDataSource.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      AppLogger.debug('Auth event: $event');

      if (event == AuthChangeEvent.signedIn) {
        state = state.copyWith(user: data.session?.user, clearError: true);
        _registerAndStartHeartbeat();
      } else if (event == AuthChangeEvent.signedOut) {
        _stopHeartbeat();
        state = state.copyWith(clearUser: true, clearError: true);
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        state = state.copyWith(user: data.session?.user);
      }
    });

    ref.onDispose(() {
      _stopHeartbeat();
    });

    return AuthState(user: currentUser);
  }

  void _registerAndStartHeartbeat() {
    // Registrar sesión de dispositivo
    UserProfileDatasource.registerSession();
    // Heartbeat cada 2 minutos
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => UserProfileDatasource.heartbeat(),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    // Cerrar sesión del dispositivo
    UserProfileDatasource.closeSession();
  }

  /// Iniciar sesión con email y contraseña
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await SupabaseDataSource.signIn(email, password);
      state = state.copyWith(
        user: response.user,
        isLoading: false,
        clearError: true,
      );
      AppLogger.success('Login exitoso: ${response.user?.email}');
      AuditLogDatasource.log(
        action: 'login',
        module: 'auth',
        description: 'Inició sesión: ${response.user?.email}',
      );
      return true;
    } on AuthException catch (e) {
      String message;
      switch (e.message) {
        case 'Invalid login credentials':
          message = 'Credenciales inválidas. Verifica tu email y contraseña.';
          break;
        case 'Email not confirmed':
          message = 'Email no confirmado. Revisa tu bandeja de entrada.';
          break;
        default:
          message = 'Error de autenticación: ${e.message}';
      }
      state = state.copyWith(isLoading: false, error: message);
      AppLogger.error('Error en login: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error de conexión. Verifica tu internet.',
      );
      AppLogger.error('Error inesperado en login', e);
      return false;
    }
  }

  /// Registrar nuevo usuario
  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await SupabaseDataSource.signUp(email, password);
      state = state.copyWith(
        user: response.user,
        isLoading: false,
        clearError: true,
      );
      AppLogger.success('Registro exitoso: ${response.user?.email}');
      return true;
    } on AuthException catch (e) {
      String message;
      if (e.message.contains('already registered')) {
        message = 'Este email ya está registrado.';
      } else {
        message = 'Error al registrar: ${e.message}';
      }
      state = state.copyWith(isLoading: false, error: message);
      AppLogger.error('Error en registro: ${e.message}');
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error de conexión. Verifica tu internet.',
      );
      AppLogger.error('Error inesperado en registro', e);
      return false;
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      AuditLogDatasource.log(
        action: 'logout',
        module: 'auth',
        description: 'Cerró sesión',
      );
      await SupabaseDataSource.signOut();
      // Limpiar perfil/rol del usuario anterior
      ref.invalidate(roleProvider);
      state = const AuthState();
      AppLogger.success('Sesión cerrada');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Error al cerrar sesión');
      AppLogger.error('Error cerrando sesión', e);
    }
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider global de autenticación
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Provider de conveniencia para verificar si está autenticado
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});
