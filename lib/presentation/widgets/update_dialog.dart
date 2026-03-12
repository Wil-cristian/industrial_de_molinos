import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/app_update_datasource.dart';

/// Dialogo que muestra al usuario que hay una actualizacion disponible.
/// Puede ser obligatorio (no se puede cerrar) u opcional.
class UpdateDialog extends StatelessWidget {
  final AppRelease release;

  const UpdateDialog({super.key, required this.release});

  /// Muestra el dialogo de actualizacion.
  /// Si es mandatorio, no se puede cerrar con el boton "Despues".
  static Future<void> show(BuildContext context, AppRelease release) {
    return showDialog(
      context: context,
      barrierDismissible: !release.isMandatory,
      builder: (_) => UpdateDialog(release: release),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.system_update,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Actualizacion Disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${release.version}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (release.fileSizeMb != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${release.fileSizeMb!.toStringAsFixed(1)} MB',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Release notes
          if (release.releaseNotes != null &&
              release.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Novedades:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  release.releaseNotes!,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ],

          if (release.isMandatory) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta actualizacion es obligatoria para continuar usando la app.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!release.isMandatory)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Despues',
              style: TextStyle(color: const Color(0xFF757575)),
            ),
          ),
        ElevatedButton.icon(
          onPressed: () {
            AppUpdateService.openDownloadUrl(release.downloadUrl);
            if (!release.isMandatory) {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Descargar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
