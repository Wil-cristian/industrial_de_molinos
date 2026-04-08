import 'package:flutter/material.dart';

import '../../domain/entities/shipment_order.dart';

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

  // Cliente
  late TextEditingController _customerNameCtrl;
  late TextEditingController _customerAddressCtrl;

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

    _customerNameCtrl = TextEditingController(
      text: s?.customerName ?? widget.initialCustomerName ?? '',
    );
    _customerAddressCtrl = TextEditingController(
      text: s?.customerAddress ?? '',
    );
    _carrierNameCtrl = TextEditingController(text: s?.carrierName ?? '');
    _carrierDocCtrl = TextEditingController(text: s?.carrierDocument ?? '');
    _vehiclePlateCtrl = TextEditingController(text: s?.vehiclePlate ?? '');
    _driverNameCtrl = TextEditingController(text: s?.driverName ?? '');
    _driverDocCtrl = TextEditingController(text: s?.driverDocument ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _internalNotesCtrl = TextEditingController(text: s?.internalNotes ?? '');
    _preparedByCtrl = TextEditingController(text: s?.preparedBy ?? '');
    _approvedByCtrl = TextEditingController(text: s?.approvedBy ?? '');
    _dispatchDate = s?.dispatchDate ?? DateTime.now();
    _deliveryDate = s?.deliveryDate;

    if (s != null && s.items.isNotEmpty) {
      _items = s.items.map((i) => _ItemEntry.fromShipmentItem(i)).toList();
    } else if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      _items = widget.initialItems!
          .map((i) => _ItemEntry.fromShipmentItem(i))
          .toList();
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerAddressCtrl.dispose();
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
                      // — Cliente —
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
                      // — Ítems —
                      Row(
                        children: [
                          _sectionTitle('Ítems del Envío'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Agregar'),
                          ),
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
                              'Sin ítems. Presiona "Agregar" para añadir elementos.',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ),
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
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
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
          initialDate: value ?? DateTime.now(),
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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

  Future<void> _save() async {
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
      invoiceId: widget.existingShipment?.invoiceId ?? widget.initialInvoiceId,
      productionOrderId:
          widget.existingShipment?.productionOrderId ??
          widget.initialProductionOrderId,
      customerName: _customerNameCtrl.text.trim(),
      customerAddress: _customerAddressCtrl.text.trim().isEmpty
          ? null
          : _customerAddressCtrl.text.trim(),
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
      createdAt: widget.existingShipment?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await widget.onSave(order);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

/// Modelo auxiliar para un ítem en el formulario
class _ItemEntry {
  ShipmentItemType type;
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
