import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _selectedSection = 0;
  bool _darkMode = false;
  bool _emailNotifications = true;
  bool _stockAlerts = true;
  bool _overdueAlerts = true;
  String _language = 'Español';
  String _currency = 'USD (\$)';

  // Controladores para edición de perfil
  final _nameController = TextEditingController(text: 'Administrador');
  final _lastNameController = TextEditingController(text: 'Sistema');
  final _emailController = TextEditingController(text: 'admin@industrialmolinos.com');
  final _phoneController = TextEditingController(text: '+51 999 999 999');
  final _roleController = TextEditingController(text: 'Administrador');

  // Controladores para empresa
  final _companyNameController = TextEditingController(text: 'Industrial de Molinos');
  final _rucController = TextEditingController(text: '20123456789');
  final _companyEmailController = TextEditingController(text: 'contacto@industrialmolinos.com');
  final _companyPhoneController = TextEditingController(text: '+51 1 234 5678');
  final _addressController = TextEditingController(text: 'Av. Industrial 123, Lima, Perú');

  final List<Map<String, dynamic>> _sections = [
    {'icon': Icons.person, 'label': 'Perfil'},
    {'icon': Icons.business, 'label': 'Empresa'},
    {'icon': Icons.tune, 'label': 'Aplicación'},
    {'icon': Icons.notifications, 'label': 'Notificaciones'},
    {'icon': Icons.backup, 'label': 'Respaldo'},
    {'icon': Icons.lock, 'label': 'Seguridad'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleController.dispose();
    _companyNameController.dispose();
    _rucController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: Row(
        children: [
          // Panel lateral de navegación
          _buildSidebar(),
          // Contenido principal
          Expanded(
            child: Column(
              children: [
                // Breadcrumbs
                _buildBreadcrumbs(),
                // Contenido de la sección
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: _buildSectionContent(),
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

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/'),
                      tooltip: 'Volver',
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Configuración',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(
                    'Gestiona tus preferencias y cuenta',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Navegación
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final section = _sections[index];
                final isSelected = _selectedSection == index;
                return _buildNavItem(
                  icon: section['icon'],
                  label: section['label'],
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedSection = index),
                );
              },
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
                const Spacer(),
                Text(
                  'Flutter',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryColor : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          _buildBreadcrumb('Inicio', onTap: () => context.go('/')),
          _buildBreadcrumbSeparator(),
          _buildBreadcrumb('Configuración'),
          _buildBreadcrumbSeparator(),
          Text(
            _sections[_selectedSection]['label'],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: onTap != null ? Colors.grey[600] : Colors.grey[800],
          fontWeight: onTap != null ? FontWeight.normal : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBreadcrumbSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case 0:
        return _buildProfileSection();
      case 1:
        return _buildCompanySection();
      case 2:
        return _buildAppSection();
      case 3:
        return _buildNotificationsSection();
      case 4:
        return _buildBackupSection();
      case 5:
        return _buildSecuritySection();
      default:
        return _buildProfileSection();
    }
  }

  // ============================================================
  // SECCIÓN: PERFIL
  // ============================================================
  Widget _buildProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        const Text(
          'Ajustes del Perfil',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Actualiza tu foto y detalles personales aquí.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        // Tarjeta de perfil
        _buildCard(
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person, size: 48, color: AppTheme.primaryColor),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_nameController.text} ${_lastNameController.text}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_roleController.text} · Industrial de Molinos',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lima, Perú',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Botones
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Eliminar foto'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Cambiar foto'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Formulario
        _buildCard(
          title: 'Información Personal',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Nombre',
                      controller: _nameController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: 'Apellido',
                      controller: _lastNameController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Correo Electrónico',
                controller: _emailController,
                prefixIcon: Icons.mail_outline,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Teléfono',
                      controller: _phoneController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: 'Cargo / Rol',
                      controller: _roleController,
                      enabled: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Botones de acción
        _buildActionButtons(),
      ],
    );
  }

  // ============================================================
  // SECCIÓN: EMPRESA
  // ============================================================
  Widget _buildCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Datos de la Empresa',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Información legal y de contacto de tu negocio.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        // Logo de empresa
        _buildCard(
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.business, size: 48, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logo de la Empresa',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se mostrará en facturas, cotizaciones y reportes.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.upload),
                label: const Text('Subir Logo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Datos de la empresa
        _buildCard(
          title: 'Información Legal',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      label: 'Razón Social',
                      controller: _companyNameController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: 'RUC',
                      controller: _rucController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Email de Contacto',
                      controller: _companyEmailController,
                      prefixIcon: Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: 'Teléfono',
                      controller: _companyPhoneController,
                      prefixIcon: Icons.phone_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Dirección',
                controller: _addressController,
                prefixIcon: Icons.location_on_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Series de documentos
        _buildCard(
          title: 'Series de Documentos',
          child: Column(
            children: [
              _buildDocumentSerieRow('Facturas', 'F001', '0001254'),
              const Divider(height: 24),
              _buildDocumentSerieRow('Boletas', 'B001', '0002341'),
              const Divider(height: 24),
              _buildDocumentSerieRow('Cotizaciones', 'COT', '000089'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildDocumentSerieRow(String docType, String serie, String lastNumber) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(docType, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('Último: $serie-$lastNumber', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Serie',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            controller: TextEditingController(text: serie),
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () {},
          tooltip: 'Editar serie',
        ),
      ],
    );
  }

  // ============================================================
  // SECCIÓN: APLICACIÓN
  // ============================================================
  Widget _buildAppSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ajustes de la Aplicación',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Personaliza la apariencia y comportamiento.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        // Idioma y moneda
        _buildCard(
          title: 'Regional',
          child: Column(
            children: [
              _buildSettingRow(
                'Idioma de la Interfaz',
                'Selecciona el idioma principal de la plataforma.',
                trailing: _buildDropdown(_language, ['Español', 'English', 'Português'], (v) => setState(() => _language = v!)),
              ),
              const Divider(height: 32),
              _buildSettingRow(
                'Moneda',
                'Moneda predeterminada para precios y totales.',
                trailing: _buildDropdown(_currency, ['USD (\$)', 'PEN (S/)', 'EUR (€)'], (v) => setState(() => _currency = v!)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Apariencia
        _buildCard(
          title: 'Apariencia',
          child: Column(
            children: [
              _buildSettingRow(
                'Modo Oscuro',
                'Cambia entre tema claro y oscuro.',
                trailing: _buildThemeToggle(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Configuración de inventario
        _buildCard(
          title: 'Inventario',
          child: Column(
            children: [
              _buildSettingRow(
                'Stock Mínimo por Defecto',
                'Cantidad mínima antes de alertar.',
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    controller: TextEditingController(text: '10'),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const Divider(height: 32),
              _buildSettingRow(
                'Descuento Automático de Stock',
                'Descuenta automáticamente al facturar.',
                trailing: Switch(
                  value: true,
                  onChanged: (v) {},
                  activeColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildThemeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildThemeButton(Icons.light_mode, 'Claro', !_darkMode, () => setState(() => _darkMode = false)),
          _buildThemeButton(Icons.dark_mode, 'Oscuro', _darkMode, () => setState(() => _darkMode = true)),
        ],
      ),
    );
  }

  Widget _buildThemeButton(IconData icon, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: selected ? Colors.grey[800] : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.grey[800] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECCIÓN: NOTIFICACIONES
  // ============================================================
  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notificaciones',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Configura cómo y cuándo recibir alertas.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        _buildCard(
          title: 'Canales',
          child: Column(
            children: [
              _buildSettingRow(
                'Notificaciones por Correo',
                'Recibe alertas importantes en tu email.',
                trailing: Switch(
                  value: _emailNotifications,
                  onChanged: (v) => setState(() => _emailNotifications = v),
                  activeColor: AppTheme.primaryColor,
                ),
              ),
              const Divider(height: 32),
              _buildSettingRow(
                'Notificaciones en App',
                'Muestra alertas dentro de la aplicación.',
                trailing: Switch(
                  value: true,
                  onChanged: (v) {},
                  activeColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildCard(
          title: 'Tipos de Alertas',
          child: Column(
            children: [
              _buildSettingRow(
                'Stock Bajo',
                'Alerta cuando un producto está bajo el mínimo.',
                trailing: Switch(
                  value: _stockAlerts,
                  onChanged: (v) => setState(() => _stockAlerts = v),
                  activeColor: AppTheme.primaryColor,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                ),
              ),
              const Divider(height: 32),
              _buildSettingRow(
                'Facturas Vencidas',
                'Recordatorio de cuentas por cobrar.',
                trailing: Switch(
                  value: _overdueAlerts,
                  onChanged: (v) => setState(() => _overdueAlerts = v),
                  activeColor: AppTheme.primaryColor,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: Colors.red, size: 20),
                ),
              ),
              const Divider(height: 32),
              _buildSettingRow(
                'Tareas Pendientes',
                'Recordatorios de tareas asignadas.',
                trailing: Switch(
                  value: true,
                  onChanged: (v) {},
                  activeColor: AppTheme.primaryColor,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.task_alt, color: Colors.blue, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildActionButtons(),
      ],
    );
  }

  // ============================================================
  // SECCIÓN: RESPALDO
  // ============================================================
  Widget _buildBackupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Respaldo de Datos',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Gestiona copias de seguridad y exportaciones.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        // Estado actual
        _buildCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_done, color: Colors.green, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos Sincronizados',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Último respaldo: Hace 5 minutos',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      'Servidor: Supabase (Online)',
                      style: TextStyle(color: Colors.green[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sincronizando...'), backgroundColor: Colors.blue),
                  );
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar Ahora'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Acciones de respaldo
        _buildCard(
          title: 'Acciones',
          child: Column(
            children: [
              _buildBackupAction(
                Icons.download,
                'Exportar Datos',
                'Descarga toda la información en formato Excel.',
                'Exportar',
                Colors.blue,
                () {},
              ),
              const Divider(height: 32),
              _buildBackupAction(
                Icons.upload,
                'Restaurar Datos',
                'Importa datos desde un archivo de respaldo.',
                'Importar',
                Colors.orange,
                () {},
              ),
              const Divider(height: 32),
              _buildBackupAction(
                Icons.delete_outline,
                'Limpiar Datos de Prueba',
                'Elimina registros de demostración.',
                'Limpiar',
                Colors.red,
                () => _showConfirmDialog(
                  'Limpiar Datos',
                  '¿Eliminar todos los datos de prueba?',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackupAction(IconData icon, String title, String subtitle, String buttonLabel, Color color, VoidCallback onTap) {
    return Row(
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withOpacity(0.5)),
          ),
          child: Text(buttonLabel),
        ),
      ],
    );
  }

  // ============================================================
  // SECCIÓN: SEGURIDAD
  // ============================================================
  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seguridad',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Protege tu cuenta y datos.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        _buildCard(
          title: 'Contraseña',
          child: Column(
            children: [
              _buildSettingRow(
                'Cambiar Contraseña',
                'Última actualización hace 30 días.',
                trailing: OutlinedButton(
                  onPressed: () => _showChangePasswordDialog(),
                  child: const Text('Cambiar'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildCard(
          title: 'Sesiones Activas',
          child: Column(
            children: [
              _buildSessionRow('Este dispositivo', 'Windows · Chrome', 'Activo ahora', true),
              const Divider(height: 24),
              _buildSessionRow('Móvil', 'Android · App', 'Hace 2 días', false),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Zona peligrosa
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Zona de Peligro',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDangerAction(
                'Eliminar Todos los Datos',
                'Esta acción es irreversible.',
                () => _showConfirmDialog(
                  'Eliminar Datos',
                  '¿Está seguro de eliminar TODOS los datos? Esta acción NO se puede deshacer.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionRow(String device, String details, String lastActive, bool current) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: current ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            current ? Icons.computer : Icons.phone_android,
            color: current ? Colors.green : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(device, style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (current) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Actual',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              Text('$details · $lastActive', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
        if (!current)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cerrar'),
          ),
      ],
    );
  }

  Widget _buildDangerAction(String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red[700])),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WIDGETS AUXILIARES
  // ============================================================
  Widget _buildCard({String? title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    IconData? prefixIcon,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey[400]) : null,
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> options, Function(String?) onChanged) {
    return Container(
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
    );
  }

  Widget _buildSettingRow(String title, String subtitle, {required Widget trailing, Widget? leading}) {
    return Row(
      children: [
        if (leading != null) ...[
          leading,
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cambios guardados correctamente'),
                backgroundColor: Colors.green,
              ),
            );
          },
          icon: const Icon(Icons.save),
          label: const Text('Guardar Cambios'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }

  void _showConfirmDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
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

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña Actual',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva Contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar Contraseña',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contraseña actualizada'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
