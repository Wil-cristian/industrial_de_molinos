import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/providers/assets_provider.dart';
import '../../../data/providers/employees_provider.dart';
import '../../../domain/entities/asset.dart';

/// Modelo ligero para un activo asignado a un empleado via producción
class EmployeeAssetAssignment {
  final String employeeId;
  final String employeeName;
  final String assetId;
  final String stageName;
  final String orderCode;
  final String stageStatus;

  const EmployeeAssetAssignment({
    required this.employeeId,
    required this.employeeName,
    required this.assetId,
    required this.stageName,
    required this.orderCode,
    required this.stageStatus,
  });
}

class EmployeesAssetsTab extends ConsumerStatefulWidget {
  const EmployeesAssetsTab({super.key});

  @override
  ConsumerState<EmployeesAssetsTab> createState() => EmployeesAssetsTabState();
}

class EmployeesAssetsTabState extends ConsumerState<EmployeesAssetsTab> {
  List<EmployeeAssetAssignment> _assignments = [];
  bool _isLoading = true;
  String _filterEmployee = '';
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      // Obtener etapas con empleado y activos asignados
      final response = await client
          .from('production_stages')
          .select(
            'process_name, status, asset_ids, assigned_employee_id, '
            'employees(first_name, last_name), '
            'production_orders(code)',
          )
          .not('assigned_employee_id', 'is', null)
          .neq('asset_ids', '{}');

      final rows = response as List;
      final assignments = <EmployeeAssetAssignment>[];

      for (final row in rows) {
        final empId = row['assigned_employee_id'] as String;
        final empData = row['employees'] as Map<String, dynamic>?;
        final empName = empData != null
            ? '${empData['first_name']} ${empData['last_name']}'
            : 'Sin nombre';
        final orderData = row['production_orders'] as Map<String, dynamic>?;
        final orderCode = orderData?['code'] as String? ?? '';
        final stageName = row['process_name'] as String? ?? '';
        final stageStatus = row['status'] as String? ?? '';
        final assetIds =
            (row['asset_ids'] as List?)?.map((e) => e.toString()).toList() ??
            [];

        for (final assetId in assetIds) {
          assignments.add(
            EmployeeAssetAssignment(
              employeeId: empId,
              employeeName: empName,
              assetId: assetId,
              stageName: stageName,
              orderCode: orderCode,
              stageStatus: stageStatus,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allAssets = ref.watch(assetsProvider).assets;
    final employees = ref.watch(employeesProvider).activeEmployees;

    // Agrupar por empleado
    final grouped = <String, List<EmployeeAssetAssignment>>{};
    for (final a in _assignments) {
      if (_selectedEmployeeId != null && a.employeeId != _selectedEmployeeId) {
        continue;
      }
      if (_filterEmployee.isNotEmpty &&
          !a.employeeName.toLowerCase().contains(
            _filterEmployee.toLowerCase(),
          )) {
        continue;
      }
      grouped.putIfAbsent(a.employeeId, () => []).add(a);
    }

    return Column(
      children: [
        // Filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar empleado...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filterEmployee = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedEmployeeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Empleado',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ...employees.map(
                      (e) => DropdownMenuItem<String?>(
                        value: e.id,
                        child: Text(
                          e.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedEmployeeId = v),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _loadAssignments,
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar',
              ),
            ],
          ),
        ),

        // Contenido
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : grouped.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.precision_manufacturing_outlined,
                        size: 64,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sin activos asignados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Asigna activos a empleados desde las etapas de producción',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final empId = grouped.keys.elementAt(index);
                    final empAssignments = grouped[empId]!;
                    final empName = empAssignments.first.employeeName;

                    return _EmployeeAssetCard(
                      employeeName: empName,
                      assignments: empAssignments,
                      allAssets: allAssets,
                      colorScheme: cs,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmployeeAssetCard extends StatelessWidget {
  final String employeeName;
  final List<EmployeeAssetAssignment> assignments;
  final List<Asset> allAssets;
  final ColorScheme colorScheme;

  const _EmployeeAssetCard({
    required this.employeeName,
    required this.assignments,
    required this.allAssets,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;

    // Deduplicar activos (un activo puede estar en varias etapas)
    final uniqueAssetIds = assignments.map((a) => a.assetId).toSet();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 20,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${uniqueAssetIds.length} activo(s) asignado(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...uniqueAssetIds.map((assetId) {
              final asset = allAssets.where((a) => a.id == assetId).toList();
              final assetName = asset.isNotEmpty
                  ? asset.first.name
                  : 'Activo desconocido';
              final assetBrand = asset.isNotEmpty ? asset.first.brand : null;
              final assetModel = asset.isNotEmpty ? asset.first.model : null;
              final assetCategory = asset.isNotEmpty
                  ? asset.first.categoryLabel
                  : '';

              // Etapas donde se usa este activo
              final stages = assignments
                  .where((a) => a.assetId == assetId)
                  .toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 20,
                      color: cs.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assetName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (assetBrand != null || assetModel != null)
                            Text(
                              [
                                assetBrand,
                                assetModel,
                              ].where((e) => e != null).join(' '),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          if (assetCategory.isNotEmpty)
                            Text(
                              assetCategory,
                              style: TextStyle(fontSize: 11, color: cs.primary),
                            ),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: stages.map((s) {
                              final isActive = s.stageStatus == 'en_proceso';
                              return Chip(
                                label: Text(
                                  '${s.orderCode} — ${s.stageName}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isActive
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                                backgroundColor: isActive
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
