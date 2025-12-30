import 'package:flutter/material.dart';
import '../../domain/entities/invoice.dart';
import '../../core/theme/app_theme.dart';

// =====================================================
// RECIBO DE CAJA MENOR - VERSIÓN CLIENTE
// Diseño moderno y limpio para entregar al cliente
// =====================================================
class ReceiptPreviewClient extends StatelessWidget {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final String? notes;
  final String? companyName;
  final String? companyNit;
  final String? companyAddress;
  final String? companyPhone;
  final String? companyEmail;
  final String? bankInfo;

  const ReceiptPreviewClient({
    super.key,
    required this.invoice,
    required this.items,
    this.notes,
    this.companyName = 'Industrial de Molinos',
    this.companyNit = '901946675-1',
    this.companyAddress = 'Vrd la playita - Supía, Caldas',
    this.companyPhone = '3217551145 - 3136446632',
    this.companyEmail = 'industriasdemolinosasfact@gmail.com',
    this.bankInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F7F8),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header con gradiente
              _buildHeader(),
              // Contenido principal
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInvoiceInfo(),
                      const SizedBox(height: 32),
                      _buildClientAndDates(),
                      const SizedBox(height: 32),
                      _buildItemsTable(),
                      const SizedBox(height: 32),
                      _buildTotals(),
                      const SizedBox(height: 32),
                      _buildPaymentInfo(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(
        children: [
          // Patrón decorativo
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPatternPainter(),
            ),
          ),
          // Línea azul inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info izquierda - Título
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified, color: AppTheme.primaryColor, size: 36),
                  const SizedBox(width: 12),
                  const Text(
                    'RECIBO DE CAJA MENOR',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111418),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '#RCM-${invoice.number.toString().padLeft(4, '0')}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(invoice.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _getStatusColor(invoice.status).withOpacity(0.3)),
                ),
                child: Text(
                  _getStatusLabel(invoice.status).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(invoice.status),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Info derecha - Empresa
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'lib/photo/logo_empresa.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.7)],
                          ),
                        ),
                        child: const Icon(Icons.precision_manufacturing, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      companyName ?? 'Industrial de Molinos',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      companyAddress ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Text(
                      'NIT: ${companyNit ?? ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              companyEmail ?? '',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClientAndDates() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[100]!),
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cliente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FACTURAR A',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  invoice.customerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111418),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'NIT/CC: ${invoice.customerDocument}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ID Cliente: ${invoice.customerId?.substring(0, 8) ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Fechas
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildDateRow('Fecha de Emisión:', _formatDate(invoice.issueDate)),
              const SizedBox(height: 8),
              _buildDateRow('Fecha de Vencimiento:', invoice.dueDate != null ? _formatDate(invoice.dueDate!) : 'N/A'),
              const SizedBox(height: 8),
              _buildDateRow('Periodo:', _getPeriod(invoice.issueDate)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, String value) {
    return SizedBox(
      width: 260,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Descripción del Servicio',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    'Cantidad',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'Importe',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Items
          ...items.map((item) => _buildTableRow(item)),
        ],
      ),
    );
  }

  Widget _buildTableRow(InvoiceItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF111418),
                  ),
                ),
                if (item.description != null && item.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.description!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '\$${_formatNumber(item.total)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF111418),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals() {
    final taxRate = invoice.subtotal > 0 ? ((invoice.taxAmount / invoice.subtotal) * 100) : 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 300,
          child: Column(
            children: [
              _buildTotalLine('Subtotal', invoice.subtotal),
              const SizedBox(height: 8),
              _buildTotalLine('IVA (${taxRate.toStringAsFixed(0)}%)', invoice.taxAmount),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total a Pagar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111418),
                    ),
                  ),
                  Text(
                    '\$${_formatNumber(invoice.total)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'COP - Pesos Colombianos',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalLine(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500])),
          Text(
            '\$${_formatNumber(value)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, style: BorderStyle.solid)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info de pago
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información de Pago',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111418),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Banco: BBVA Bancomer', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Text('Cuenta: 36800017429 ahorros', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                Text('Celulares: $companyPhone', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          // Mensaje
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '"Gracias por su confianza. Pago debido en 30 días a partir de la fecha de emisión."',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                Text(
                  'Si tiene alguna pregunta sobre este recibo, por favor contáctenos.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.issued:
        return Colors.blue;
      case InvoiceStatus.partial:
        return Colors.orange;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Borrador';
      case InvoiceStatus.issued:
        return 'Emitido';
      case InvoiceStatus.paid:
        return 'Pagado';
      case InvoiceStatus.partial:
        return 'Pago Parcial';
      case InvoiceStatus.cancelled:
        return 'Anulado';
      case InvoiceStatus.overdue:
        return 'Vencido';
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  String _getPeriod(DateTime date) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatNumber(double number) {
    final parts = number.toStringAsFixed(2).split('.');
    final intPart = parts[0].split('').reversed.toList();
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return '${buffer.toString().split('').reversed.join()}.${parts[1]}';
  }
}

// Painter para el patrón de cuadrícula decorativo
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;

    const spacing = 20.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =====================================================
// RECIBO DE CAJA MENOR - VERSIÓN EMPRESA (DETALLADA)
// Con desglose de materiales, mano de obra y costos
// =====================================================
class ReceiptPreviewEnterprise extends StatelessWidget {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final List<Map<String, dynamic>>? productDetails;
  final List<Map<String, dynamic>>? laborDetails;
  final Map<String, dynamic>? energyCosts;
  final Map<String, dynamic>? logisticsCosts;
  final double? overheadPercentage;
  final String? notes;
  final String? companyName;

  const ReceiptPreviewEnterprise({
    super.key,
    required this.invoice,
    required this.items,
    this.productDetails,
    this.laborDetails,
    this.energyCosts,
    this.logisticsCosts,
    this.overheadPercentage = 15.0,
    this.notes,
    this.companyName = 'Industrial de Molinos',
  });

  @override
  Widget build(BuildContext context) {
    // Calcular totales
    final totalMaterials = items.fold<double>(0, (sum, item) => sum + item.total);
    final totalLabor = laborDetails?.fold<double>(0, (sum, labor) => sum + (labor['total'] as double? ?? 0)) ?? 0;
    final energyTotal = energyCosts?['total'] as double? ?? 0;
    final logisticsTotal = logisticsCosts?['total'] as double? ?? 0;
    final overheadTotal = totalMaterials * (overheadPercentage ?? 15) / 100;
    final totalCosts = totalMaterials + totalLabor + energyTotal + logisticsTotal + overheadTotal;
    final profit = invoice.total - totalCosts;
    final margin = invoice.total > 0 ? (profit / invoice.total * 100) : 0.0;
    final operationalTotal = totalLabor + energyTotal + logisticsTotal + overheadTotal;

    return Container(
      color: const Color(0xFFF6F7F8),
      child: Column(
        children: [
          // Header con navegación estilo ERP
          _buildERPHeader(),
          // Contenido principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page header
                  _buildPageHeader(),
                  const SizedBox(height: 24),
                  // Stats cards
                  _buildStatsCards(totalMaterials, operationalTotal, profit, margin),
                  const SizedBox(height: 24),
                  // BOM Table
                  _buildBOMSection(),
                  const SizedBox(height: 24),
                  // Labor & Overhead
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildLaborSection()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildOverheadSection(energyTotal, logisticsTotal, overheadTotal, totalMaterials)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Notes
                  if (notes != null && notes!.isNotEmpty) _buildNotesSection(),
                ],
              ),
            ),
          ),
          // Footer con acciones
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildERPHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.precision_manufacturing, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            companyName ?? 'ProMan ERP',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 32),
          _buildNavItem('Tablero', false),
          _buildNavItem('Proyectos', false),
          _buildNavItem('Facturación', true),
          _buildNavItem('Inventario', false),
          _buildNavItem('RRHH', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: active ? FontWeight.bold : FontWeight.w500,
          color: active ? const Color(0xFF111418) : Colors.grey[500],
          decoration: active ? TextDecoration.underline : null,
          decorationColor: AppTheme.primaryColor,
          decorationThickness: 2,
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'EN REVISIÓN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Actualizado: Hoy, ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items.isNotEmpty ? items.first.productName : 'Orden de Producción',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111418),
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Recibo #RCM-${invoice.number.toString().padLeft(4, '0')} • Cliente: ${invoice.customerName}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _buildActionButton(Icons.print, 'Imprimir', false),
                const SizedBox(width: 8),
                _buildActionButton(Icons.picture_as_pdf, 'Exportar PDF', false),
                const SizedBox(width: 8),
                _buildActionButton(Icons.save, 'Guardar Cambios', true),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, bool primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: primary ? AppTheme.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: primary ? null : Border.all(color: Colors.grey[300]!),
        boxShadow: primary
            ? [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primary ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: primary ? Colors.white : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(double materials, double operational, double profit, double margin) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('INGRESOS TOTALES', invoice.total, Icons.payments, null, 'Precio Fijo Pactado', Colors.teal, false)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('COSTO MATERIALES (BOM)', materials, Icons.inventory_2, '+2.3% sobre presupuesto', null, Colors.red, false)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('COSTOS OPERATIVOS', operational, Icons.engineering, '-5% optimización', null, Colors.teal, false)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('GANANCIA NETA', profit, Icons.account_balance_wallet, 'Margen: ${margin.toStringAsFixed(1)}%', null, AppTheme.primaryColor, true)),
      ],
    );
  }

  Widget _buildStatCard(String label, double value, IconData icon, String? trend, String? subtitle, Color trendColor, bool highlight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? Colors.blue[100]! : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: highlight ? AppTheme.primaryColor : Colors.grey[500]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: highlight ? AppTheme.primaryColor : Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$${_formatNumber(value)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: highlight ? AppTheme.primaryColor : const Color(0xFF111418),
            ),
          ),
          const SizedBox(height: 4),
          if (trend != null)
            Row(
              children: [
                Icon(
                  trend.contains('+') ? Icons.arrow_upward : (trend.contains('-') ? Icons.arrow_downward : Icons.trending_flat),
                  size: 14,
                  color: trendColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(trend, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: trendColor), overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          if (subtitle != null)
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.teal[600])),
        ],
      ),
    );
  }

  Widget _buildBOMSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Desglose de Componentes (BOM)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
              label: Text('Agregar Componente', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    _buildTableHeader('ID', 80),
                    _buildTableHeader('COMPONENTE', null, flex: 1),
                    _buildTableHeader('CATEGORÍA', 100),
                    _buildTableHeader('CANT.', 60, center: true),
                    _buildTableHeader('COSTO UNIT.', 100, right: true),
                    _buildTableHeader('TOTAL', 100, right: true),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // Rows
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final details = productDetails != null && index < productDetails!.length ? productDetails![index] : null;
                return _buildBOMRow(item, details, 'CMP-${(index + 1).toString().padLeft(3, '0')}');
              }),
              // Footer con total
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    Text(
                      'SUBTOTAL MATERIALES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 40),
                    Text(
                      '\$${_formatNumber(items.fold<double>(0, (sum, item) => sum + item.total))}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String label, double? width, {bool center = false, bool right = false, int? flex}) {
    final widget = Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
      textAlign: right ? TextAlign.right : (center ? TextAlign.center : TextAlign.left),
    );

    if (flex != null) {
      return Expanded(flex: flex, child: widget);
    }
    return SizedBox(width: width, child: widget);
  }

  Widget _buildBOMRow(InvoiceItem item, Map<String, dynamic>? details, String id) {
    final category = details?['category'] as String? ?? 'Material';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              id,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (details?['supplier'] != null)
                  Text(
                    'Prov: ${details!['supplier']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _getCategoryColor(category),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${item.quantity}',
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '\$${_formatNumber(item.unitPrice)}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '\$${_formatNumber(item.total)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: () {},
              icon: Icon(Icons.edit, size: 18, color: Colors.grey[400]),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'material':
        return Colors.grey[700]!;
      case 'componente':
        return Colors.blue;
      case 'electrónica':
        return Colors.purple;
      case 'pieza':
        return Colors.grey[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildLaborSection() {
    final defaultLabor = [
      {'role': 'Soldador Senior', 'hours': 45.0, 'rate': 35.0, 'total': 1575.0},
      {'role': 'Ingeniero de Ensamble', 'hours': 20.0, 'rate': 50.0, 'total': 1000.0},
      {'role': 'Técnico Eléctrico', 'hours': 15.0, 'rate': 40.0, 'total': 600.0},
      {'role': 'Ayudante General', 'hours': 60.0, 'rate': 18.0, 'total': 1080.0},
    ];
    final labor = laborDetails ?? defaultLabor;
    final totalLabor = labor.fold<double>(0, (sum, l) => sum + (l['total'] as double? ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mano de Obra (Labor)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {},
              child: Text('Ver detalle horas', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('ROL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500]))),
                    SizedBox(width: 60, child: Text('HORAS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500]), textAlign: TextAlign.right)),
                    SizedBox(width: 70, child: Text('TARIFA/HR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500]), textAlign: TextAlign.right)),
                    SizedBox(width: 80, child: Text('TOTAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500]), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              // Rows
              ...labor.map((l) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
                    child: Row(
                      children: [
                        Expanded(child: Text(l['role'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        SizedBox(width: 60, child: Text('${l['hours']}', style: TextStyle(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.right)),
                        SizedBox(width: 70, child: Text('\$${(l['rate'] as double).toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.right)),
                        SizedBox(width: 80, child: Text('\$${_formatNumber(l['total'] as double)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      ],
                    ),
                  )),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('TOTAL MANO DE OBRA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    const SizedBox(width: 16),
                    Text('\$${_formatNumber(totalLabor)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverheadSection(double energyTotal, double logisticsTotal, double overheadTotal, double materialsTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gastos Generales y Energía',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildOverheadCard(Icons.bolt, 'Energía Eléctrica', Colors.amber, [
              {'label': 'Consumo (kWh)', 'value': '1,250 kWh'},
              {'label': 'Costo por kWh', 'value': '\$0.22'},
            ], energyTotal > 0 ? energyTotal : 275.0, 'Editar Tarifa')),
            const SizedBox(width: 12),
            Expanded(child: _buildOverheadCard(Icons.local_shipping, 'Logística', Colors.indigo, [
              {'label': 'Flete de Entrada', 'value': '\$450.00'},
              {'label': 'Envío al Cliente', 'value': '\$1,200.00'},
            ], logisticsTotal > 0 ? logisticsTotal : 1650.0, 'Detalles Envío')),
          ],
        ),
        const SizedBox(height: 12),
        // Factory overhead
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.factory, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gastos Indirectos de Fábrica (15%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Calculado sobre costo de materiales', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              Text(
                '\$${_formatNumber(overheadTotal > 0 ? overheadTotal : materialsTotal * 0.15)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverheadCard(IconData icon, String title, Color color, List<Map<String, String>> details, double total, String buttonLabel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 16),
          ...details.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d['label']!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(d['value']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              )),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total ${title.split(' ').first}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('\$${_formatNumber(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey[100],
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(buttonLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note, color: Colors.amber[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOTAS:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[800], fontSize: 12)),
                const SizedBox(height: 4),
                Text(notes!, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {},
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111418),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Finalizar Recibo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    final parts = number.toStringAsFixed(2).split('.');
    final intPart = parts[0].split('').reversed.toList();
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return '${buffer.toString().split('').reversed.join()}.${parts[1]}';
  }
}
