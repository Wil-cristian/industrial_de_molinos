import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_datasource.dart';

/// Modelo para representar un archivo adjunto
class AttachmentInfo {
  final String name;
  final String path; // ruta en el bucket de Storage
  final int size;
  final String? mimeType;
  final String? publicUrl;

  AttachmentInfo({
    required this.name,
    required this.path,
    required this.size,
    this.mimeType,
    this.publicUrl,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'size': size,
    'type': mimeType,
  };

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) => AttachmentInfo(
    name: json['name'] ?? '',
    path: json['path'] ?? '',
    size: json['size'] ?? 0,
    mimeType: json['type'],
  );

  /// Extensión del archivo
  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';

  /// Es imagen?
  bool get isImage => ['jpg', 'jpeg', 'png', 'webp'].contains(extension);

  /// Es PDF?
  bool get isPdf => extension == 'pdf';
}

/// DataSource para gestionar archivos en Supabase Storage
class StorageDatasource {
  static const String _bucketId = 'attachments';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Sube un archivo desde PlatformFile (file_picker) al bucket
  /// Retorna la información del archivo subido
  static Future<AttachmentInfo> uploadFile({
    required PlatformFile file,
    required String movementId,
  }) async {
    final String fileName = _sanitizeFileName(file.name);
    final String storagePath = 'movements/$movementId/$fileName';

    Uint8List fileBytes;

    // En web se usa bytes, en desktop/mobile se usa path
    if (file.bytes != null) {
      fileBytes = file.bytes!;
    } else if (file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    } else {
      throw Exception('No se pudo leer el archivo: ${file.name}');
    }

    final String mimeType = _getMimeType(fileName);

    await _client.storage
        .from(_bucketId)
        .uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    return AttachmentInfo(
      name: file.name,
      path: storagePath,
      size: file.size,
      mimeType: mimeType,
    );
  }

  /// Sube múltiples archivos y retorna la lista de info
  static Future<List<AttachmentInfo>> uploadFiles({
    required List<PlatformFile> files,
    required String movementId,
  }) async {
    final List<AttachmentInfo> results = [];
    for (final file in files) {
      final info = await uploadFile(file: file, movementId: movementId);
      results.add(info);
    }
    return results;
  }

  /// Obtiene la URL pública de un archivo
  static String getPublicUrl(String storagePath) {
    return _client.storage.from(_bucketId).getPublicUrl(storagePath);
  }

  /// Obtiene una URL firmada (temporal) para un archivo
  static Future<String> getSignedUrl(
    String storagePath, {
    int expiresIn = 3600,
  }) async {
    return await _client.storage
        .from(_bucketId)
        .createSignedUrl(storagePath, expiresIn);
  }

  /// Elimina un archivo del storage
  static Future<void> deleteFile(String storagePath) async {
    await _client.storage.from(_bucketId).remove([storagePath]);
  }

  /// Elimina todos los archivos de un movimiento
  static Future<void> deleteMovementFiles(String movementId) async {
    try {
      final files = await _client.storage
          .from(_bucketId)
          .list(path: 'movements/$movementId');

      if (files.isNotEmpty) {
        final paths = files
            .map((f) => 'movements/$movementId/${f.name}')
            .toList();
        await _client.storage.from(_bucketId).remove(paths);
      }
    } catch (e) {
      // Si falla la limpieza, no es crítico
      print(
        'Warning: No se pudieron limpiar archivos de movimiento $movementId: $e',
      );
    }
  }

  /// Actualiza la columna attachments en cash_movements
  static Future<void> saveAttachmentsToMovement(
    String movementId,
    List<AttachmentInfo> attachments,
  ) async {
    await _client
        .from('cash_movements')
        .update({'attachments': attachments.map((a) => a.toJson()).toList()})
        .eq('id', movementId);
  }

  /// Obtiene los attachments de un movimiento desde la DB
  static Future<List<AttachmentInfo>> getMovementAttachments(
    String movementId,
  ) async {
    final result = await _client
        .from('cash_movements')
        .select('attachments')
        .eq('id', movementId)
        .single();

    final attachments = result['attachments'];
    if (attachments == null || attachments is! List) return [];

    return attachments
        .map<AttachmentInfo>(
          (a) => AttachmentInfo.fromJson(Map<String, dynamic>.from(a)),
        )
        .toList();
  }

  /// Asegura que el bucket existe (llamar al inicializar la app si es necesario)
  static Future<bool> ensureBucketExists() async {
    try {
      await _client.storage.getBucket(_bucketId);
      return true;
    } catch (e) {
      // El bucket no existe, intentaremos crearlo
      try {
        await _client.storage.createBucket(
          _bucketId,
          const BucketOptions(
            public: true,
            fileSizeLimit: '10485760', // 10MB
            allowedMimeTypes: [
              'image/jpeg',
              'image/png',
              'image/webp',
              'application/pdf',
              'application/msword',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'application/vnd.ms-excel',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
          ),
        );
        return true;
      } catch (createError) {
        print('Error creando bucket: $createError');
        return false;
      }
    }
  }

  // ─── Utilidades privadas ────────────────────────────────

  /// Sanitiza el nombre del archivo para evitar problemas con Storage
  static String _sanitizeFileName(String name) {
    // Reemplazar espacios y caracteres especiales
    return name
        .replaceAll(RegExp(r'[^\w\-.]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Determina el MIME type basado en la extensión
  static String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}
