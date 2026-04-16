---
name: "Supabase DataSources"
description: "Use when creating or editing Supabase datasource files. Covers static method pattern, JSON conversion, audit logging, Supabase client access for Industrial de Molinos."
applyTo: "**/datasources/**"
---

# Supabase DataSource Rules — Industrial de Molinos

## Pattern: Static-Method Classes

```dart
class FeatureDataSource {
  static const String _table = 'table_name';
  static SupabaseClient get _client => SupabaseDataSource.client;

  static Future<List<Entity>> getAll() async { ... }
  static Future<Entity?> getById(String id) async { ... }
  static Future<Entity> create(Entity item) async { ... }
  static Future<Entity> update(Entity item) async { ... }
  static Future<void> delete(String id) async { ... }

  static Entity _fromJson(Map<String, dynamic> json) { ... }
  static Map<String, dynamic> _toJson(Entity item) { ... }
}
```

## Required Imports
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/entity_name.dart';
import 'supabase_datasource.dart';
import 'audit_log_datasource.dart';
import '../../core/utils/colombia_time.dart';
import '../../core/utils/logger.dart';
```

## Client Access
- Always: `static SupabaseClient get _client => SupabaseDataSource.client;`
- Never hardcode Supabase URL or keys
- Config loaded from `.env` via `flutter_dotenv`

## JSON Conversion
- `_fromJson`: handle nulls with `??` defaults, parse dates with `DateTime.parse()`
- `_toJson`: exclude `id`, `created_at`, `updated_at` on create/update
- Numeric fields: always cast with `.toDouble()` — `(json['amount'] ?? 0).toDouble()`
- Dates: use `ColombiaTime.toIso8601()` for serialization

## Audit Logging
- Log `create`, `update`, `delete` actions via `AuditLogDatasource.log()`
- Include: `action`, `module` (table name), `recordId`, `description` (Spanish)

## Query Patterns
- Ordering: `.order('name', ascending: false)`
- Filtering: `.eq('is_active', true)`
- Search: `.or('name.ilike.%$query%,code.ilike.%$query%')`
- Single result: `.single()` — wrap in try/catch, return `null` on not found
- RPC calls: `_client.rpc('function_name', params: {...})`

## Error Handling
- Let exceptions bubble up to the Notifier layer
- Only catch in `getById` to return `null` on not found
- Use `AppLogger.error()` for critical operations
- Use `rethrow` after logging if the caller needs the error

## File Encoding
- **UTF-8 without BOM** — verify when editing legacy datasource files
