import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import 'supabase_datasource.dart';

/// Modelo simple para un release de la app
class AppRelease {
  final String id;
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String? releaseNotes;
  final bool isMandatory;
  final double? fileSizeMb;
  final DateTime createdAt;

  AppRelease({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    this.releaseNotes,
    this.isMandatory = false,
    this.fileSizeMb,
    required this.createdAt,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      id: json['id'] as String,
      version: json['version'] as String,
      buildNumber: json['build_number'] as int,
      downloadUrl: json['download_url'] as String,
      releaseNotes: json['release_notes'] as String?,
      isMandatory: json['is_mandatory'] as bool? ?? false,
      fileSizeMb: json['file_size_mb'] != null
          ? (json['file_size_mb'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Servicio que verifica si hay actualizaciones disponibles
class AppUpdateService {
  static const String _table = 'app_releases';
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Verifica si hay una version mas reciente que la actual.
  /// Retorna el release si hay actualizacion, null si estamos al dia.
  static Future<AppRelease?> checkForUpdate() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .order('build_number', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      final latest = AppRelease.fromJson(response.first);
      final currentBuild = AppConstants.appBuildNumber;

      if (latest.buildNumber > currentBuild && latest.downloadUrl.isNotEmpty) {
        AppLogger.info(
          'Actualizacion disponible: v${latest.version} (build ${latest.buildNumber}) '
          '- Actual: v${AppConstants.appVersion} (build $currentBuild)',
        );
        return latest;
      }

      return null;
    } catch (e) {
      // No bloquear la app si falla el check de update
      if (kDebugMode) {
        AppLogger.error('Error verificando actualizaciones', e);
      }
      return null;
    }
  }

  /// Compara dos versiones semanticas. Retorna:
  ///  1 si v1 > v2
  ///  0 si v1 == v2
  /// -1 si v1 < v2
  static int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }
    return 0;
  }

  /// Abre la URL de descarga en el navegador del sistema
  static Future<void> openDownloadUrl(String url) async {
    try {
      // En Windows, usa 'start' para abrir la URL en el navegador predeterminado
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
      }
    } catch (e) {
      AppLogger.error('Error abriendo URL de descarga', e);
    }
  }
}
