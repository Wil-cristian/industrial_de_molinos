import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _selectedPeriod = 'Este Mes';
  String _selectedReport = 'Ventas';

  // Datos de ejemplo para gráficos
  final List<double> _ventasMensuales = [12500, 15800, 18200, 14500, 22000, 19500, 25000, 21000, 28500, 24000, 31000, 35000];
  final List<String> _meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Panel lateral de reportes
          Container(
            width: 280,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reportes',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Análisis y estadísticas',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Lista de reportes
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildReportCategory('Ventas', Icons.trending_up, [
                        'Ventas por Período',
                        'Ventas por Producto',
                        'Ventas por Cliente',
                        'Productos más Vendidos',
                      ]),
                      _buildReportCategory('Inventario', Icons.inventory_2, [
                        'Stock Actual',
                        'Movimientos de Stock',
                        'Productos Bajo Mínimo',
                        'Valorización de Inventario',
                      ]),
                      _buildReportCategory('Cuentas por Cobrar', Icons.account_balance_wallet, [
                        'Cartera de Clientes',
                        'Antigüedad de Saldos',
                        'Clientes Morosos',
                      ]),
                      _buildReportCategory('Financieros', Icons.analytics, [
                        'Estado de Resultados',
                        'Flujo de Caja',
                        'Balance General',
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contenido principal
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedReport,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Período: $_selectedPeriod',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      // Selector de período
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPeriod,
                            items: ['Hoy', 'Esta Semana', 'Este Mes', 'Este Trimestre', 'Este Año', 'Personalizado']
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (value) => setState(() => _selectedPeriod = value!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download),
                        label: const Text('Exportar PDF'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Exportar Excel'),
                      ),
                    ],
                  ),
                ),
                // Contenido del reporte
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // KPIs
                        Row(
                          children: [
                            Expanded(child: _buildKpiCard('Ventas Totales', 'S/ 285,420.50', '+12.5%', Colors.blue, Icons.trending_up, true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildKpiCard('Transacciones', '1,245', '+8.3%', Colors.green, Icons.receipt_long, true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildKpiCard('Ticket Promedio', 'S/ 229.25', '+4.2%', Colors.purple, Icons.shopping_cart, true)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildKpiCard('Margen Bruto', '32.5%', '-1.2%', Colors.orange, Icons.pie_chart, false)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Gráfico principal
                        Container(
                          height: 350,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
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
                                  const Text(
                                    'Evolución de Ventas',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  _buildChartLegend('Ventas 2025', Colors.blue),
                                  const SizedBox(width: 16),
                                  _buildChartLegend('Ventas 2024', Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Expanded(
                                child: LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 10000,
                                      getDrawingHorizontalLine: (value) => FlLine(
                                        color: Colors.grey[200]!,
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 60,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              'S/ ${(value / 1000).toStringAsFixed(0)}K',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                            );
                                          },
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() >= 0 && value.toInt() < _meses.length) {
                                              return Text(
                                                _meses[value.toInt()],
                                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _ventasMensuales.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                                        isCurved: true,
                                        color: Colors.blue,
                                        barWidth: 3,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.blue.withValues(alpha: 0.1),
                                        ),
                                      ),
                                      LineChartBarData(
                                        spots: _ventasMensuales.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value * 0.85)).toList(),
                                        isCurved: true,
                                        color: Colors.grey[400],
                                        barWidth: 2,
                                        dotData: const FlDotData(show: false),
                                        dashArray: [5, 5],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Gráficos secundarios
                        Row(
                          children: [
                            // Productos más vendidos
                            Expanded(
                              child: Container(
                                height: 300,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Top 5 Productos',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: BarChart(
                                        BarChartData(
                                          alignment: BarChartAlignment.spaceAround,
                                          maxY: 100,
                                          barGroups: [
                                            _buildBarGroup(0, 95, 'Harina'),
                                            _buildBarGroup(1, 78, 'Arroz'),
                                            _buildBarGroup(2, 65, 'Azúcar'),
                                            _buildBarGroup(3, 52, 'Aceite'),
                                            _buildBarGroup(4, 45, 'Fideos'),
                                          ],
                                          titlesData: FlTitlesData(
                                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                getTitlesWidget: (value, meta) {
                                                  const titles = ['Harina', 'Arroz', 'Azúcar', 'Aceite', 'Fideos'];
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 8),
                                                    child: Text(
                                                      titles[value.toInt()],
                                                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                          borderData: FlBorderData(show: false),
                                          gridData: const FlGridData(show: false),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Distribución por categoría
                            Expanded(
                              child: Container(
                                height: 300,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ventas por Categoría',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: PieChart(
                                              PieChartData(
                                                sectionsSpace: 2,
                                                centerSpaceRadius: 40,
                                                sections: [
                                                  PieChartSectionData(value: 35, color: Colors.blue, title: '35%', titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  PieChartSectionData(value: 25, color: Colors.green, title: '25%', titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  PieChartSectionData(value: 20, color: Colors.orange, title: '20%', titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  PieChartSectionData(value: 12, color: Colors.purple, title: '12%', titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                  PieChartSectionData(value: 8, color: Colors.grey, title: '8%', titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildPieLegend('Harinas', Colors.blue, 'S/ 99,897'),
                                              _buildPieLegend('Granos', Colors.green, 'S/ 71,355'),
                                              _buildPieLegend('Aceites', Colors.orange, 'S/ 57,084'),
                                              _buildPieLegend('Azúcares', Colors.purple, 'S/ 34,250'),
                                              _buildPieLegend('Otros', Colors.grey, 'S/ 22,833'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Tabla de detalle
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
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
                                  const Text(
                                    'Detalle de Ventas',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.visibility, size: 18),
                                    label: const Text('Ver todo'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              DataTable(
                                headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                                columns: const [
                                  DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Documento', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Productos', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                  DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                                ],
                                rows: [
                                  _buildTableRow('08/12/2025', 'F001-00045', 'Juan Pérez', 5, 1250.00),
                                  _buildTableRow('08/12/2025', 'B001-00023', 'Cliente Mostrador', 2, 50.00),
                                  _buildTableRow('07/12/2025', 'F001-00044', 'María García', 12, 890.00),
                                  _buildTableRow('06/12/2025', 'F001-00043', 'Distribuidora El Sol', 45, 14800.00),
                                  _buildTableRow('05/12/2025', 'F001-00042', 'Carlos Rodríguez', 3, 500.00),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCategory(String title, IconData icon, List<String> items) {
    return ExpansionTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      children: items.map((item) => ListTile(
        contentPadding: const EdgeInsets.only(left: 72, right: 16),
        title: Text(item, style: const TextStyle(fontSize: 14)),
        selected: _selectedReport == item,
        selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        onTap: () => setState(() => _selectedReport = item),
      )).toList(),
    );
  }

  Widget _buildKpiCard(String title, String value, String change, Color color, IconData icon, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, String label) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppTheme.primaryColor,
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildPieLegend(String label, Color color, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  DataRow _buildTableRow(String date, String doc, String customer, int items, double total) {
    return DataRow(cells: [
      DataCell(Text(date)),
      DataCell(Text(doc, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(customer)),
      DataCell(Text(items.toString())),
      DataCell(Text(Formatters.currency(total), style: const TextStyle(fontWeight: FontWeight.w600))),
    ]);
  }
}
