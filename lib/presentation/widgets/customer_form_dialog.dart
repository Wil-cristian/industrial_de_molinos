import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/customers_provider.dart';
import '../../domain/entities/customer.dart';

/// Diálogo reutilizable para crear o editar un Cliente.
/// Retorna el Customer creado/editado, o null si se canceló.
class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? initial;
  final String? suggestedName;
  final String? suggestedDocNumber;
  final DocumentType? suggestedDocType;
  final CustomerType? suggestedType;
  final String? suggestedTradeName;
  final String? suggestedPhone;
  final String? suggestedEmail;
  final String? suggestedAddress;

  /// Si true, muestra un banner "datos pre-llenados desde escaneo"
  final bool showScanBanner;

  const CustomerFormDialog({
    super.key,
    this.initial,
    this.suggestedName,
    this.suggestedDocNumber,
    this.suggestedDocType,
    this.suggestedType,
    this.suggestedTradeName,
    this.suggestedPhone,
    this.suggestedEmail,
    this.suggestedAddress,
    this.showScanBanner = false,
  });

  static Future<Customer?> show(
    BuildContext context, {
    Customer? initial,
    String? suggestedName,
    String? suggestedDocNumber,
    DocumentType? suggestedDocType,
    CustomerType? suggestedType,
    String? suggestedTradeName,
    String? suggestedPhone,
    String? suggestedEmail,
    String? suggestedAddress,
    bool showScanBanner = false,
  }) {
    return showDialog<Customer?>(
      context: context,
      builder: (_) => CustomerFormDialog(
        initial: initial,
        suggestedName: suggestedName,
        suggestedDocNumber: suggestedDocNumber,
        suggestedDocType: suggestedDocType,
        suggestedType: suggestedType,
        suggestedTradeName: suggestedTradeName,
        suggestedPhone: suggestedPhone,
        suggestedEmail: suggestedEmail,
        suggestedAddress: suggestedAddress,
        showScanBanner: showScanBanner,
      ),
    );
  }

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  static const _colombianDocTypes = [
    DocumentType.cc,
    DocumentType.nit,
    DocumentType.ce,
    DocumentType.pasaporte,
    DocumentType.ti,
  ];

  late final bool isEditing;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController nameCtrl;
  late final TextEditingController tradeNameCtrl;
  late final TextEditingController docNumberCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController creditLimitCtrl;
  late final TextEditingController currentBalanceCtrl;

  late CustomerType selectedType;
  late DocumentType selectedDocType;

  @override
  void initState() {
    super.initState();
    isEditing = widget.initial != null;
    final c = widget.initial;

    nameCtrl = TextEditingController(
      text: c?.name ?? widget.suggestedName ?? '',
    );
    tradeNameCtrl = TextEditingController(
      text: c?.tradeName ?? widget.suggestedTradeName ?? '',
    );
    docNumberCtrl = TextEditingController(
      text: c?.documentNumber ?? widget.suggestedDocNumber ?? '',
    );
    phoneCtrl = TextEditingController(
      text: c?.phone ?? widget.suggestedPhone ?? '',
    );
    emailCtrl = TextEditingController(
      text: c?.email ?? widget.suggestedEmail ?? '',
    );
    addressCtrl = TextEditingController(
      text: c?.address ?? widget.suggestedAddress ?? '',
    );
    creditLimitCtrl = TextEditingController(
      text: c?.creditLimit.toString() ?? '0',
    );
    currentBalanceCtrl = TextEditingController(
      text: c?.currentBalance.toString() ?? '0',
    );

    selectedType = c?.type ?? widget.suggestedType ?? CustomerType.business;
    selectedDocType = c != null
        ? c.documentType.normalized
        : (widget.suggestedDocType ?? DocumentType.nit);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    tradeNameCtrl.dispose();
    docNumberCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    creditLimitCtrl.dispose();
    currentBalanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      title: Text(
        isEditing ? 'Editar Cliente' : 'Nuevo Cliente',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showScanBanner) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: Color(0xFFF57C00),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Datos pre-llenados desde la factura escaneada.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Tipo de cliente
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<CustomerType>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Cliente',
                          border: OutlineInputBorder(),
                        ),
                        items: CustomerType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type == CustomerType.business
                                      ? 'Empresa'
                                      : 'Persona',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedType = value!;
                            selectedDocType = value == CustomerType.business
                                ? DocumentType.nit
                                : DocumentType.cc;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<DocumentType>(
                        value: selectedDocType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo Documento',
                          border: OutlineInputBorder(),
                        ),
                        items: _colombianDocTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedDocType = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: docNumberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de Documento',
                    border: OutlineInputBorder(),
                    helperText: 'Ingresa un número de documento válido',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Campo requerido';
                    if (value == '0') {
                      return 'Ingresa un número de documento válido (no puede ser 0)';
                    }
                    if (int.tryParse(value!) == null) {
                      return 'Debe ser un número válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre / Razón Social',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: tradeNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Comercial',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Límite de Crédito y Deuda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: creditLimitCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Límite de Crédito',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) return 'Campo requerido';
                          if (double.tryParse(value!) == null) {
                            return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: currentBalanceCtrl,
                        keyboardType: TextInputType.number,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Deuda Actual',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.money_off),
                          helperText: 'Calculado desde facturas',
                          filled: true,
                          fillColor: Color(0xFFF5F5F5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _onSave,
          child: Text(isEditing ? 'Actualizar' : 'Guardar'),
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final creditLimit = double.tryParse(creditLimitCtrl.text) ?? 0;
    final currentBalance = double.tryParse(currentBalanceCtrl.text) ?? 0;

    if (isEditing) {
      final updated = Customer(
        id: widget.initial!.id,
        type: selectedType,
        documentType: selectedDocType,
        documentNumber: docNumberCtrl.text,
        name: nameCtrl.text,
        tradeName: tradeNameCtrl.text.isNotEmpty ? tradeNameCtrl.text : null,
        phone: phoneCtrl.text.isNotEmpty ? phoneCtrl.text : null,
        email: emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
        address: addressCtrl.text.isNotEmpty ? addressCtrl.text : null,
        creditLimit: creditLimit,
        currentBalance: currentBalance,
        createdAt: widget.initial!.createdAt,
        updatedAt: DateTime.now(),
      );

      final result = await ref
          .read(customersProvider.notifier)
          .updateCustomer(updated);
      if (result && mounted) {
        Navigator.pop(context, updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente actualizado exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      final newCustomer = Customer(
        id: const Uuid().v4(),
        type: selectedType,
        documentType: selectedDocType,
        documentNumber: docNumberCtrl.text,
        name: nameCtrl.text,
        tradeName: tradeNameCtrl.text.isNotEmpty ? tradeNameCtrl.text : null,
        phone: phoneCtrl.text.isNotEmpty ? phoneCtrl.text : null,
        email: emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
        address: addressCtrl.text.isNotEmpty ? addressCtrl.text : null,
        creditLimit: creditLimit,
        currentBalance: currentBalance,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await ref
          .read(customersProvider.notifier)
          .createCustomer(newCustomer);
      if (result != null && mounted) {
        Navigator.pop(context, result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente creado exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        final error = ref.read(customersProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al crear cliente: ${error ?? "Error desconocido"}',
            ),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
