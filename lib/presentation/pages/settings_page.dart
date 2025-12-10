import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _autoSync = true;
  bool _notifications = true;
  String _language = 'Español';
  String _currency = 'PEN (S/)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Panel lateral
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
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                            onPressed: () => context.go('/'),
                            tooltip: 'Volver al menú',
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Configuración',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Personaliza tu aplicación',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildNavItem(Icons.business, 'Empresa', true),
                      _buildNavItem(Icons.person, 'Mi Perfil', false),
                      _buildNavItem(Icons.people, 'Usuarios', false),
                      _buildNavItem(Icons.receipt_long, 'Caja Menor', false),
                      _buildNavItem(Icons.inventory_2, 'Inventario', false),
                      _buildNavItem(Icons.sync, 'Sincronización', false),
                      _buildNavItem(Icons.notifications, 'Notificaciones', false),
                      _buildNavItem(Icons.palette, 'Apariencia', false),
                      _buildNavItem(Icons.backup, 'Respaldo', false),
                      _buildNavItem(Icons.security, 'Seguridad', false),
                    ],
                  ),
                ),
                // Info de versión
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        'Versión 1.0.0',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contenido principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Datos de la empresa
                  _buildSection(
                    'Datos de la Empresa',
                    Icons.business,
                    [
                      _buildCompanyInfo(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Configuración general
                  _buildSection(
                    'Configuración General',
                    Icons.settings,
                    [
                      _buildSettingsCard([
                        _buildDropdownSetting(
                          'Idioma',
                          'Idioma de la aplicación',
                          Icons.language,
                          _language,
                          ['Español', 'English'],
                          (value) => setState(() => _language = value!),
                        ),
                        const Divider(),
                        _buildDropdownSetting(
                          'Moneda',
                          'Moneda predeterminada',
                          Icons.attach_money,
                          _currency,
                          ['PEN (S/)', 'USD (\$)', 'EUR (€)'],
                          (value) => setState(() => _currency = value!),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Apariencia
                  _buildSection(
                    'Apariencia',
                    Icons.palette,
                    [
                      _buildSettingsCard([
                        _buildSwitchSetting(
                          'Modo Oscuro',
                          'Activa el tema oscuro',
                          Icons.dark_mode,
                          _darkMode,
                          (value) => setState(() => _darkMode = value),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Sincronización
                  _buildSection(
                    'Sincronización',
                    Icons.sync,
                    [
                      _buildSettingsCard([
                        _buildSwitchSetting(
                          'Sincronización Automática',
                          'Sincroniza datos automáticamente',
                          Icons.sync,
                          _autoSync,
                          (value) => setState(() => _autoSync = value),
                        ),
                        const Divider(),
                        _buildInfoSetting(
                          'Estado de Conexión',
                          'Conectado a Supabase',
                          Icons.cloud_done,
                          Colors.green,
                        ),
                        const Divider(),
                        _buildInfoSetting(
                          'Última Sincronización',
                          'Hace 5 minutos',
                          Icons.access_time,
                          Colors.grey,
                        ),
                        const Divider(),
                        _buildActionSetting(
                          'Sincronizar Ahora',
                          'Forzar sincronización manual',
                          Icons.refresh,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sincronizando...'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Notificaciones
                  _buildSection(
                    'Notificaciones',
                    Icons.notifications,
                    [
                      _buildSettingsCard([
                        _buildSwitchSetting(
                          'Notificaciones',
                          'Recibir alertas y recordatorios',
                          Icons.notifications_active,
                          _notifications,
                          (value) => setState(() => _notifications = value),
                        ),
                        const Divider(),
                        _buildInfoSetting(
                          'Stock Bajo',
                          'Alerta cuando un producto está bajo el mínimo',
                          Icons.warning,
                          Colors.orange,
                        ),
                        const Divider(),
                        _buildInfoSetting(
                          'Recibos Vencidos',
                          'Recordatorio de cuentas por cobrar',
                          Icons.receipt_long,
                          Colors.red,
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Respaldo
                  _buildSection(
                    'Respaldo de Datos',
                    Icons.backup,
                    [
                      _buildSettingsCard([
                        _buildInfoSetting(
                          'Último Respaldo',
                          '07/12/2025 - 10:30 AM',
                          Icons.backup,
                          Colors.green,
                        ),
                        const Divider(),
                        _buildActionSetting(
                          'Crear Respaldo',
                          'Guardar copia de seguridad local',
                          Icons.save,
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Creando respaldo...'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        _buildActionSetting(
                          'Restaurar Datos',
                          'Recuperar desde una copia de seguridad',
                          Icons.restore,
                          () {
                            _showRestoreDialog();
                          },
                        ),
                        const Divider(),
                        _buildActionSetting(
                          'Exportar Datos',
                          'Exportar a Excel o CSV',
                          Icons.download,
                          () {},
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Zona peligrosa
                  _buildSection(
                    'Zona de Peligro',
                    Icons.warning,
                    [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          children: [
                            _buildDangerAction(
                              'Limpiar Datos de Prueba',
                              'Elimina todos los datos de demostración',
                              Icons.cleaning_services,
                              () => _showConfirmDialog(
                                'Limpiar Datos de Prueba',
                                '¿Está seguro de eliminar todos los datos de prueba?',
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDangerAction(
                              'Restablecer Configuración',
                              'Volver a la configuración predeterminada',
                              Icons.settings_backup_restore,
                              () => _showConfirmDialog(
                                'Restablecer Configuración',
                                '¿Está seguro de restablecer toda la configuración?',
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDangerAction(
                              'Eliminar Todos los Datos',
                              'Borra permanentemente toda la información',
                              Icons.delete_forever,
                              () => _showConfirmDialog(
                                'Eliminar Todos los Datos',
                                '¿Está seguro de eliminar TODOS los datos? Esta acción NO se puede deshacer.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool selected) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppTheme.primaryColor : Colors.grey[600]),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? AppTheme.primaryColor : Colors.grey[800],
        ),
      ),
      selected: selected,
      selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      onTap: () {},
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
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
      child: Column(children: children),
    );
  }

  Widget _buildCompanyInfo() {
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
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.business, size: 40, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Industrial de Molinos',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('RUC: 20123456789', style: TextStyle(color: Colors.grey[600])),
                    Text('Lima, Perú', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showEditCompanyDialog(),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Editar'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildCompanyField(Icons.email, 'Email', 'contacto@industrialmolinos.com'),
              ),
              Expanded(
                child: _buildCompanyField(Icons.phone, 'Teléfono', '+51 1 234 5678'),
              ),
              Expanded(
                child: _buildCompanyField(Icons.location_on, 'Dirección', 'Av. Industrial 123, Lima'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyField(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchSetting(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting(String title, String subtitle, IconData icon, String value, List<String> options, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSetting(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(value, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSetting(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.primaryColor)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerAction(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.red),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.red),
        ],
      ),
    );
  }

  void _showEditCompanyDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.business, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  const Text('Editar Empresa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: 'Industrial de Molinos',
                decoration: const InputDecoration(labelText: 'Razón Social', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '20123456789',
                      decoration: const InputDecoration(labelText: 'RUC', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: '+51 1 234 5678',
                      decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: 'contacto@industrialmolinos.com',
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: 'Av. Industrial 123, Lima',
                decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Datos actualizados'), backgroundColor: Colors.green),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRestoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Datos'),
        content: const Text('Seleccione un archivo de respaldo para restaurar los datos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seleccionar archivo...'), backgroundColor: Colors.blue),
              );
            },
            child: const Text('Seleccionar Archivo'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title completado'), backgroundColor: Colors.red),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
