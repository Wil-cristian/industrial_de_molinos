import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/nfc_kiosk_provider.dart';

/// Pagina de asistencia NFC — Kiosko Windows con lector USB
class NfcAttendancePage extends ConsumerStatefulWidget {
  const NfcAttendancePage({super.key});

  @override
  ConsumerState<NfcAttendancePage> createState() => _NfcAttendancePageState();
}

class _NfcAttendancePageState extends ConsumerState<NfcAttendancePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nfcKioskProvider.notifier).startKiosk();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kioskState = ref.watch(nfcKioskProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.nfc, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Punto de Fichaje NFC'),
          ],
        ),
        actions: [
          _StatusIndicator(isActive: kioskState.isActive),
          const SizedBox(width: 8),
          if (!kioskState.isLinkingCard)
            FilledButton.tonalIcon(
              onPressed: () => _showSelectEmployeeForLinking(kioskState),
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Vincular Tarjeta'),
            ),
          if (kioskState.isLinkingCard)
            FilledButton.icon(
              onPressed: () =>
                  ref.read(nfcKioskProvider.notifier).cancelCardLinking(),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancelar vinculacion'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
            ),
          const SizedBox(width: 8),
          Chip(
            avatar: const Icon(Icons.people, size: 18),
            label: Text(
              '${kioskState.checkedInCount}/${kioskState.totalEmployees}',
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar estado',
            onPressed: () =>
                ref.read(nfcKioskProvider.notifier).loadTodayStatus(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: kioskState.isLinkingCard
          ? _buildLinkingOverlay(kioskState, theme)
          : _buildKioskMode(kioskState, theme),
    );
  }

  /// Muestra un dialogo para seleccionar empleado y vincular tarjeta
  void _showSelectEmployeeForLinking(NfcKioskState kioskState) {
    final employees = kioskState.todayStatus;
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay empleados cargados')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        String search = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = employees.where((e) {
              final name = '${e['first_name'] ?? ''} ${e['last_name'] ?? ''}'
                  .toLowerCase();
              return name.contains(search.toLowerCase());
            }).toList();

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.link,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Vincular Tarjeta NFC'),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selecciona el empleado al que quieres asignar una tarjeta. Luego escanea la tarjeta en el lector.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar empleado...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setDialogState(() => search = v),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final emp = filtered[index];
                          final firstName = emp['first_name'] as String? ?? '';
                          final lastName = emp['last_name'] as String? ?? '';
                          final nfcId = emp['nfc_card_id'] as String?;
                          final hasNfc = nfcId != null && nfcId.isNotEmpty;

                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: hasNfc
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                              child: Icon(
                                hasNfc ? Icons.credit_card : Icons.person,
                                size: 18,
                                color: hasNfc ? Colors.green : Colors.grey,
                              ),
                            ),
                            title: Text('$firstName $lastName'),
                            subtitle: Text(
                              hasNfc ? 'NFC: $nfcId' : 'Sin tarjeta NFC',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasNfc ? Colors.green : Colors.grey,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              ref
                                  .read(nfcKioskProvider.notifier)
                                  .startCardLinking(
                                    employeeId: emp['id'] as String,
                                    employeeName: '$firstName $lastName',
                                  );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Overlay que se muestra mientras se espera el escaneo de vinculacion
  Widget _buildLinkingOverlay(NfcKioskState kioskState, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.15);
              return Transform.scale(
                scale: kioskState.isProcessing ? 1.0 : scale,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    kioskState.isProcessing
                        ? Icons.hourglass_top
                        : Icons.contactless,
                    size: 70,
                    color: Colors.amber,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          Text(
            'Vinculando tarjeta para:',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kioskState.linkingEmployeeName ?? '',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          if (kioskState.isProcessing)
            const CircularProgressIndicator()
          else if (kioskState.linkingResult != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                kioskState.linkingResult!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
            Text(
              'Escanea la tarjeta NFC en el lector USB',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La tarjeta quedara asignada a este empleado',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],

          if (kioskState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                kioskState.error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
            ),
          ],

          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(nfcKioskProvider.notifier).cancelCardLinking(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver al fichaje'),
          ),
        ],
      ),
    );
  }

  // ========== MODO KIOSKO ==========

  Widget _buildKioskMode(NfcKioskState kioskState, ThemeData theme) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 800;

    if (isCompact) {
      return Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildCheckpointPanel(kioskState, theme),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            flex: 2,
            child: _buildEmployeeStatusPanel(kioskState, theme),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 3, child: _buildCheckpointPanel(kioskState, theme)),
        VerticalDivider(width: 1, color: theme.dividerColor),
        Expanded(flex: 2, child: _buildEmployeeStatusPanel(kioskState, theme)),
      ],
    );
  }

  Widget _buildCheckpointPanel(NfcKioskState kioskState, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (kioskState.error != null)
            _ErrorBanner(message: kioskState.error!, theme: theme),

          Expanded(
            child: Center(
              child: kioskState.isProcessing
                  ? _buildProcessingIndicator(theme)
                  : kioskState.lastResult != null
                  ? _buildResultCard(kioskState.lastResult!, theme)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulseController.value * 0.15);
                            final opacity = 0.3 + (_pulseController.value * 0.7);
                            return Transform.scale(
                              scale: kioskState.isActive ? scale : 1.0,
                              child: Icon(
                                Icons.contactless,
                                size: 100,
                                color: kioskState.isActive
                                    ? colorScheme.primary.withValues(alpha: opacity)
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          kioskState.isActive
                              ? 'Lector NFC Activo'
                              : 'Lector NFC Inactivo',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: kioskState.isActive
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          kioskState.isActive
                              ? 'Acerque la tarjeta al lector para registrar asistencia'
                              : 'El lector no esta activo',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ),
          ),

          _ClockWidget(theme: theme),

          const SizedBox(height: 16),

          if (kioskState.recentResults.isNotEmpty)
            _RecentResultsBar(results: kioskState.recentResults, theme: theme),
        ],
      ),
    );
  }

  // ========== WIDGETS COMPARTIDOS ==========

  Widget _buildProcessingIndicator(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            strokeWidth: 6,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Registrando asistencia...',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(NfcAttendanceResult result, ThemeData theme) {
    final isCheckIn = result.action == 'CHECK_IN';
    final isCheckOut = result.action == 'CHECK_OUT';

    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    if (isCheckIn) {
      bgColor = AppColors.success.withValues(alpha: 0.1);
      fgColor = AppColors.success;
      icon = Icons.login;
    } else if (isCheckOut) {
      bgColor = AppColors.info.withValues(alpha: 0.1);
      fgColor = AppColors.info;
      icon = Icons.logout;
    } else {
      bgColor = AppColors.danger.withValues(alpha: 0.1);
      fgColor = AppColors.danger;
      icon = Icons.error_outline;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(result.hashCode),
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: fgColor.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: fgColor),
                if (result.photoUrl != null) ...[
                  const SizedBox(width: 16),
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(result.photoUrl!),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (result.employeeName != null)
              Text(
                result.employeeName!,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: fgColor,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Text(
              result.message,
              style: theme.textTheme.titleLarge?.copyWith(
                color: result.success ? theme.colorScheme.onSurface : fgColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (result.checkIn != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _TimeChip(
                    label: 'Entrada',
                    time: result.checkIn!,
                    icon: Icons.login,
                    color: AppColors.success,
                  ),
                  if (result.checkOut != null)
                    _TimeChip(
                      label: 'Salida',
                      time: result.checkOut!,
                      icon: Icons.logout,
                      color: AppColors.info,
                    ),
                ],
              ),
            ],
            if (result.workedMinutes != null && result.workedMinutes! > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Tiempo trabajado: ${_formatMinutes(result.workedMinutes!)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeStatusPanel(NfcKioskState kioskState, ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Icon(Icons.people, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Estado de Asistencia Hoy',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: kioskState.todayStatus.isEmpty
              ? Center(
                  child: Text(
                    'Cargando empleados...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: kioskState.todayStatus.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, index) {
                    final emp = kioskState.todayStatus[index];
                    return _EmployeeStatusTile(employee: emp);
                  },
                ),
        ),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

// ========== WIDGETS AUXILIARES ==========

class _StatusIndicator extends StatelessWidget {
  final bool isActive;

  const _StatusIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Activo' : 'Inactivo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final ThemeData theme;

  const _ErrorBanner({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockWidget extends StatelessWidget {
  final ThemeData theme;

  const _ClockWidget({required this.theme});

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final now = DateTime.now();
        return Column(
          children: [
            Text(
              DateFormat('HH:mm:ss').format(now),
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              DateFormat("EEEE d 'de' MMMM, yyyy", 'es').format(now),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentResultsBar extends StatelessWidget {
  final List<NfcAttendanceResult> results;
  final ThemeData theme;

  const _RecentResultsBar({required this.results, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Registros recientes',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final result = results[index];
              return Chip(
                avatar: Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? AppColors.success : AppColors.danger,
                  size: 18,
                ),
                label: Text(
                  result.employeeName ?? result.action,
                  style: theme.textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final DateTime time;
  final IconData icon;
  final Color color;

  const _TimeChip({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(
                DateFormat('HH:mm').format(time.toLocal()),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeStatusTile extends StatelessWidget {
  final Map<String, dynamic> employee;

  const _EmployeeStatusTile({required this.employee});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = employee['employee_time_entries'] as List? ?? [];
    final hasEntry = entries.isNotEmpty;
    final entry = hasEntry ? entries.first as Map<String, dynamic> : null;
    final hasCheckOut = entry?['check_out'] != null;

    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    if (!hasEntry) {
      statusText = 'Sin registrar';
      statusColor = Colors.grey;
      statusIcon = Icons.remove_circle_outline;
    } else if (hasCheckOut) {
      statusText = 'Jornada completa';
      statusColor = AppColors.info;
      statusIcon = Icons.check_circle;
    } else {
      statusText = 'Trabajando';
      statusColor = AppColors.success;
      statusIcon = Icons.play_circle;
    }

    final firstName = employee['first_name'] as String? ?? '';
    final lastName = employee['last_name'] as String? ?? '';
    final position = employee['position'] as String? ?? '';

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: statusColor.withValues(alpha: 0.15),
        child: Text(
          '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}',
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(
        '$firstName $lastName',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        position,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry?['check_in'] != null)
            Text(
              DateFormat(
                'HH:mm',
              ).format(DateTime.parse(entry!['check_in'] as String).toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          if (entry?['check_out'] != null) ...[
            Text(' - ', style: theme.textTheme.bodySmall),
            Text(
              DateFormat(
                'HH:mm',
              ).format(DateTime.parse(entry!['check_out'] as String).toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.info,
              ),
            ),
          ],
          const SizedBox(width: 8),
          Tooltip(
            message: statusText,
            child: Icon(statusIcon, size: 18, color: statusColor),
          ),
        ],
      ),
    );
  }
}