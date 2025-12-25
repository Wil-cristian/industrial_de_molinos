import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/asset.dart';
import '../../data/providers/assets_provider.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/quick_actions_button.dart';

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
      body: Stack(
        children: [
          Row(
            children: [
              const AppSidebar(currentRoute: '/assets'),
              Expanded(
                child: Container(
                  color: AppTheme.backgroundColor,
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(context),
                      
                      // Content
                      Expanded(
                        child: state.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Stats Cards
                                    _buildStatsCards(state),
                                    const SizedBox(height: 20),
                                    
                                    // Filters
                                    _buildFilters(state),
                                    const SizedBox(height: 20),
                                    
                                    // Assets Grid
                                    _buildAssetsGrid(state),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const QuickActionsButton(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
            onPressed: () => context.go('/'),
            tooltip: 'Volver al menú',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activos Fijos e Inversiones',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  'Gestión de herramientas, maquinaria y equipos',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _showAddAssetDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo Activo'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(AssetsState state) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Activos',
            '${state.totalAssets}',
            Icons.business_center,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Valor Actual',
            'S/ ${Helpers.formatNumber(state.totalValue)}',
            Icons.account_balance,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Inversión Total',
            'S/ ${Helpers.formatNumber(state.totalInvestment)}',
            Icons.trending_up,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'En Mantenimiento',
            '${state.inMaintenance}',
            Icons.build,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
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
      child: Row(
        children: [
          Expanded(
            flex: 2,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: state.categoryFilter,
              decoration: InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'todas', child: Text('Todas')),
                DropdownMenuItem(value: 'maquinaria', child: Text('Maquinaria')),
                DropdownMenuItem(value: 'herramientas', child: Text('Herramientas')),
                DropdownMenuItem(value: 'equipos', child: Text('Equipos')),
                DropdownMenuItem(value: 'vehiculos', child: Text('Vehículos')),
                DropdownMenuItem(value: 'mobiliario', child: Text('Mobiliario')),
                DropdownMenuItem(value: 'otros', child: Text('Otros')),
              ],
              onChanged: (value) {
                ref.read(assetsProvider.notifier).filterByCategory(value ?? 'todas');
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: state.statusFilter,
              decoration: InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos')),
                DropdownMenuItem(value: 'activo', child: Text('Activo')),
                DropdownMenuItem(value: 'mantenimiento', child: Text('Mantenimiento')),
                DropdownMenuItem(value: 'baja', child: Text('Dado de Baja')),
                DropdownMenuItem(value: 'vendido', child: Text('Vendido')),
              ],
              onChanged: (value) {
                ref.read(assetsProvider.notifier).filterByStatus(value ?? 'todos');
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
              Icon(Icons.business_center_outlined, size: 64, color: Colors.grey[400]),
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: filteredAssets.length,
      itemBuilder: (context, index) {
        final asset = filteredAssets[index];
        return _buildAssetCard(asset);
      },
    );
  }

  Widget _buildAssetCard(Asset asset) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
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
                  const PopupMenuItem(value: 'maintenance', child: Text('Mantenimiento')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (asset.description != null)
            Text(
              asset.description!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                asset.status == 'activo' ? Icons.check_circle :
                asset.status == 'mantenimiento' ? Icons.build : Icons.cancel,
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
                'S/ ${Helpers.formatNumber(asset.currentValue)}',
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
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ========== DIÁLOGOS ==========

  void _showAddAssetDialog() {
    _showAssetDialog();
  }

  void _showEditAssetDialog(Asset asset) {
    _showAssetDialog(asset: asset);
  }

  void _showAssetDialog({Asset? asset}) {
    final isEditing = asset != null;
    final nameController = TextEditingController(text: asset?.name ?? '');
    final descriptionController = TextEditingController(text: asset?.description ?? '');
    final purchasePriceController = TextEditingController(
      text: asset?.purchasePrice.toString() ?? '',
    );
    final currentValueController = TextEditingController(
      text: asset?.currentValue.toString() ?? '',
    );
    final locationController = TextEditingController(text: asset?.location ?? '');
    final serialController = TextEditingController(text: asset?.serialNumber ?? '');
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
                            DropdownMenuItem(value: 'maquinaria', child: Text('Maquinaria')),
                            DropdownMenuItem(value: 'herramientas', child: Text('Herramientas')),
                            DropdownMenuItem(value: 'equipos', child: Text('Equipos')),
                            DropdownMenuItem(value: 'vehiculos', child: Text('Vehículos')),
                            DropdownMenuItem(value: 'mobiliario', child: Text('Mobiliario')),
                            DropdownMenuItem(value: 'otros', child: Text('Otros')),
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
                            prefixText: 'S/ ',
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
                            prefixText: 'S/ ',
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
                            DropdownMenuItem(value: 'activo', child: Text('Activo')),
                            DropdownMenuItem(value: 'mantenimiento', child: Text('Mantenimiento')),
                            DropdownMenuItem(value: 'baja', child: Text('Dado de Baja')),
                            DropdownMenuItem(value: 'vendido', child: Text('Vendido')),
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
                    const SnackBar(content: Text('Completa los campos obligatorios')),
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
                  purchasePrice: double.tryParse(purchasePriceController.text) ?? 0,
                  currentValue: double.tryParse(currentValueController.text) ?? 0,
                  status: selectedStatus,
                  location: locationController.text.isEmpty ? null : locationController.text,
                  serialNumber: serialController.text.isEmpty ? null : serialController.text,
                  brand: brandController.text.isEmpty ? null : brandController.text,
                  model: modelController.text.isEmpty ? null : modelController.text,
                  createdAt: asset?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                Navigator.pop(context);

                if (isEditing) {
                  await ref.read(assetsProvider.notifier).updateAsset(newAsset);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Activo actualizado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  final created = await ref.read(assetsProvider.notifier).createAsset(newAsset);
                  if (mounted && created != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
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
                      DropdownMenuItem(value: 'preventivo', child: Text('Preventivo')),
                      DropdownMenuItem(value: 'correctivo', child: Text('Correctivo')),
                      DropdownMenuItem(value: 'emergencia', child: Text('Emergencia')),
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
                            prefixText: 'S/ ',
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
                        initialDate: DateTime.now().add(const Duration(days: 30)),
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
                    const SnackBar(content: Text('Ingresa la descripción del trabajo')),
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

                Navigator.pop(context);

                final created = await ref.read(assetsProvider.notifier)
                    .createMaintenance(maintenance);
                
                if (mounted && created != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mantenimiento registrado'),
                      backgroundColor: Colors.green,
                    ),
                  );
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
        content: Text('¿Estás seguro de eliminar "${asset.name}"?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(assetsProvider.notifier)
                  .deleteAsset(asset.id);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success 
                        ? 'Activo eliminado' 
                        : 'Error al eliminar'),
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
