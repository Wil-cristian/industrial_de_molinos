import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/activity.dart';
import '../../data/providers/assets_provider.dart';
import '../../data/providers/activities_provider.dart';

/// Página de Activos Fijos / Inversiones
/// Gestión de herramientas, maquinaria, equipos e inversiones
class AssetsPage extends ConsumerStatefulWidget {
  final bool openNewDialog;

  const AssetsPage({super.key, this.openNewDialog = false});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  final _searchController = TextEditingController();
  bool _dialogOpened = false;
  Asset? _selectedAsset;
  List<AssetMaintenance> _maintenanceHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assetsProvider.notifier).loadAssets();

      if (widget.openNewDialog && !_dialogOpened) {
        _dialogOpened = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showAddAssetDialog();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assetsProvider);

    return Scaffold(
      body: Container(
        color: AppTheme.backgroundColor,
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Content
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        // Left: Grid
                        Expanded(
                          flex: _selectedAsset != null ? 3 : 1,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatsCards(state),
                                const SizedBox(height: 12),
                                _buildFilters(state),
                                const SizedBox(height: 12),
                                _buildAssetsGrid(state),
                              ],
                            ),
                          ),
                        ),
                        // Right: Detail panel
                        if (_selectedAsset != null)
                          SizedBox(
                            width: 420,
                            child: _buildDetailPanel(_selectedAsset!),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 880;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    onPressed: () => context.go('/'),
                    tooltip: 'Volver al menú',
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activos Fijos e Inversiones',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                        ),
                        Text(
                          'Herramientas, maquinaria y equipos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _showAddAssetDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isNarrow ? 'Nuevo' : 'Nuevo Activo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCards(AssetsState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 500;
        if (narrow) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: (constraints.maxWidth - 8) / 2,
                child: _buildStatCard(
                  'Activos',
                  '${state.totalAssets}',
                  Icons.business_center,
                  Colors.blue,
                ),
              ),
              SizedBox(
                width: (constraints.maxWidth - 8) / 2,
                child: _buildStatCard(
                  'Valor',
                  '\$ ${Helpers.formatNumber(state.totalValue)}',
                  Icons.account_balance,
                  Colors.green,
                ),
              ),
              SizedBox(
                width: (constraints.maxWidth - 8) / 2,
                child: _buildStatCard(
                  'Inversión',
                  '\$ ${Helpers.formatNumber(state.totalInvestment)}',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ),
              SizedBox(
                width: (constraints.maxWidth - 8) / 2,
                child: _buildStatCard(
                  'Mant.',
                  '${state.inMaintenance}',
                  Icons.build,
                  Colors.orange,
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Activos',
                '${state.totalAssets}',
                Icons.business_center,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Valor',
                '\$ ${Helpers.formatNumber(state.totalValue)}',
                Icons.account_balance,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Inversión',
                '\$ ${Helpers.formatNumber(state.totalInvestment)}',
                Icons.trending_up,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Mant.',
                '${state.inMaintenance}',
                Icons.build,
                Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(AssetsState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(assetsProvider.notifier).search(value);
              },
              decoration: InputDecoration(
                hintText: 'Buscar activo...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: state.categoryFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'todas', child: Text('Todas')),
                DropdownMenuItem(
                  value: 'maquinaria',
                  child: Text('Maquinaria'),
                ),
                DropdownMenuItem(
                  value: 'herramientas',
                  child: Text('Herramientas'),
                ),
                DropdownMenuItem(value: 'equipos', child: Text('Equipos')),
                DropdownMenuItem(value: 'vehiculos', child: Text('Vehículos')),
                DropdownMenuItem(
                  value: 'mobiliario',
                  child: Text('Mobiliario'),
                ),
                DropdownMenuItem(value: 'otros', child: Text('Otros')),
              ],
              onChanged: (value) {
                ref
                    .read(assetsProvider.notifier)
                    .filterByCategory(value ?? 'todas');
              },
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: state.statusFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos')),
                DropdownMenuItem(value: 'activo', child: Text('Activo')),
                DropdownMenuItem(
                  value: 'mantenimiento',
                  child: Text('Mantenimiento'),
                ),
                DropdownMenuItem(value: 'baja', child: Text('Dado de Baja')),
                DropdownMenuItem(value: 'vendido', child: Text('Vendido')),
              ],
              onChanged: (value) {
                ref
                    .read(assetsProvider.notifier)
                    .filterByStatus(value ?? 'todos');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsGrid(AssetsState state) {
    final filteredAssets = state.filteredAssets;

    if (filteredAssets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_center_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No hay activos registrados',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _showAddAssetDialog,
                icon: const Icon(Icons.add),
                label: const Text('Agregar primer activo'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _selectedAsset != null
            ? (constraints.maxWidth > 500 ? 2 : 1)
            : (constraints.maxWidth > 700 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: filteredAssets.length,
          itemBuilder: (context, index) {
            final asset = filteredAssets[index];
            return _buildAssetCard(asset);
          },
        );
      },
    );
  }

  Widget _buildAssetCard(Asset asset) {
    final isSelected = _selectedAsset?.id == asset.id;
    return GestureDetector(
      onTap: () => _selectAsset(asset),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.primaryColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
              blurRadius: isSelected ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: asset.categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    asset.categoryIcon,
                    color: asset.categoryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        asset.categoryLabel,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') _showEditAssetDialog(asset);
                    if (value == 'maintenance') _showMaintenanceDialog(asset);
                    if (value == 'delete') _showDeleteConfirmation(asset);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'maintenance',
                      child: Text('Mantenimiento'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            if (asset.description != null)
              Text(
                asset.description!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  asset.status == 'activo'
                      ? Icons.check_circle
                      : asset.status == 'mantenimiento'
                      ? Icons.build
                      : Icons.cancel,
                  color: asset.statusColor,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  asset.statusLabel,
                  style: TextStyle(
                    color: asset.statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$ ${Helpers.formatNumber(asset.currentValue)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (asset.location != null)
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    asset.location!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _selectAsset(Asset asset) async {
    setState(() => _selectedAsset = asset);
    final history = await ref
        .read(assetsProvider.notifier)
        .loadMaintenanceHistory(asset.id)
        .then((_) => ref.read(assetsProvider).maintenanceHistory);
    if (mounted) {
      setState(() => _maintenanceHistory = history);
    }
  }

  Widget _buildDetailPanel(Asset asset) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Header del panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: asset.categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(asset.categoryIcon, color: asset.categoryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        asset.categoryLabel,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedAsset = null),
                ),
              ],
            ),
          ),

          // Contenido scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado actual y cambio de estado
                  _buildStatusSection(asset),
                  const SizedBox(height: 20),

                  // Info general
                  _buildInfoSection(asset),
                  const SizedBox(height: 20),

                  // Notas
                  _buildNotesSection(asset),
                  const SizedBox(height: 20),

                  // Historial de mantenimiento
                  _buildMaintenanceHistorySection(asset),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Asset asset) {
    final statuses = [
      {
        'value': 'activo',
        'label': 'Activo',
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'value': 'mantenimiento',
        'label': 'Mantenimiento',
        'icon': Icons.build,
        'color': Colors.orange,
      },
      {
        'value': 'baja',
        'label': 'De Baja',
        'icon': Icons.cancel,
        'color': Colors.red,
      },
      {
        'value': 'vendido',
        'label': 'Vendido',
        'icon': Icons.sell,
        'color': Colors.blue,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statuses.map((s) {
            final isActive = asset.status == s['value'];
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s['icon'] as IconData,
                    size: 16,
                    color: isActive ? Colors.white : s['color'] as Color,
                  ),
                  const SizedBox(width: 4),
                  Text(s['label'] as String),
                ],
              ),
              selected: isActive,
              selectedColor: s['color'] as Color,
              labelStyle: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
              onSelected: (selected) async {
                if (selected && !isActive) {
                  final success = await ref
                      .read(assetsProvider.notifier)
                      .updateStatus(asset.id, s['value'] as String);
                  if (success && mounted) {
                    // Actualizar el asset seleccionado con el nuevo estado
                    final updated = ref
                        .read(assetsProvider)
                        .assets
                        .where((a) => a.id == asset.id)
                        .firstOrNull;
                    if (updated != null) {
                      setState(() => _selectedAsset = updated);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Estado cambiado a ${s['label']}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoSection(Asset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _infoRow(
                'Valor actual',
                '\$ ${Helpers.formatNumber(asset.currentValue)}',
              ),
              _infoRow(
                'Precio compra',
                '\$ ${Helpers.formatNumber(asset.purchasePrice)}',
              ),
              _infoRow('Depreciación', '${asset.depreciationRate}% anual'),
              if (asset.location != null)
                _infoRow('Ubicación', asset.location!),
              if (asset.brand != null) _infoRow('Marca', asset.brand!),
              if (asset.model != null) _infoRow('Modelo', asset.model!),
              if (asset.serialNumber != null)
                _infoRow('N° Serie', asset.serialNumber!),
              if (asset.assignedTo != null)
                _infoRow('Asignado a', asset.assignedTo!),
              if (asset.warrantyExpiry != null)
                _infoRow(
                  'Garantía',
                  '${asset.warrantyExpiry!.day}/${asset.warrantyExpiry!.month}/${asset.warrantyExpiry!.year}'
                      ' ${asset.isWarrantyValid ? '(Vigente)' : '(Vencida)'}',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(Asset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 16),
              onPressed: () => _showEditNotesDialog(asset),
              tooltip: 'Editar notas',
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Text(
            asset.notes?.isNotEmpty == true ? asset.notes! : 'Sin notas',
            style: TextStyle(
              color: asset.notes?.isNotEmpty == true
                  ? Colors.black87
                  : Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditNotesDialog(Asset asset) {
    final controller = TextEditingController(text: asset.notes ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar notas'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Escribe notas sobre este activo...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final updated = asset.copyWith(notes: controller.text);
              final success = await ref
                  .read(assetsProvider.notifier)
                  .updateAsset(updated);
              if (success && mounted) {
                setState(() => _selectedAsset = updated);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notas actualizadas'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceHistorySection(Asset asset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Historial de Mantenimiento',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: () => _showMaintenanceDialog(asset),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_maintenanceHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.build_outlined, size: 32, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'Sin registros de mantenimiento',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...(_maintenanceHistory.map((m) => _buildMaintenanceCard(m))),
      ],
    );
  }

  Widget _buildMaintenanceCard(AssetMaintenance m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: m.typeColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: m.typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.typeLabel,
                  style: TextStyle(
                    color: m.typeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${m.maintenanceDate.day}/${m.maintenanceDate.month}/${m.maintenanceDate.year}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(m.description, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (m.cost > 0) ...[
                Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                Text(
                  Helpers.formatNumber(m.cost),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 12),
              ],
              if (m.performedBy != null) ...[
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 2),
                Text(
                  m.performedBy!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
          if (m.nextMaintenanceDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event, size: 14, color: Colors.blue[400]),
                const SizedBox(width: 4),
                Text(
                  'Próximo: ${m.nextMaintenanceDate!.day}/${m.nextMaintenanceDate!.month}/${m.nextMaintenanceDate!.year}',
                  style: TextStyle(color: Colors.blue[400], fontSize: 12),
                ),
              ],
            ),
          ],
          if (m.notes != null && m.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              m.notes!,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddAssetDialog() {
    _showAssetDialog();
  }

  void _showEditAssetDialog(Asset asset) {
    _showAssetDialog(asset: asset);
  }

  void _showAssetDialog({Asset? asset}) {
    final isEditing = asset != null;
    final nameController = TextEditingController(text: asset?.name ?? '');
    final descriptionController = TextEditingController(
      text: asset?.description ?? '',
    );
    final purchasePriceController = TextEditingController(
      text: asset?.purchasePrice.toString() ?? '',
    );
    final currentValueController = TextEditingController(
      text: asset?.currentValue.toString() ?? '',
    );
    final locationController = TextEditingController(
      text: asset?.location ?? '',
    );
    final serialController = TextEditingController(
      text: asset?.serialNumber ?? '',
    );
    final brandController = TextEditingController(text: asset?.brand ?? '');
    final modelController = TextEditingController(text: asset?.model ?? '');

    String selectedCategory = asset?.category ?? 'maquinaria';
    String selectedStatus = asset?.status ?? 'activo';
    DateTime purchaseDate = asset?.purchaseDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Activo' : 'Nuevo Activo'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del activo *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'maquinaria',
                              child: Text('Maquinaria'),
                            ),
                            DropdownMenuItem(
                              value: 'herramientas',
                              child: Text('Herramientas'),
                            ),
                            DropdownMenuItem(
                              value: 'equipos',
                              child: Text('Equipos'),
                            ),
                            DropdownMenuItem(
                              value: 'vehiculos',
                              child: Text('Vehículos'),
                            ),
                            DropdownMenuItem(
                              value: 'mobiliario',
                              child: Text('Mobiliario'),
                            ),
                            DropdownMenuItem(
                              value: 'otros',
                              child: Text('Otros'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedCategory = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: purchasePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Precio de compra *',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            if (currentValueController.text.isEmpty) {
                              currentValueController.text = value;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: currentValueController,
                          decoration: const InputDecoration(
                            labelText: 'Valor actual *',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Fecha de compra'),
                          subtitle: Text(
                            '${purchaseDate.day}/${purchaseDate.month}/${purchaseDate.year}',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: purchaseDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setDialogState(() => purchaseDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'activo',
                              child: Text('Activo'),
                            ),
                            DropdownMenuItem(
                              value: 'mantenimiento',
                              child: Text('Mantenimiento'),
                            ),
                            DropdownMenuItem(
                              value: 'baja',
                              child: Text('Dado de Baja'),
                            ),
                            DropdownMenuItem(
                              value: 'vendido',
                              child: Text('Vendido'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedStatus = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: brandController,
                          decoration: const InputDecoration(
                            labelText: 'Marca',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: modelController,
                          decoration: const InputDecoration(
                            labelText: 'Modelo',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: serialController,
                          decoration: const InputDecoration(
                            labelText: 'Número de serie',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Ubicación',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    purchasePriceController.text.isEmpty ||
                    currentValueController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa los campos obligatorios'),
                    ),
                  );
                  return;
                }

                final newAsset = Asset(
                  id: asset?.id ?? '',
                  name: nameController.text,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  category: selectedCategory,
                  purchaseDate: purchaseDate,
                  purchasePrice:
                      double.tryParse(purchasePriceController.text) ?? 0,
                  currentValue:
                      double.tryParse(currentValueController.text) ?? 0,
                  status: selectedStatus,
                  location: locationController.text.isEmpty
                      ? null
                      : locationController.text,
                  serialNumber: serialController.text.isEmpty
                      ? null
                      : serialController.text,
                  brand: brandController.text.isEmpty
                      ? null
                      : brandController.text,
                  model: modelController.text.isEmpty
                      ? null
                      : modelController.text,
                  createdAt: asset?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                if (isEditing) {
                  await ref.read(assetsProvider.notifier).updateAsset(newAsset);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Activo actualizado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  final created = await ref
                      .read(assetsProvider.notifier)
                      .createAsset(newAsset);
                  if (mounted && created != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Activo creado exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceDialog(Asset asset) {
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    final performedByController = TextEditingController();
    String maintenanceType = 'preventivo';
    DateTime maintenanceDate = DateTime.now();
    DateTime? nextMaintenanceDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Mantenimiento - ${asset.name}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: maintenanceType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de mantenimiento',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'preventivo',
                        child: Text('Preventivo'),
                      ),
                      DropdownMenuItem(
                        value: 'correctivo',
                        child: Text('Correctivo'),
                      ),
                      DropdownMenuItem(
                        value: 'emergencia',
                        child: Text('Emergencia'),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => maintenanceType = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del trabajo *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costController,
                          decoration: const InputDecoration(
                            labelText: 'Costo',
                            border: OutlineInputBorder(),
                            prefixText: '\$ ',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: performedByController,
                          decoration: const InputDecoration(
                            labelText: 'Realizado por',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Próximo mantenimiento'),
                    subtitle: Text(
                      nextMaintenanceDate != null
                          ? '${nextMaintenanceDate!.day}/${nextMaintenanceDate!.month}/${nextMaintenanceDate!.year}'
                          : 'No programado',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 30),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (date != null) {
                        setDialogState(() => nextMaintenanceDate = date);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (descriptionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa la descripción del trabajo'),
                    ),
                  );
                  return;
                }

                final maintenance = AssetMaintenance(
                  id: '',
                  assetId: asset.id,
                  maintenanceDate: maintenanceDate,
                  maintenanceType: maintenanceType,
                  description: descriptionController.text,
                  cost: double.tryParse(costController.text) ?? 0,
                  performedBy: performedByController.text.isEmpty
                      ? null
                      : performedByController.text,
                  nextMaintenanceDate: nextMaintenanceDate,
                  createdAt: DateTime.now(),
                );

                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                final created = await ref
                    .read(assetsProvider.notifier)
                    .createMaintenance(maintenance);

                if (mounted && created != null) {
                  // Crear evento en calendario si hay fecha de próximo mantenimiento
                  if (nextMaintenanceDate != null) {
                    final activity = Activity(
                      id: '',
                      title: 'Mantenimiento: ${asset.name}',
                      description:
                          'Mantenimiento $maintenanceType programado para ${asset.name}.\n${descriptionController.text}',
                      activityType: ActivityType.maintenance,
                      startDate: nextMaintenanceDate!,
                      dueDate: nextMaintenanceDate,
                      status: ActivityStatus.pending,
                      priority: maintenanceType == 'emergencia'
                          ? ActivityPriority.urgent
                          : ActivityPriority.medium,
                      reminderEnabled: true,
                      reminderDate: nextMaintenanceDate!.subtract(
                        const Duration(days: 3),
                      ),
                      amount: double.tryParse(costController.text),
                      color: '#FF9800',
                      notes: performedByController.text.isNotEmpty
                          ? 'Responsable: ${performedByController.text}'
                          : null,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await ref
                        .read(activitiesProvider.notifier)
                        .createActivity(activity);
                  }

                  // Refrescar panel de detalle si está abierto
                  if (_selectedAsset?.id == asset.id) {
                    _selectAsset(asset);
                  }

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          nextMaintenanceDate != null
                              ? 'Mantenimiento registrado y agendado en calendario'
                              : 'Mantenimiento registrado',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Asset asset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar activo'),
        content: Text(
          '¿Estás seguro de eliminar "${asset.name}"?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final success = await ref
                  .read(assetsProvider.notifier)
                  .deleteAsset(asset.id);

              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Activo eliminado' : 'Error al eliminar',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
