import 'package:flutter/material.dart';
import '../../domain/entities/invoice.dart';

/// Widget para mostrar vista previa de recibo para CLIENTE (simple)
class ReceiptPreviewClient extends StatelessWidget {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final String? notes;

  const ReceiptPreviewClient({
    super.key,
    required this.invoice,
    required this.items,
    this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildClientInfo(),
            const Divider(thickness: 1),
            _buildProductsTable(),
            const Divider(thickness: 1),
            _buildTotals(),
            if (notes != null && notes!.isNotEmpty) _buildNotes(),
            const Divider(thickness: 1),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo de la empresa
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'lib/photo/logo_empresa.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1a365d), width: 2),
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFF1a365d), const Color(0xFF2d5a8c)],
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grain, size: 30, color: Colors.white),
                        SizedBox(height: 2),
                        Text(
                          'MOLINOS',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'INDUSTRIAL DE MOLINOS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a365d),
                ),
              ),
              const Text(
                'E IMPORTACIONES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1a365d),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'RECIBO ${invoice.number.toString().padLeft(4, '0')}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientInfo() {
    return Column(
      children: [
        _buildInfoRow('Cliente:', invoice.customerName),
        _buildInfoRow('NIT/CC:', invoice.customerDocument),
        _buildInfoRow('Celular:', ''),
        _buildInfoRow('Fecha:', _formatDate(invoice.issueDate)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildProductsTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.grey.shade200),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              Expanded(child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              Expanded(child: Text('Valor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
            ],
          ),
        ),
        ...items.map((item) => _buildProductRow(item)),
        ...List.generate((5 - items.length).clamp(0, 5), (_) => _buildEmptyRow()),
      ],
    );
  }

  Widget _buildProductRow(InvoiceItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(item.productName, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text('${item.quantity}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
          Expanded(child: Text('\$ ${_formatNumber(item.unitPrice)}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
          Expanded(child: Text(_formatNumber(item.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildEmptyRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: const Row(children: [Expanded(flex: 3, child: SizedBox()), Expanded(child: SizedBox()), Expanded(child: SizedBox()), Expanded(child: SizedBox())]),
    );
  }

  Widget _buildTotals() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          const Expanded(child: SizedBox()),
          const Expanded(child: SizedBox()),
          Expanded(child: Text(_formatNumber(invoice.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildNotes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOTA:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
          const SizedBox(height: 4),
          Text(notes ?? '', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
          child: const Column(
            children: [
              Text('INDUSTRIAL DE MOLINOS E IMPORTACIONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              SizedBox(height: 4),
              Text('CELULARES 3043047353 - 3217551145', style: TextStyle(fontSize: 11)),
              Text('E-mail: industriasdemolinosasfact@gmail.com', style: TextStyle(fontSize: 11)),
              Text('CUENTA BANCARIA 36800017429 ahorros', style: TextStyle(fontSize: 11)),
              Text('SUPIA CALDAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('NIT: 901946675', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Text('Vrd la playita esq costado izquierdo - vía principal que conduce al municipio de Supía Caldas', style: TextStyle(fontSize: 10, color: Colors.grey.shade600), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('TELÉFONOS: 3217551145 - 3136446632', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text('CORREO: industriasdemolinosasfact@gmail.com', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatNumber(double number) {
    final parts = number.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }
}

/// Widget para vista previa de recibo para EMPRESA (detallado)
class ReceiptPreviewEnterprise extends StatelessWidget {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final List<Map<String, dynamic>>? productDetails;
  final String? notes;

  const ReceiptPreviewEnterprise({
    super.key,
    required this.invoice,
    required this.items,
    this.productDetails,
    this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildClientInfo(),
            const Divider(thickness: 2),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              child: const Text('COPIA EMPRESA - DETALLE COMPLETO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
            ),
            const Divider(thickness: 1),
            _buildDetailedProducts(),
            const Divider(thickness: 1),
            _buildTotals(),
            if (notes != null && notes!.isNotEmpty) _buildNotes(),
            const Divider(thickness: 1),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo de la empresa
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'lib/photo/logo_empresa.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF1a365d), width: 2),
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFF1a365d), const Color(0xFF2d5a8c)],
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.grain, size: 30, color: Colors.white),
                        SizedBox(height: 2),
                        Text(
                          'MOLINOS',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              const Text('INDUSTRIAL DE MOLINOS E IMPORTACIONES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1a365d)), textAlign: TextAlign.center),
              const Text('NIT: 901946675', style: TextStyle(fontSize: 11)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red)),
                child: Text('RECIBO ${invoice.number.toString().padLeft(4, '0')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientInfo() {
    return Column(
      children: [
        _buildInfoRow('Cliente:', invoice.customerName),
        _buildInfoRow('NIT/CC:', invoice.customerDocument),
        _buildInfoRow('Fecha:', _formatDate(invoice.issueDate)),
        _buildInfoRow('Vencimiento:', invoice.dueDate != null ? _formatDate(invoice.dueDate!) : 'N/A'),
        _buildInfoRow('Estado:', _getStatusLabel(invoice.status)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildDetailedProducts() {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final details = productDetails != null && index < productDetails!.length ? productDetails![index] : null;
        return _buildProductCard(item, details);
      }).toList(),
    );
  }

  Widget _buildProductCard(InvoiceItem item, Map<String, dynamic>? details) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Total: \$ ${_formatNumber(item.total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
            ],
          ),
          const Divider(),
          if (details != null) ...[
            if (details['type'] != null) _buildDetailRow('Tipo:', details['type']),
            if (details['dimensions'] != null) _buildDetailRow('Dimensiones:', details['dimensions']),
            if (details['weight'] != null) _buildDetailRow('Peso:', '${details['weight']} kg'),
            if (details['material'] != null) _buildDetailRow('Material:', details['material']),
            if (details['components'] != null) ...[
              const SizedBox(height: 8),
              const Text('Componentes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ...(details['components'] as List).map((comp) => Padding(padding: const EdgeInsets.only(left: 16), child: Text('• $comp', style: const TextStyle(fontSize: 10)))),
            ],
            const Divider(),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cantidad: ${item.quantity}', style: const TextStyle(fontSize: 11)),
              Text('Precio Unit.: \$ ${_formatNumber(item.unitPrice)}', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100),
      child: Column(
        children: [
          _buildTotalRow('Subtotal:', invoice.subtotal),
          if (invoice.discount > 0) _buildTotalRow('Descuento:', -invoice.discount, color: Colors.green),
          const Divider(),
          _buildTotalRow('TOTAL:', invoice.total, isBold: true),
          const SizedBox(height: 8),
          _buildTotalRow('Pagado:', invoice.paidAmount, color: Colors.green),
          _buildTotalRow('Pendiente:', invoice.pendingAmount, color: Colors.orange, isBold: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        Text('\$ ${_formatNumber(value)}', style: TextStyle(fontSize: isBold ? 14 : 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
      ],
    );
  }

  Widget _buildNotes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOTAS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange)),
          const SizedBox(height: 4),
          Text(notes ?? '', style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
      child: const Column(
        children: [
          Text('INDUSTRIAL DE MOLINOS E IMPORTACIONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          Text('NIT: 901946675', style: TextStyle(fontSize: 9)),
          Text('industriasdemolinosasfact@gmail.com', style: TextStyle(fontSize: 9)),
          Text('SUPIA CALDAS', style: TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatNumber(double number) {
    final parts = number.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buffer.write('.');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }

  String _getStatusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return 'Borrador';
      case InvoiceStatus.issued: return 'Emitido';
      case InvoiceStatus.paid: return 'Pagado';
      case InvoiceStatus.partial: return 'Pago Parcial';
      case InvoiceStatus.cancelled: return 'Anulado';
      case InvoiceStatus.overdue: return 'Vencido';
    }
  }
}
