import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/helpers.dart';
import '../../core/utils/print_service.dart';
import '../../data/datasources/messenger_funds_datasource.dart';
import '../../data/providers/accounts_provider.dart';
import '../../data/providers/employees_provider.dart';
import '../../data/providers/messenger_funds_provider.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/messenger_fund.dart';

class MessengerFundsDialog extends ConsumerStatefulWidget {
  const MessengerFundsDialog({super.key});

  @override
  ConsumerState<MessengerFundsDialog> createState() =>
      _MessengerFundsDialogState();
}

class _MessengerFundsDialogState extends ConsumerState<MessengerFundsDialog> {
  String _searchQuery = '';
  String _statusFilter = 'abiertos';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(messengerFundsProvider.notifier).load();
      if (ref.read(employeesProvider).employees.isEmpty) {
        await ref.read(employeesProvider.notifier).loadEmployees(activeOnly: true);
      }
      if (ref.read(dailyCashProvider).accounts.isEmpty) {
        await ref.read(dailyCashProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fundsState = ref.watch(messengerFundsProvider);
    final accounts = ref.watch(dailyCashProvider).accounts;
    final reports = fundsState.messengerReports;
    final filteredFunds = fundsState.funds.where((fund) {
      final matchesStatus = switch (_statusFilter) {
        'abiertos' => fund.isOpen,
        'cerrados' => !fund.isOpen,
        _ => true,
      };
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          fund.employeeName.toLowerCase().contains(query) ||
          (fund.notes ?? '').toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(Icons.local_shipping, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fondos de Mensajería',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Entrega dinero al mensajero sin inflar la contabilidad. Solo se legaliza cuando trae soportes o devuelve saldo.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryCard(
                    title: 'Fondos Activos',
                    value: '${fundsState.openFunds.length}',
                    color: Colors.blue,
                    icon: Icons.account_balance_wallet,
                  ),
                  _SummaryCard(
                    title: 'Entregado',
                    value: Helpers.formatCurrency(fundsState.totalActiveGiven),
                    color: Colors.orange,
                    icon: Icons.outbox,
                  ),
                  _SummaryCard(
                    title: 'Legalizado',
                    value: Helpers.formatCurrency(fundsState.totalActiveSpent),
                    color: Colors.green,
                    icon: Icons.verified,
                  ),
                  _SummaryCard(
                    title: 'Pendiente',
                    value: Helpers.formatCurrency(fundsState.totalActivePending),
                    color: Colors.red,
                    icon: Icons.pending_actions,
                  ),
                ],
              ),
            ),
            if ((fundsState.error ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    fundsState.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: const InputDecoration(
                            hintText: 'Buscar mensajero o motivo...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => ref.read(messengerFundsProvider.notifier).load(),
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Recargar',
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: filteredFunds.isEmpty
                            ? null
                            : () => _exportReportPdf(filteredFunds, reports),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Exportar PDF'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: accounts.isEmpty ? null : _showCreateFundDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo Fondo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilterChip(
                        selected: _statusFilter == 'abiertos',
                        label: const Text('Abiertos'),
                        onSelected: (_) => setState(() => _statusFilter = 'abiertos'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _statusFilter == 'todos',
                        label: const Text('Todos'),
                        onSelected: (_) => setState(() => _statusFilter = 'todos'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        selected: _statusFilter == 'cerrados',
                        label: const Text('Cerrados'),
                        onSelected: (_) => setState(() => _statusFilter = 'cerrados'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (reports.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Resumen por mensajero',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 122,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) => _MessengerReportCard(report: reports[index]),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemCount: reports.length,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fondos ${_statusFilter == 'todos' ? 'registrados' : _statusFilter} • ${filteredFunds.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: fundsState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredFunds.isEmpty
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: Colors.black38),
                                SizedBox(height: 12),
                                Text('No hay fondos que coincidan con el filtro actual'),
                                SizedBox(height: 6),
                                Text(
                                  'Prueba con otro mensajero, cambia el filtro o crea un nuevo fondo.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            ...filteredFunds.map(
                              (fund) => _FundCard(
                                fund: fund,
                                onLegalize: () => _showLegalizeDialog(fund),
                                onCancel: fund.isOpen
                                    ? () => _confirmCancelFund(fund)
                                    : null,
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateFundDialog() async {
    final employees = ref.read(employeesProvider).employees;
    final accounts = ref.read(dailyCashProvider).accounts;

    Employee? selectedEmployee;
    Account? selectedAccount;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo Fondo de Mensajería'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Employee>(
                    value: selectedEmployee,
                    decoration: const InputDecoration(
                      labelText: 'Mensajero / Empleado',
                      border: OutlineInputBorder(),
                    ),
                    items: employees
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text('${e.fullName} • ${e.position}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedEmployee = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Account>(
                    value: selectedAccount,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta de salida',
                      border: OutlineInputBorder(),
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a,
                            child: Text('${a.name} • ${Helpers.formatCurrency(a.balance)}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => selectedAccount = value),
                  ),
                  if (selectedAccount != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Disponible en ${selectedAccount!.name}: ${Helpers.formatCurrency(selectedAccount!.balance)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto entregado',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas / propósito',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: Pago de facturas, compra de materiales, diligencias...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Este movimiento no se toma como gasto real hasta que el mensajero legalice con soportes o devuelva el sobrante.',
                          ),
                        ),
                      ],
                    ),
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
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                if (selectedEmployee == null || selectedAccount == null || amount <= 0) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Completa empleado, cuenta y monto')),
                  );
                  return;
                }
                if (notesController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Agrega el propósito o detalle del fondo')),
                  );
                  return;
                }
                if (amount > selectedAccount!.balance) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'El monto excede el saldo disponible en ${selectedAccount!.name}',
                      ),
                    ),
                  );
                  return;
                }

                final result = await ref.read(messengerFundsProvider.notifier).createFund(
                  employeeId: selectedEmployee!.id,
                  employeeName: selectedEmployee!.fullName,
                  amount: amount,
                  accountId: selectedAccount!.id,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                );

                if (!mounted) return;
                await ref.read(dailyCashProvider.notifier).load();
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result != null ? 'Fondo creado correctamente' : 'No se pudo crear el fondo',
                    ),
                  ),
                );
              },
              child: const Text('Crear Fondo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLegalizeDialog(MessengerFund fund) async {
    FundItemType selectedType = FundItemType.compra;
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final referenceController = TextEditingController();
    String selectedCategory = 'consumibles';
    final pendingInvoices = await MessengerFundsDataSource.getPendingInvoices();
    final pendingOrders = await MessengerFundsDataSource.getPendingPurchaseOrders();
    Invoice? selectedInvoice;
    PurchaseOrder? selectedOrder;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Legalizar Fondo • ${fund.employeeName}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entregado: ${Helpers.formatCurrency(fund.amountGiven)}'),
                        Text('Legalizado: ${Helpers.formatCurrency(fund.amountSpent)}'),
                        Text('Pendiente: ${Helpers.formatCurrency(fund.remainingBalance)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FundItemType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de registro',
                      border: OutlineInputBorder(),
                    ),
                    items: FundItemType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.name.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      if (value != null) selectedType = value;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (selectedType == FundItemType.compra || selectedType == FundItemType.pago_factura) ...[
                    DropdownButtonFormField<PurchaseOrder>(
                      value: selectedOrder,
                      decoration: const InputDecoration(
                        labelText: 'Orden de compra relacionada',
                        border: OutlineInputBorder(),
                      ),
                      items: pendingOrders
                          .map(
                            (o) => DropdownMenuItem(
                              value: o,
                              child: Text('${o.orderNumber} • ${o.supplierName} • Saldo ${Helpers.formatCurrency(o.balance)}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        selectedOrder = value;
                        if (value != null) {
                          amountController.text = value.balance.toStringAsFixed(2);
                          descriptionController.text = 'Pago orden ${value.orderNumber} - ${value.supplierName}';
                          referenceController.text = value.supplierInvoiceNumber ?? value.orderNumber;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (selectedType == FundItemType.pago_factura) ...[
                    DropdownButtonFormField<Invoice>(
                      value: selectedInvoice,
                      decoration: const InputDecoration(
                        labelText: 'Factura relacionada del sistema',
                        border: OutlineInputBorder(),
                      ),
                      items: pendingInvoices
                          .map(
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('${i.fullNumber} • ${i.customerName} • Saldo ${Helpers.formatCurrency(i.pendingAmount)}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        selectedInvoice = value;
                        if (value != null) {
                          amountController.text = value.pendingAmount.toStringAsFixed(2);
                          descriptionController.text = 'Pago factura ${value.fullNumber} - ${value.customerName}';
                          referenceController.text = value.fullNumber;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Referencia / Factura / Recibo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedType != FundItemType.devolucion)
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría contable',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'consumibles', child: Text('Consumibles')),
                        DropdownMenuItem(value: 'transporte', child: Text('Transporte')),
                        DropdownMenuItem(value: 'servicios_publicos', child: Text('Servicios Públicos')),
                        DropdownMenuItem(value: 'papeleria', child: Text('Papelería')),
                        DropdownMenuItem(value: 'gastos_reducibles', child: Text('Gastos Reducibles')),
                      ],
                      onChanged: (value) => setState(() => selectedCategory = value ?? 'consumibles'),
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
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0 || descriptionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Completa monto y descripción')),
                  );
                  return;
                }
                if (amount > fund.remainingBalance + 0.01) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('El monto supera el saldo pendiente del fondo')),
                  );
                  return;
                }
                if (selectedType == FundItemType.pago_factura &&
                    selectedInvoice == null &&
                    selectedOrder == null) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Selecciona la factura u orden relacionada')),
                  );
                  return;
                }
                if (selectedInvoice != null && amount > selectedInvoice!.pendingAmount + 0.01) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('El monto supera el saldo pendiente de la factura')),
                  );
                  return;
                }
                if (selectedOrder != null && amount > selectedOrder!.balance + 0.01) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('El monto supera el saldo pendiente de la orden')),
                  );
                  return;
                }

                final result = await ref.read(messengerFundsProvider.notifier).legalizeItem(
                  fundId: fund.id,
                  itemType: selectedType,
                  amount: amount,
                  description: descriptionController.text.trim(),
                  reference: referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
                  category: selectedType == FundItemType.devolucion ? null : selectedCategory,
                  purchaseOrderId: selectedOrder?.id,
                  invoiceId: selectedInvoice?.id,
                );

                if (!mounted) return;
                await ref.read(dailyCashProvider.notifier).load();
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result != null ? 'Registro guardado correctamente' : 'No se pudo guardar',
                    ),
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancelFund(MessengerFund fund) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar fondo'),
        content: Text(
          'Se cancelará el fondo de ${fund.employeeName} y se devolverá el saldo pendiente a la caja. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ref.read(messengerFundsProvider.notifier).cancelFund(fund.id);
      if (!mounted) return;
      await ref.read(dailyCashProvider.notifier).load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Fondo cancelado correctamente' : 'No se pudo cancelar'),
        ),
      );
    }
  }

  Future<void> _exportReportPdf(
    List<MessengerFund> filteredFunds,
    List<MessengerFundReport> reports,
  ) async {
    try {
      final reportRows = reports
          .map(
            (r) => {
              'employeeName': r.employeeName,
              'totalFunds': r.totalFunds,
              'openFunds': r.openFunds,
              'totalGiven': r.totalGiven,
              'totalSpent': r.totalSpent,
              'totalPending': r.totalPending,
            },
          )
          .toList();

      await PrintService.shareMessengerFundsReportPdf(
        funds: filteredFunds,
        reportByMessenger: reportRows,
        statusFilter: _statusFilter,
        searchQuery: _searchQuery,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte PDF generado y compartido')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar el reporte PDF')),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessengerReportCard extends StatelessWidget {
  final MessengerFundReport report;

  const _MessengerReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            report.employeeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('Fondos: ${report.totalFunds} • Abiertos: ${report.openFunds}'),
          const Spacer(),
          Text(
            'Pendiente: ${Helpers.formatCurrency(report.totalPending)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
          Text(
            'Legalizado: ${Helpers.formatCurrency(report.totalSpent)}',
            style: const TextStyle(color: Colors.green),
          ),
          Text(
            'Entregado: ${Helpers.formatCurrency(report.totalGiven)}',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _FundCard extends StatelessWidget {
  final MessengerFund fund;
  final VoidCallback onLegalize;
  final VoidCallback? onCancel;

  const _FundCard({
    required this.fund,
    required this.onLegalize,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (fund.status) {
      MessengerFundStatus.abierto => Colors.blue,
      MessengerFundStatus.parcial => Colors.orange,
      MessengerFundStatus.legalizado => Colors.green,
      MessengerFundStatus.cancelado => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(Icons.person, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fund.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Fecha: ${Helpers.formatDate(fund.dateGiven)}'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    fund.statusLabel,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _moneyChip('Entregado', fund.amountGiven, Colors.orange),
                _moneyChip('Gastado', fund.amountSpent, Colors.green),
                _moneyChip('Devuelto', fund.amountReturned, Colors.blue),
                _moneyChip('Pendiente', fund.remainingBalance, Colors.red),
              ],
            ),
            if ((fund.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(fund.notes!),
            ],
            if (fund.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Items registrados: ${fund.items.length}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: fund.progress.clamp(0, 1),
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (fund.isOpen)
                  OutlinedButton.icon(
                    onPressed: onLegalize,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Legalizar'),
                  ),
                const SizedBox(width: 8),
                if (onCancel != null)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyChip(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: ${Helpers.formatCurrency(amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
