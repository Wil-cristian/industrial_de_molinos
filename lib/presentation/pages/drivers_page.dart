import 'package:flutter/material.dart';

import '../../data/datasources/drivers_datasource.dart';
import '../../domain/entities/driver.dart';
import '../../core/utils/colombia_time.dart';

/// Pestaña de Conductores dentro de la página de Clientes
class DriversPage extends StatefulWidget {
  const DriversPage({super.key});

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage>
    with AutomaticKeepAliveClientMixin {
  List<Driver> _drivers = [];
  bool _loading = true;
  String _search = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final drivers = await DriversDataSource.getAll();
      if (mounted) setState(() => _drivers = drivers);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando conductores: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Driver> get _filtered {
    if (_search.isEmpty) return _drivers;
    final q = _search.toLowerCase();
    return _drivers.where((d) {
      return d.name.toLowerCase().contains(q) ||
          d.document.toLowerCase().contains(q) ||
          (d.vehiclePlate?.toLowerCase().contains(q) ?? false) ||
          (d.carrierCompany?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar conductor...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showDriverDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo'),
              ),
            ],
          ),
        ),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _statChip(
                Icons.directions_car,
                '${_drivers.length} conductores',
                cs.primary,
              ),
              const SizedBox(width: 8),
              _statChip(
                Icons.filter_list,
                '${_filtered.length} filtrados',
                Colors.grey,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _search.isNotEmpty
                                ? 'Sin resultados'
                                : 'No hay conductores registrados',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (ctx, i) =>
                            _buildDriverTile(_filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverTile(Driver driver) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
          child: const Icon(Icons.person, size: 20, color: Color(0xFF1565C0)),
        ),
        title: Text(
          driver.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(
          [
            'CC: ${driver.document}',
            if (driver.vehiclePlate != null && driver.vehiclePlate!.isNotEmpty)
              'Placa: ${driver.vehiclePlate}',
            if (driver.carrierCompany != null &&
                driver.carrierCompany!.isNotEmpty)
              driver.carrierCompany!,
          ].join('  •  '),
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              _showDriverDialog(driver: driver);
            } else if (action == 'delete') {
              _confirmDelete(driver);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverDialog({Driver? driver}) {
    final nameCtrl = TextEditingController(text: driver?.name ?? '');
    final docCtrl = TextEditingController(text: driver?.document ?? '');
    final phoneCtrl = TextEditingController(text: driver?.phone ?? '');
    final plateCtrl = TextEditingController(text: driver?.vehiclePlate ?? '');
    final companyCtrl =
        TextEditingController(text: driver?.carrierCompany ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          driver == null ? 'Nuevo Conductor' : 'Editar Conductor',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person, size: 18),
                    ),
                    style: const TextStyle(fontSize: 13),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: docCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cédula (CC) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.badge, size: 18),
                    ),
                    style: const TextStyle(fontSize: 13),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.phone, size: 18),
                    ),
                    style: const TextStyle(fontSize: 13),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: plateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Placa del Vehículo',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.directions_car, size: 18),
                    ),
                    style: const TextStyle(fontSize: 13),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: companyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Empresa Transportista',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.business, size: 18),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                final newDriver = Driver(
                  id: driver?.id ?? '',
                  name: nameCtrl.text.trim(),
                  document: docCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  vehiclePlate: plateCtrl.text.trim().isEmpty
                      ? null
                      : plateCtrl.text.trim().toUpperCase(),
                  carrierCompany: companyCtrl.text.trim().isEmpty
                      ? null
                      : companyCtrl.text.trim(),
                  createdAt: driver?.createdAt ?? ColombiaTime.now(),
                  updatedAt: ColombiaTime.now(),
                );
                if (driver == null) {
                  await DriversDataSource.create(newDriver);
                } else {
                  await DriversDataSource.update(newDriver);
                }
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(driver == null
                          ? 'Conductor creado'
                          : 'Conductor actualizado'),
                      backgroundColor: const Color(0xFF43A047),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(driver == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Driver driver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Conductor'),
        content: Text('¿Eliminar a ${driver.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await DriversDataSource.delete(driver.id);
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conductor eliminado'),
                      backgroundColor: Color(0xFF43A047),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
