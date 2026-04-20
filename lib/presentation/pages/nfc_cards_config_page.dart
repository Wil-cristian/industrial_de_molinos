import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/nfc_cards_provider.dart';
import '../../domain/entities/employee.dart';

/// Página de configuración y gestión de tarjetas NFC
class NfcCardsConfigPage extends ConsumerStatefulWidget {
  const NfcCardsConfigPage({super.key});

  @override
  ConsumerState<NfcCardsConfigPage> createState() =>
      _NfcCardsConfigPageState();
}

class _NfcCardsConfigPageState extends ConsumerState<NfcCardsConfigPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(nfcCardsProvider.notifier);
      notifier.loadEmployees();
      notifier.startReader();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pulseController.dispose();
    ref.read(nfcCardsProvider.notifier).stopReader();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nfcCardsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Cuando está en modo asignación, quitar foco del campo de búsqueda
    // para que el lector NFC HID no escriba ahí
    if (state.isAssigning && _searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.nfc, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Configuración de Tarjetas NFC'),
          ],
        ),
        actions: [
          // Indicador del lector
          _ReaderStatusChip(isActive: state.isReaderActive),
          const SizedBox(width: 8),
          // Último escaneo
          if (state.lastScannedCardId != null)
            Chip(
              avatar: const Icon(Icons.credit_card, size: 16),
              label: Text(
                state.lastScannedCardId!,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              backgroundColor:
                  colorScheme.primaryContainer.withValues(alpha: 0.5),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar empleados',
            onPressed: () =>
                ref.read(nfcCardsProvider.notifier).loadEmployees(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Resultado de operación
          if (state.operationResult != null)
            _OperationBanner(
              message: state.operationResult!,
              isSuccess: state.operationSuccess,
            ),

          // Overlay de asignación
          if (state.isAssigning)
            _AssigningBanner(
              employeeName: state.assigningEmployeeName ?? '',
              pulseController: _pulseController,
              onCancel: () =>
                  ref.read(nfcCardsProvider.notifier).cancelAssigning(),
            ),

          // Stats y filtros
          _StatsBar(state: state),

          // Barra de búsqueda
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              enabled: !state.isAssigning,
              decoration: InputDecoration(
                hintText: state.isAssigning
                    ? 'Escanea la tarjeta NFC...'
                    : 'Buscar por nombre, tarjeta, departamento...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(nfcCardsProvider.notifier)
                              .setSearch('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(nfcCardsProvider.notifier).setSearch(v),
            ),
          ),

          // Lista de empleados
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48,
                                color: colorScheme.error),
                            const SizedBox(height: 8),
                            Text(state.error!),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => ref
                                  .read(nfcCardsProvider.notifier)
                                  .loadEmployees(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _EmployeeCardsList(
                        employees: state.filteredEmployees,
                        isAssigning: state.isAssigning,
                        assigningId: state.assigningEmployeeId,
                        onAssign: (emp) => ref
                            .read(nfcCardsProvider.notifier)
                            .startAssigning(
                              employeeId: emp.id,
                              employeeName: emp.fullName,
                            ),
                        onRemove: (emp) =>
                            _confirmRemoveCard(context, emp),
                        onReassign: (emp) => ref
                            .read(nfcCardsProvider.notifier)
                            .reassignCard(
                              employeeId: emp.id,
                              employeeName: emp.fullName,
                            ),
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveCard(BuildContext context, Employee emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.link_off, color: AppColors.danger),
        title: const Text('Remover Tarjeta NFC'),
        content: Text(
          '¿Deseas remover la tarjeta ${emp.nfcCardId} de ${emp.fullName}?\n\n'
          'El empleado no podrá fichar con NFC hasta que se le asigne una nueva tarjeta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(nfcCardsProvider.notifier)
                  .removeCard(emp.id, emp.fullName);
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

// ==================== WIDGETS ====================

class _ReaderStatusChip extends StatelessWidget {
  final bool isActive;
  const _ReaderStatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        isActive ? Icons.sensors : Icons.sensors_off,
        size: 18,
        color: isActive ? AppColors.success : Colors.grey,
      ),
      label: Text(
        isActive ? 'Lector Activo' : 'Lector Inactivo',
        style: Theme.of(context).textTheme.labelMedium,
      ),
      backgroundColor: isActive
          ? AppColors.success.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.1),
    );
  }
}

class _OperationBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;
  const _OperationBanner({
    required this.message,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isSuccess
          ? AppColors.success.withValues(alpha: 0.1)
          : AppColors.danger.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? AppColors.success : AppColors.danger,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isSuccess ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssigningBanner extends StatelessWidget {
  final String employeeName;
  final AnimationController pulseController;
  final VoidCallback onCancel;

  const _AssigningBanner({
    required this.employeeName,
    required this.pulseController,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      color: Colors.amber.withValues(alpha: 0.1),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              return Icon(
                Icons.contactless,
                color: Colors.amber.withValues(
                  alpha: 0.5 + pulseController.value * 0.5,
                ),
                size: 28,
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esperando escaneo de tarjeta...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Escanea una tarjeta NFC para asignarla a $employeeName',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final NfcCardsState state;
  const _StatsBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ProviderScope.containerOf(context).read(nfcCardsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Stats
          _StatChip(
            label: 'Total',
            count: state.totalEmployees,
            icon: Icons.people,
            color: AppColors.info,
            isSelected: state.filter == NfcCardFilter.all,
            onTap: () => notifier.setFilter(NfcCardFilter.all),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Con tarjeta',
            count: state.withCardCount,
            icon: Icons.credit_card,
            color: AppColors.success,
            isSelected: state.filter == NfcCardFilter.withCard,
            onTap: () => notifier.setFilter(NfcCardFilter.withCard),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Sin tarjeta',
            count: state.withoutCardCount,
            icon: Icons.credit_card_off,
            color: AppColors.warning,
            isSelected: state.filter == NfcCardFilter.withoutCard,
            onTap: () => notifier.setFilter(NfcCardFilter.withoutCard),
          ),
          const Spacer(),
          // Progreso
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${state.withCardCount}/${state.totalEmployees} configurados',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: state.totalEmployees > 0
                      ? state.withCardCount / state.totalEmployees
                      : 0,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  color: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeCardsList extends StatelessWidget {
  final List<Employee> employees;
  final bool isAssigning;
  final String? assigningId;
  final ValueChanged<Employee> onAssign;
  final ValueChanged<Employee> onRemove;
  final ValueChanged<Employee> onReassign;

  const _EmployeeCardsList({
    required this.employees,
    required this.isAssigning,
    required this.assigningId,
    required this.onAssign,
    required this.onRemove,
    required this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No se encontraron empleados'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        return _EmployeeNfcCard(
          employee: emp,
          isAssigning: isAssigning && assigningId == emp.id,
          onAssign: () => onAssign(emp),
          onRemove: () => onRemove(emp),
          onReassign: () => onReassign(emp),
        );
      },
    );
  }
}

class _EmployeeNfcCard extends StatelessWidget {
  final Employee employee;
  final bool isAssigning;
  final VoidCallback onAssign;
  final VoidCallback onRemove;
  final VoidCallback onReassign;

  const _EmployeeNfcCard({
    required this.employee,
    required this.isAssigning,
    required this.onAssign,
    required this.onRemove,
    required this.onReassign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasCard =
        employee.nfcCardId != null && employee.nfcCardId!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isAssigning ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isAssigning
            ? const BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: hasCard
                  ? AppColors.success.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              backgroundImage: employee.photoUrl != null
                  ? NetworkImage(employee.photoUrl!)
                  : null,
              child: employee.photoUrl == null
                  ? Text(
                      employee.initials,
                      style: TextStyle(
                        color: hasCard ? AppColors.success : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Info del empleado
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.fullName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${employee.position}${employee.department != null ? ' • ${employee.department}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Estado de tarjeta NFC
            if (hasCard) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.credit_card,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(
                      employee.nfcCardId!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Menú de acciones
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reassign',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.swap_horiz),
                      title: Text('Cambiar tarjeta'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      dense: true,
                      leading:
                          Icon(Icons.link_off, color: AppColors.danger),
                      title: Text('Remover tarjeta',
                          style: TextStyle(color: AppColors.danger)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                onSelected: (action) {
                  if (action == 'reassign') onReassign();
                  if (action == 'remove') onRemove();
                },
              ),
            ] else ...[
              // Sin tarjeta: botón asignar
              FilledButton.tonalIcon(
                onPressed: isAssigning ? null : onAssign,
                icon: const Icon(Icons.nfc, size: 18),
                label: const Text('Asignar tarjeta'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
