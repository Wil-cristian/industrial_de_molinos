import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/colombia_time.dart';
import '../../data/datasources/customers_datasource.dart';
import '../../data/datasources/drivers_datasource.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/driver.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/shipment_order.dart';
import 'shipment_print_preview.dart';

/// Dialog para crear o editar una remisión / orden de envío.
class ShipmentFormDialog extends StatefulWidget {
  final ShipmentOrder? existingShipment;
  final String? initialInvoiceId;
  final String? initialProductionOrderId;
  final String? initialCustomerName;
  final String? initialInvoiceNumber;
  final List<ShipmentOrderItem>? initialItems;
  final Future<void> Function(ShipmentOrder order) onSave;

  const ShipmentFormDialog({
    super.key,
    this.existingShipment,
    this.initialInvoiceId,
    this.initialProductionOrderId,
    this.initialCustomerName,
    this.initialInvoiceNumber,
    this.initialItems,
    required this.onSave,
  });

  @override
  State<ShipmentFormDialog> createState() => _ShipmentFormDialogState();
}

class _ShipmentFormDialogState extends State<ShipmentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Clientes
  List<Customer> _customers = [];
  String? _selectedCustomerId;

  // Factura asociada
  String? _selectedInvoiceId;
  String? _selectedInvoiceNumber;

  // Conductores
  List<Driver> _allDrivers = [];
  bool _loadingDrivers = true;

  // Cliente
  late TextEditingController _customerNameCtrl;
  late TextEditingController _customerAddressCtrl;
  late TextEditingController _customerDocCtrl;
  late TextEditingController _customerPhoneCtrl;

  // Transporte
  late TextEditingController _carrierNameCtrl;
  late TextEditingController _carrierDocCtrl;
  late TextEditingController _vehiclePlateCtrl;
  late TextEditingController _driverNameCtrl;
  late TextEditingController _driverDocCtrl;

  // Notas
  late TextEditingController _notesCtrl;
  late TextEditingController _internalNotesCtrl;

  // Firmas
  late TextEditingController _preparedByCtrl;
  late TextEditingController _approvedByCtrl;

  // Fechas
  late DateTime _dispatchDate;
  DateTime? _deliveryDate;

  // Ítems
  List<_ItemEntry> _items = [];

  bool get _isEditing => widget.existingShipment != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existingShipment;

    _selectedCustomerId = s?.customerId;
    _selectedInvoiceId = s?.invoiceId ?? widget.initialInvoiceId;
    _selectedInvoiceNumber = s?.invoiceFullNumber ?? widget.initialInvoiceNumber;
    _customerNameCtrl = TextEditingController(
      text: s?.customerName ?? widget.initialCustomerName ?? '',
    );
    _customerAddressCtrl = TextEditingController(
      text: s?.customerAddress ?? '',
    );
    _customerDocCtrl = TextEditingController();
    _customerPhoneCtrl = TextEditingController();
    _carrierNameCtrl = TextEditingController(text: s?.carrierName ?? '');
    _carrierDocCtrl = TextEditingController(text: s?.carrierDocument ?? '');
    _vehiclePlateCtrl = TextEditingController(text: s?.vehiclePlate ?? '');
    _driverNameCtrl = TextEditingController(text: s?.driverName ?? '');
    _driverDocCtrl = TextEditingController(text: s?.driverDocument ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _internalNotesCtrl = TextEditingController(text: s?.internalNotes ?? '');
    _preparedByCtrl = TextEditingController(text: s?.preparedBy ?? '');
    _approvedByCtrl = TextEditingController(text: s?.approvedBy ?? '');
    _dispatchDate = s?.dispatchDate ?? ColombiaTime.now();
    _deliveryDate = s?.deliveryDate;

    if (s != null && s.items.isNotEmpty) {
      _items = s.items.map((i) => _ItemEntry.fromShipmentItem(i)).toList();
    } else if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      _items = widget.initialItems!
          .map((i) => _ItemEntry.fromShipmentItem(i))
          .toList();
    }

    _loadCustomers();
    _loadDrivers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await CustomersDataSource.getAll();
      if (mounted) {
        setState(() {
          _customers = customers;
        });
        // Si ya hay customerId, rellenar doc y phone
        if (_selectedCustomerId != null) {
          final match = customers.where((c) => c.id == _selectedCustomerId);
          if (match.isNotEmpty) {
            final c = match.first;
            _customerDocCtrl.text =
                '${c.documentType.displayName}: ${c.documentNumber}';
            _customerPhoneCtrl.text = c.phone ?? '';
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadDrivers() async {
    try {
      final drivers = await DriversDataSource.getAll();
      if (mounted) {
        setState(() {
          _allDrivers = drivers;
          _loadingDrivers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDrivers = false);
    }
  }

  void _onDriverSelected(Driver d) {
    setState(() {
      _driverNameCtrl.text = d.name;
      _driverDocCtrl.text = d.document;
      _vehiclePlateCtrl.text = d.vehiclePlate ?? '';
      _carrierNameCtrl.text = d.carrierCompany ?? '';
    });
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerAddressCtrl.dispose();
    _customerDocCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _carrierNameCtrl.dispose();
    _carrierDocCtrl.dispose();
    _vehiclePlateCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverDocCtrl.dispose();
    _notesCtrl.dispose();
    _internalNotesCtrl.dispose();
    _preparedByCtrl.dispose();
    _approvedByCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;
    final dialogWidth = isCompact
        ? MediaQuery.sizeOf(context).width * 0.95
        : 750.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing
                          ? 'Editar Remisión ${widget.existingShipment!.code}'
                          : 'Nueva Remisión',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // — Ítems (PRIMERO) —
                      Row(
                        children: [
                          _sectionTitle('Ítems del Envío'),
                          if (_items.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _items.every((i) => i.checked)
                                    ? const Color(0xFF43A047).withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_items.where((i) => i.checked).length}/${_items.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _items.every((i) => i.checked)
                                      ? const Color(0xFF43A047)
                                      : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (isCompact) ...[
                            IconButton(
                              onPressed: _loadFromInvoices,
                              icon: const Icon(Icons.receipt_long, size: 20),
                              tooltip: 'Cargar desde Factura',
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add_circle, size: 20),
                              tooltip: 'Agregar ítem',
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ] else ...[
                            TextButton.icon(
                              onPressed: _loadFromInvoices,
                              icon: const Icon(Icons.receipt_long, size: 18),
                              label: const Text('Cargar desde Factura'),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Agregar'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._items.asMap().entries.map(
                        (entry) => _buildItemRow(entry.key, entry.value),
                      ),
                      if (_items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Sin ítems. Presiona "Cargar desde Factura" o "Agregar".',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ),
                        ),

                      // — Factura asociada (informativo) —
                      if (_selectedInvoiceId != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long, color: Color(0xFF1565C0), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Factura asociada: ${_selectedInvoiceNumber ?? _selectedInvoiceId}',
                                  style: const TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                tooltip: 'Desasociar factura',
                                onPressed: () {
                                  setState(() {
                                    _selectedInvoiceId = null;
                                    _selectedInvoiceNumber = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      // — Cliente (auto-llenado desde factura) —
                      _sectionTitle('Datos del Destinatario'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        _customerNameCtrl,
                        'Nombre del Cliente *',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      if (isCompact)
                        Column(
                          children: [
                            _buildTextField(
                              _customerDocCtrl,
                              'NIT / CC del Cliente',
                              readOnly: true,
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              _customerPhoneCtrl,
                              'Teléfono del Cliente',
                              readOnly: true,
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                _customerDocCtrl,
                                'NIT / CC del Cliente',
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                _customerPhoneCtrl,
                                'Teléfono del Cliente',
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        _customerAddressCtrl,
                        'Dirección de entrega',
                      ),
                      const SizedBox(height: 10),
                      // Fechas
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              'Fecha de despacho',
                              _dispatchDate,
                              (d) => setState(() => _dispatchDate = d),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              'Fecha entrega estimada',
                              _deliveryDate,
                              (d) => setState(() => _deliveryDate = d),
                              optional: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      // — Transporte —
                      _sectionTitle('Datos de Transporte'),
                      const SizedBox(height: 8),
                      // Selector de conductor con búsqueda
                      _loadingDrivers
                          ? const LinearProgressIndicator()
                          : _allDrivers.isEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey[50],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No hay conductores guardados. Agrega conductores en Clientes → Conductores.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Autocomplete<Driver>(
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return _allDrivers;
                                }
                                final q = textEditingValue.text.toLowerCase();
                                return _allDrivers.where(
                                  (d) =>
                                      d.name.toLowerCase().contains(q) ||
                                      d.document.contains(q) ||
                                      (d.vehiclePlate?.toLowerCase().contains(
                                            q,
                                          ) ??
                                          false) ||
                                      (d.carrierCompany?.toLowerCase().contains(
                                            q,
                                          ) ??
                                          false),
                                );
                              },
                              displayStringForOption: (d) =>
                                  '${d.name} - CC: ${d.document}',
                              onSelected: _onDriverSelected,
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText: 'Buscar conductor guardado',
                                        prefixIcon: Icon(
                                          Icons.search,
                                          size: 20,
                                        ),
                                        suffixIcon: Icon(
                                          Icons.directions_car,
                                          size: 20,
                                        ),
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        isDense: true,
                                        hintText: 'Nombre, CC o placa...',
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                    );
                                  },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4,
                                        borderRadius: BorderRadius.circular(8),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 220,
                                            maxWidth: 500,
                                          ),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (ctx, i) {
                                              final d = options.elementAt(i);
                                              return ListTile(
                                                dense: true,
                                                leading: const CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: Color(
                                                    0x181565C0,
                                                  ),
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 18,
                                                    color: Color(0xFF1565C0),
                                                  ),
                                                ),
                                                title: Text(
                                                  d.name,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  [
                                                    'CC: ${d.document}',
                                                    if (d.vehiclePlate !=
                                                            null &&
                                                        d
                                                            .vehiclePlate!
                                                            .isNotEmpty)
                                                      'Placa: ${d.vehiclePlate}',
                                                    if (d.carrierCompany !=
                                                            null &&
                                                        d
                                                            .carrierCompany!
                                                            .isNotEmpty)
                                                      d.carrierCompany!,
                                                  ].join('  •  '),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                onTap: () => onSelected(d),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                      if (_allDrivers.isNotEmpty) const SizedBox(height: 10),
                      if (isCompact)
                        Column(
                          children: [
                            _buildTextField(
                              _carrierNameCtrl,
                              'Transportista / Empresa',
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              _carrierDocCtrl,
                              'NIT / CC Transportista',
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              _vehiclePlateCtrl,
                              'Placa del Vehículo',
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(_driverNameCtrl, 'Conductor'),
                            const SizedBox(height: 10),
                            _buildTextField(_driverDocCtrl, 'CC Conductor'),
                          ],
                        )
                      else
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    _carrierNameCtrl,
                                    'Transportista / Empresa',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    _carrierDocCtrl,
                                    'NIT / CC',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    _vehiclePlateCtrl,
                                    'Placa',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    _driverNameCtrl,
                                    'Conductor',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    _driverDocCtrl,
                                    'CC Conductor',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                      const SizedBox(height: 20),
                      // — Notas y Firmas —
                      _sectionTitle('Notas y Firmas'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        _notesCtrl,
                        'Observaciones (se imprimen)',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        _internalNotesCtrl,
                        'Notas internas (no se imprimen)',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _preparedByCtrl,
                              'Preparado por',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              _approvedByCtrl,
                              'Aprobado por',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  if (isCompact)
                    IconButton(
                      onPressed: _isSaving
                          ? null
                          : () => _save(printAfter: true),
                      icon: const Icon(Icons.print, size: 20),
                      tooltip: 'Guardar e Imprimir',
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _save(printAfter: true),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Guardar e Imprimir'),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isEditing ? 'Actualizar' : 'Guardar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1565C0),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? value,
    void Function(DateTime) onPicked, {
    bool optional = false,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? ColombiaTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
          locale: const Locale('es', 'CO'),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(
          value != null
              ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
              : optional
              ? 'Sin fecha'
              : 'Seleccionar',
          style: TextStyle(
            fontSize: 13,
            color: value != null ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }

  // ── Cargar desde Facturas ──
  Future<void> _loadFromInvoices() async {
    // Step 1: Fetch invoices
    List<Invoice>? invoices;
    try {
      invoices = await InvoicesDataSource.getAll();
      // Filter only issued/paid/partial (not cancelled/draft)
      invoices = invoices
          .where(
            (inv) =>
                inv.status != InvoiceStatus.cancelled &&
                inv.status != InvoiceStatus.draft &&
                inv.items.isNotEmpty,
          )
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando facturas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (invoices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay facturas con ítems disponibles'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Step 2: Show invoice selection dialog
    final selectedInvoices = await showDialog<List<Invoice>>(
      context: context,
      builder: (ctx) => _InvoiceSelectionDialog(invoices: invoices!),
    );

    if (selectedInvoices == null || selectedInvoices.isEmpty) return;
    if (!mounted) return;

    // Step 3: Collect items from selected invoices
    final allItems = <_InvoiceItemEntry>[];
    for (final inv in selectedInvoices) {
      for (final item in inv.items) {
        allItems.add(_InvoiceItemEntry(invoice: inv, item: item));
      }
    }

    // Step 4: Show item selection dialog
    final selectedItems = await showDialog<List<_InvoiceItemEntry>>(
      context: context,
      builder: (ctx) => _InvoiceItemSelectionDialog(items: allItems),
    );

    if (selectedItems == null || selectedItems.isEmpty) return;

    // Step 5: Save linked invoice (first selected)
    // Nota: shipment_orders solo soporta 1 invoice_id.
    // Si se seleccionaron múltiples facturas, alertar al usuario.
    final firstInvoice = selectedInvoices.first;
    _selectedInvoiceId = firstInvoice.id;
    _selectedInvoiceNumber = '${firstInvoice.series}-${firstInvoice.number}';

    if (selectedInvoices.length > 1 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se seleccionaron ${selectedInvoices.length} facturas. '
            'Solo ${firstInvoice.series}-${firstInvoice.number} quedará asociada como factura principal.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // Step 5b: Auto-fill customer from first selected invoice
    if (_customerNameCtrl.text.trim().isEmpty) {
      // Find matching customer to get full data
      final match = _customers.where(
        (c) => c.name == firstInvoice.customerName,
      );
      if (match.isNotEmpty) {
        final c = match.first;
        _selectedCustomerId = c.id;
        _customerNameCtrl.text = c.name;
        _customerAddressCtrl.text = c.address ?? '';
        _customerDocCtrl.text =
            '${c.documentType.displayName}: ${c.documentNumber}';
        _customerPhoneCtrl.text = c.phone ?? '';
      } else {
        _customerNameCtrl.text = firstInvoice.customerName;
        _customerDocCtrl.text = firstInvoice.customerDocument;
      }
    }

    // Step 6: Convert to _ItemEntry and add
    setState(() {
      for (final entry in selectedItems) {
        final inv = entry.item;
        _items.add(
          _ItemEntry(
            type: inv.materialId != null
                ? ShipmentItemType.material
                : ShipmentItemType.producto,
            desc: inv.productName,
            qty: inv.quantity.toStringAsFixed(
              inv.quantity == inv.quantity.roundToDouble() ? 0 : 2,
            ),
            unit: inv.unit,
          ),
        );
      }
    });
  }

  // ── Ítems ──
  void _addItem() {
    setState(() {
      _items.add(_ItemEntry());
    });
  }

  Widget _buildItemRow(int index, _ItemEntry item) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: item.checked
            ? const Color(0xFF43A047).withOpacity(0.06)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.checked
              ? const Color(0xFF43A047).withOpacity(0.4)
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: item.checked,
                  onChanged: (v) {
                    setState(() => item.checked = v ?? false);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: const Color(0xFF43A047),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.checked
                      ? const Color(0xFF43A047)
                      : const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: item.checked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              // Tipo
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<ShipmentItemType>(
                  value: item.type,
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    isDense: true,
                    labelText: 'Tipo',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  items: ShipmentItemType.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            _itemTypeLabel(t),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => item.type = v);
                  },
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    _items[index].dispose();
                    _items.removeAt(index);
                  });
                },
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                tooltip: 'Eliminar',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isCompact)
            Column(
              children: [
                TextFormField(
                  controller: item.descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: item.qtyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cant.',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        controller: item.unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unid.',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        controller: item.weightCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Peso kg',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: item.descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    controller: item.qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cant.',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    controller: item.unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Und',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: item.weightCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Peso kg',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: item.dimensionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dimensiones',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _itemTypeLabel(ShipmentItemType t) {
    switch (t) {
      case ShipmentItemType.producto:
        return 'Producto';
      case ShipmentItemType.material:
        return 'Material';
      case ShipmentItemType.pieza:
        return 'Pieza';
      case ShipmentItemType.herramienta:
        return 'Herramienta';
      case ShipmentItemType.otro:
        return 'Otro';
    }
  }

  Future<void> _save({bool printAfter = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ítem'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final shipmentItems = _items.asMap().entries.map((entry) {
      final item = entry.value;
      return ShipmentOrderItem(
        id: '',
        shipmentOrderId: '',
        itemType: item.type,
        description: item.descCtrl.text.trim(),
        quantity: double.tryParse(item.qtyCtrl.text) ?? 1,
        unit: item.unitCtrl.text.trim().isEmpty
            ? 'UND'
            : item.unitCtrl.text.trim(),
        weightKg: double.tryParse(item.weightCtrl.text),
        dimensions: item.dimensionsCtrl.text.trim().isEmpty
            ? null
            : item.dimensionsCtrl.text.trim(),
        sequenceOrder: entry.key,
      );
    }).toList();

    final order = ShipmentOrder(
      id: widget.existingShipment?.id ?? '',
      code: widget.existingShipment?.code ?? '',
      invoiceId: _selectedInvoiceId,
      productionOrderId:
          widget.existingShipment?.productionOrderId ??
          widget.initialProductionOrderId,
      customerId: _selectedCustomerId,
      customerName: _customerNameCtrl.text.trim(),
      customerAddress: _customerAddressCtrl.text.trim().isEmpty
          ? null
          : _customerAddressCtrl.text.trim(),
      customerPhone: _customerPhoneCtrl.text.trim().isEmpty
          ? null
          : _customerPhoneCtrl.text.trim(),
      carrierName: _carrierNameCtrl.text.trim().isEmpty
          ? null
          : _carrierNameCtrl.text.trim(),
      carrierDocument: _carrierDocCtrl.text.trim().isEmpty
          ? null
          : _carrierDocCtrl.text.trim(),
      vehiclePlate: _vehiclePlateCtrl.text.trim().isEmpty
          ? null
          : _vehiclePlateCtrl.text.trim(),
      driverName: _driverNameCtrl.text.trim().isEmpty
          ? null
          : _driverNameCtrl.text.trim(),
      driverDocument: _driverDocCtrl.text.trim().isEmpty
          ? null
          : _driverDocCtrl.text.trim(),
      dispatchDate: _dispatchDate,
      deliveryDate: _deliveryDate,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      internalNotes: _internalNotesCtrl.text.trim().isEmpty
          ? null
          : _internalNotesCtrl.text.trim(),
      preparedBy: _preparedByCtrl.text.trim().isEmpty
          ? null
          : _preparedByCtrl.text.trim(),
      approvedBy: _approvedByCtrl.text.trim().isEmpty
          ? null
          : _approvedByCtrl.text.trim(),
      items: shipmentItems,
      createdAt: widget.existingShipment?.createdAt ?? ColombiaTime.now(),
      updatedAt: ColombiaTime.now(),
    );

    try {
      await widget.onSave(order);
      if (mounted) Navigator.pop(context);
      if (printAfter) {
        ShipmentPrintService.printShipment(order);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

/// Modelo auxiliar para un ítem en el formulario
class _ItemEntry {
  ShipmentItemType type;
  bool checked = false;
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController dimensionsCtrl;

  _ItemEntry({
    this.type = ShipmentItemType.producto,
    String desc = '',
    String qty = '1',
    String unit = 'UND',
    String weight = '',
    String dimensions = '',
  }) : descCtrl = TextEditingController(text: desc),
       qtyCtrl = TextEditingController(text: qty),
       unitCtrl = TextEditingController(text: unit),
       weightCtrl = TextEditingController(text: weight),
       dimensionsCtrl = TextEditingController(text: dimensions);

  factory _ItemEntry.fromShipmentItem(ShipmentOrderItem item) {
    return _ItemEntry(
      type: item.itemType,
      desc: item.description,
      qty: item.quantity.toStringAsFixed(
        item.quantity == item.quantity.roundToDouble() ? 0 : 2,
      ),
      unit: item.unit,
      weight: item.weightKg != null ? item.weightKg.toString() : '',
      dimensions: item.dimensions ?? '',
    );
  }

  void dispose() {
    descCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    weightCtrl.dispose();
    dimensionsCtrl.dispose();
  }
}

/// Wrapper to track invoice item + its parent invoice
class _InvoiceItemEntry {
  final Invoice invoice;
  final InvoiceItem item;
  const _InvoiceItemEntry({required this.invoice, required this.item});
}

// ─────────────────────────────────────────────────────────
//  Dialog: Selección de Facturas (multi-select)
// ─────────────────────────────────────────────────────────
class _InvoiceSelectionDialog extends StatefulWidget {
  final List<Invoice> invoices;
  const _InvoiceSelectionDialog({required this.invoices});

  @override
  State<_InvoiceSelectionDialog> createState() =>
      _InvoiceSelectionDialogState();
}

class _InvoiceSelectionDialogState extends State<_InvoiceSelectionDialog> {
  final Set<String> _selected = {};
  String _search = '';

  List<Invoice> get _filtered {
    if (_search.isEmpty) return widget.invoices;
    final q = _search.toLowerCase();
    return widget.invoices.where((inv) {
      return inv.customerName.toLowerCase().contains(q) ||
          '${inv.series}-${inv.number}'.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 700;
    final fmt = NumberFormat('#,##0.00', 'es_CO');

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isCompact ? width * 0.95 : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Seleccionar Facturas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar por cliente o número...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            // List
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron facturas',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final inv = _filtered[i];
                        final checked = _selected.contains(inv.id);
                        final dateStr =
                            '${inv.issueDate.day.toString().padLeft(2, '0')}/${inv.issueDate.month.toString().padLeft(2, '0')}/${inv.issueDate.year}';
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(inv.id);
                              } else {
                                _selected.remove(inv.id);
                              }
                            });
                          },
                          title: Text(
                            '${inv.series}-${inv.number}  •  ${inv.customerName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '$dateStr  •  \$${fmt.format(inv.total)}  •  ${inv.items.length} ítems',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selected.length} seleccionada(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            final result = widget.invoices
                                .where((inv) => _selected.contains(inv.id))
                                .toList();
                            Navigator.pop(context, result);
                          },
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Dialog: Selección de Ítems de Facturas (multi-select)
// ─────────────────────────────────────────────────────────
class _InvoiceItemSelectionDialog extends StatefulWidget {
  final List<_InvoiceItemEntry> items;
  const _InvoiceItemSelectionDialog({required this.items});

  @override
  State<_InvoiceItemSelectionDialog> createState() =>
      _InvoiceItemSelectionDialogState();
}

class _InvoiceItemSelectionDialogState
    extends State<_InvoiceItemSelectionDialog> {
  late final Set<int> _selected;

  @override
  void initState() {
    super.initState();
    // All selected by default
    _selected = Set<int>.from(List.generate(widget.items.length, (i) => i));
  }

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selected.addAll(List.generate(widget.items.length, (i) => i));
      } else {
        _selected.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 700;
    final fmt = NumberFormat('#,##0.00', 'es_CO');

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isCompact ? width * 0.95 : 650,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.checklist, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Seleccionar Ítems',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Select All
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: CheckboxListTile(
                dense: true,
                title: Text(
                  'Seleccionar todos (${widget.items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: _selected.length == widget.items.length,
                tristate: true,
                onChanged: _toggleAll,
              ),
            ),
            const Divider(height: 1),
            // Items list
            Expanded(
              child: ListView.builder(
                itemCount: widget.items.length,
                itemBuilder: (ctx, i) {
                  final entry = widget.items[i];
                  final inv = entry.invoice;
                  final item = entry.item;
                  final checked = _selected.contains(i);

                  return CheckboxListTile(
                    dense: true,
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(i);
                        } else {
                          _selected.remove(i);
                        }
                      });
                    },
                    title: Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Cant: ${item.quantity}  •  ${item.unit}  •  \$${fmt.format(item.unitPrice)}  •  Fact: ${inv.series}-${inv.number}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_selected.length} de ${widget.items.length} ítems',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            final result = _selected
                                .map((i) => widget.items[i])
                                .toList();
                            Navigator.pop(context, result);
                          },
                    child: const Text('Agregar Ítems'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
