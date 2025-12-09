import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';

class SupabaseDataSource {
  static SupabaseClient? _client;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    _client = Supabase.instance.client;
    _initialized = true;
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase no inicializado. Llama a initialize() primero.');
    }
    return _client!;
  }

  static bool get isInitialized => _initialized;

  // Verificar conexión
  static Future<bool> checkConnection() async {
    try {
      await client.from('products').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Auth
  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  // Métodos de autenticación
  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // CRUD genérico
  static Future<List<Map<String, dynamic>>> getAll(String table) async {
    final response = await client.from(table).select();
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> getById(String table, String id) async {
    final response = await client.from(table).select().eq('id', id).single();
    return response;
  }

  static Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response = await client.from(table).insert(data).select().single();
    return response;
  }

  static Future<Map<String, dynamic>> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await client
        .from(table)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return response;
  }

  static Future<void> delete(String table, String id) async {
    await client.from(table).delete().eq('id', id);
  }

  // Suscripción a cambios en tiempo real
  static RealtimeChannel subscribeToTable(
    String table,
    void Function(Map<String, dynamic>) onInsert,
    void Function(Map<String, dynamic>) onUpdate,
    void Function(Map<String, dynamic>) onDelete,
  ) {
    return client.channel('public:$table').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (payload) {
        switch (payload.eventType) {
          case PostgresChangeEvent.insert:
            onInsert(payload.newRecord);
            break;
          case PostgresChangeEvent.update:
            onUpdate(payload.newRecord);
            break;
          case PostgresChangeEvent.delete:
            onDelete(payload.oldRecord);
            break;
          default:
            break;
        }
      },
    ).subscribe();
  }
}
