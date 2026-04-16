import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/chat_provider.dart';
import '../../../data/datasources/accounts_datasource.dart';
import '../../../domain/entities/account.dart';

/// Bottom sheet para crear una nueva conversación o solicitud
/// Flujo: Seleccionar usuario → Tipo de mensaje → Formulario
class NewRequestSheet extends ConsumerStatefulWidget {
  const NewRequestSheet({super.key});

  @override
  ConsumerState<NewRequestSheet> createState() => _NewRequestSheetState();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewRequestSheet(),
    );
  }
}

class _NewRequestSheetState extends ConsumerState<NewRequestSheet> {
  int _currentStep = 0; // 0 = usuario, 1 = tipo, 2 = formulario
  Map<String, dynamic>? _selectedUser;
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppShapes.bottomSheet,
      ),
      child: AnimatedSize(
        duration: AppMotion.medium,
        curve: AppMotion.standard,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.base, AppSpacing.xl, AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      IconButton(
                        onPressed: () => setState(() {
                          if (_currentStep == 2) {
                            _currentStep = 1;
                            _selectedType = null;
                          } else {
                            _currentStep = 0;
                            _selectedUser = null;
                          }
                        }),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
                      ),
                    if (_currentStep > 0) const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _getTitle(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AnimatedSwitcher(
                    duration: AppMotion.medium,
                    child: _buildCurrentStep(theme, colors),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_currentStep) {
      case 0:
        return 'Nuevo Mensaje';
      case 1:
        return 'Enviar a ${_selectedUser?['display_name'] ?? ''}';
      case 2:
        return _getFormTitle(_selectedType!);
      default:
        return 'Nuevo Mensaje';
    }
  }

  Widget _buildCurrentStep(ThemeData theme, ColorScheme colors) {
    switch (_currentStep) {
      case 0:
        return _buildUserSelection(theme, colors);
      case 1:
        return _buildTypeSelection(theme, colors);
      case 2:
        return _buildForm(theme, colors);
      default:
        return const SizedBox.shrink();
    }
  }

  // ===================== PASO 0: Seleccionar usuario =====================

  Widget _buildUserSelection(ThemeData theme, ColorScheme colors) {
    final usersAsync = ref.watch(chatUsersProvider);

    return usersAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator.adaptive(),
        ),
      ),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: AppColors.danger, size: 32),
              const SizedBox(height: AppSpacing.sm),
              const Text('Error cargando usuarios'),
            ],
          ),
        ),
      ),
      data: (users) {
        return Column(
          key: const ValueKey('user_selection'),
          children: [
            _TypeOption(
              icon: Icons.auto_awesome_rounded,
              title: 'Chat con IA',
              subtitle: 'Abrir tu conversación individual con el asistente',
              color: const Color(0xFF8E24AA),
              onTap: _openAiChat,
            ),
            const SizedBox(height: AppSpacing.md),
            _TypeOption(
              icon: Icons.groups_rounded,
              title: 'Crear Grupo',
              subtitle: 'Abrir un chat grupal con todos los empleados',
              color: colors.primary,
              onTap: () => setState(() {
                _selectedType = 'group';
                _selectedUser = null;
                _currentStep = 2;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mensajes directos',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...users.map((user) {
              final name = user['display_name'] as String? ?? 'Sin nombre';
              final role = user['role'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _UserTile(
                  name: name,
                  role: role,
                  onTap: () => setState(() {
                    _selectedUser = user;
                    _currentStep = 1;
                  }),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ===================== PASO 1: Seleccionar tipo =====================

  Widget _buildTypeSelection(ThemeData theme, ColorScheme colors) {
    return Column(
      key: const ValueKey('type_selection'),
      children: [
        _TypeOption(
          icon: Icons.chat_bubble_rounded,
          title: 'Mensaje Directo',
          subtitle: 'Enviar un mensaje de texto',
          color: colors.tertiary,
          onTap: () => setState(() {
            _selectedType = 'direct';
            _currentStep = 2;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        _TypeOption(
          icon: Icons.swap_horiz_rounded,
          title: 'Traslado de Saldo',
          subtitle: 'Solicitar transferencia entre cuentas',
          color: colors.primary,
          onTap: () => setState(() {
            _selectedType = 'transfer';
            _currentStep = 2;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        _TypeOption(
          icon: Icons.shopping_cart_rounded,
          title: 'Compra de Materiales',
          subtitle: 'Solicitar aprobación para comprar materiales',
          color: const Color(0xFF8B5E3C),
          onTap: () => setState(() {
            _selectedType = 'purchase';
            _currentStep = 2;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        _TypeOption(
          icon: Icons.receipt_long_rounded,
          title: 'Gasto General',
          subtitle: 'Solicitar aprobación de un gasto',
          color: AppColors.info,
          onTap: () => setState(() {
            _selectedType = 'expense';
            _currentStep = 2;
          }),
        ),
      ],
    );
  }

  Widget _buildForm(ThemeData theme, ColorScheme colors) {
    final userId = _selectedUser?['user_id'] as String?;
    switch (_selectedType) {
      case 'direct':
        return _DirectMessageForm(key: const ValueKey('direct_form'), toUserId: userId!);
      case 'transfer':
        return _TransferForm(key: const ValueKey('transfer_form'), assignedTo: userId!);
      case 'purchase':
        return _PurchaseForm(key: const ValueKey('purchase_form'), assignedTo: userId!);
      case 'expense':
        return _ExpenseForm(key: const ValueKey('expense_form'), assignedTo: userId!);
      case 'group':
        return const _GroupChatForm(key: ValueKey('group_form'));
      default:
        return const SizedBox.shrink();
    }
  }

  String _getFormTitle(String type) {
    switch (type) {
      case 'direct':
        return 'Mensaje a ${_selectedUser?['display_name'] ?? ''}';
      case 'transfer':
        return 'Solicitar Traslado';
      case 'purchase':
        return 'Compra de Materiales';
      case 'expense':
        return 'Aprobar Gasto';
      case 'group':
        return 'Crear Grupo';
      default:
        return 'Nuevo Mensaje';
    }
  }

  Future<void> _openAiChat() async {
    final conversationId = await ref.read(chatProvider.notifier).createAiChat();
    if (!mounted) return;
    if (conversationId != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error abriendo chat con IA'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
    }
  }
}

// ===================== USER TILE =====================

class _UserTile extends StatelessWidget {
  final String name;
  final String role;
  final VoidCallback onTap;

  const _UserTile({
    required this.name,
    required this.role,
    required this.onTap,
  });

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return 'Administrador';
      case 'dueno': return 'Dueño';
      case 'tecnico': return 'Técnico';
      case 'employee': return 'Empleado';
      default: return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return const Color(0xFF1565C0);
      case 'dueno': return const Color(0xFF6A1B9A);
      case 'tecnico': return const Color(0xFF2E7D32);
      case 'employee': return const Color(0xFFE65100);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = _roleColor(role);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(AppShapes.lg),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _roleLabel(role),
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== TYPE OPTION =====================

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(AppShapes.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppShapes.md),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== DIRECT MESSAGE FORM =====================

class _DirectMessageForm extends ConsumerStatefulWidget {
  final String toUserId;
  const _DirectMessageForm({super.key, required this.toUserId});

  @override
  ConsumerState<_DirectMessageForm> createState() => _DirectMessageFormState();
}

class _DirectMessageFormState extends ConsumerState<_DirectMessageForm> {
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _messageController,
          decoration: const InputDecoration(
            labelText: 'Escribe tu mensaje',
            prefixIcon: Icon(Icons.message_rounded),
            hintText: 'Hola, ¿cómo estás?...',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded),
          label: const Text('Enviar Mensaje'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final conversationId = await ref.read(chatProvider.notifier).createDirectChat(
      toUserId: widget.toUserId,
      message: _messageController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (conversationId != null) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error enviando mensaje'), backgroundColor: Color(0xFFC62828)),
        );
      }
    }
  }
}

// ===================== TRANSFER FORM =====================

class _TransferForm extends ConsumerStatefulWidget {
  final String assignedTo;
  const _TransferForm({super.key, required this.assignedTo});

  @override
  ConsumerState<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<_TransferForm> {
  final _formKey = GlobalKey<FormState>();
  List<Account> _accounts = [];
  Account? _fromAccount;
  Account? _toAccount;
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await AccountsDataSource.getAllAccounts();
      setState(() {
        _accounts = accounts;
        _isLoadingAccounts = false;
      });
    } catch (e) {
      setState(() => _isLoadingAccounts = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccounts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Desde
          DropdownButtonFormField<Account>(
            value: _fromAccount,
            decoration: const InputDecoration(
              labelText: 'Cuenta origen',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
            ),
            items: _accounts.map((a) => DropdownMenuItem(
              value: a,
              child: Text(a.name),
            )).toList(),
            onChanged: (v) => setState(() => _fromAccount = v),
            validator: (v) => v == null ? 'Selecciona cuenta origen' : null,
          ),
          const SizedBox(height: AppSpacing.base),
          // Hacia
          DropdownButtonFormField<Account>(
            value: _toAccount,
            decoration: const InputDecoration(
              labelText: 'Cuenta destino',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
            ),
            items: _accounts
                .where((a) => a.id != _fromAccount?.id)
                .map((a) => DropdownMenuItem(
              value: a,
              child: Text(a.name),
            )).toList(),
            onChanged: (v) => setState(() => _toAccount = v),
            validator: (v) => v == null ? 'Selecciona cuenta destino' : null,
          ),
          const SizedBox(height: AppSpacing.base),
          // Monto
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Monto',
              prefixIcon: Icon(Icons.attach_money_rounded),
              prefixText: '\$ ',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa el monto';
              final amount = double.tryParse(v);
              if (amount == null || amount <= 0) return 'Monto inválido';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.base),
          // Razón
          TextFormField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Razón del traslado',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
            maxLines: 2,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe la razón' : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          // Submit
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text('Enviar Solicitud'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccount == null || _toAccount == null) return;

    setState(() => _isLoading = true);

    final conversationId = await ref.read(chatProvider.notifier).createTransferRequest(
      fromAccountId: _fromAccount!.id,
      fromAccountName: _fromAccount!.name,
      toAccountId: _toAccount!.id,
      toAccountName: _toAccount!.name,
      amount: double.parse(_amountController.text),
      reason: _reasonController.text.trim(),
      assignedTo: widget.assignedTo,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (conversationId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada'), backgroundColor: Color(0xFF2E7D32)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error enviando solicitud'), backgroundColor: Color(0xFFC62828)),
        );
      }
    }
  }
}

// ===================== PURCHASE FORM =====================

class _PurchaseForm extends ConsumerStatefulWidget {
  final String assignedTo;
  const _PurchaseForm({super.key, required this.assignedTo});

  @override
  ConsumerState<_PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends ConsumerState<_PurchaseForm> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final List<_MaterialItem> _materials = [_MaterialItem()];
  String _urgency = 'normal';
  bool _isLoading = false;

  @override
  void dispose() {
    _supplierController.dispose();
    for (final m in _materials) {
      m.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Proveedor
          TextFormField(
            controller: _supplierController,
            decoration: const InputDecoration(
              labelText: 'Proveedor',
              prefixIcon: Icon(Icons.store_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el proveedor' : null,
          ),
          const SizedBox(height: AppSpacing.base),
          // Urgencia
          DropdownButtonFormField<String>(
            value: _urgency,
            decoration: const InputDecoration(
              labelText: 'Urgencia',
              prefixIcon: Icon(Icons.flag_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'normal', child: Text('Normal')),
              DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
            ],
            onChanged: (v) => setState(() => _urgency = v ?? 'normal'),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Materiales header
          Row(
            children: [
              Text('Materiales', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _materials.add(_MaterialItem())),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Lista de materiales
          ..._materials.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppShapes.sm),
                  border: Border.all(color: colors.outlineVariant.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Material ${i + 1}', style: theme.textTheme.labelMedium),
                        const Spacer(),
                        if (_materials.length > 1)
                          IconButton(
                            onPressed: () => setState(() {
                              _materials[i].dispose();
                              _materials.removeAt(i);
                            }),
                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                            style: IconButton.styleFrom(minimumSize: const Size(28, 28)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: m.nameController,
                      decoration: const InputDecoration(labelText: 'Nombre', isDense: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: m.quantityController,
                            decoration: const InputDecoration(labelText: 'Cantidad', isDense: true),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Req.' : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextFormField(
                            controller: m.unitController,
                            decoration: const InputDecoration(labelText: 'Unidad', isDense: true, hintText: 'kg, und...'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextFormField(
                            controller: m.priceController,
                            decoration: const InputDecoration(labelText: 'Precio est.', isDense: true, prefixText: '\$ '),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.base),
          // Submit
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text('Enviar Solicitud'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final materials = _materials.map((m) {
      final price = double.tryParse(m.priceController.text) ?? 0;
      return {
        'name': m.nameController.text.trim(),
        'quantity': double.tryParse(m.quantityController.text) ?? 0,
        'unit': m.unitController.text.trim(),
        'estimated_price': price,
      };
    }).toList();

    final total = materials.fold<double>(
      0,
      (sum, m) => sum + ((m['estimated_price'] as double) * (m['quantity'] as double)),
    );

    final conversationId = await ref.read(chatProvider.notifier).createPurchaseRequest(
      materials: materials,
      supplier: _supplierController.text.trim(),
      totalEstimated: total,
      urgency: _urgency,
      assignedTo: widget.assignedTo,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (conversationId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada'), backgroundColor: Color(0xFF2E7D32)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error enviando solicitud'), backgroundColor: Color(0xFFC62828)),
        );
      }
    }
  }
}

class _MaterialItem {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final priceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    priceController.dispose();
  }
}

// ===================== GROUP FORM =====================

class _GroupChatForm extends ConsumerStatefulWidget {
  const _GroupChatForm({super.key});

  @override
  ConsumerState<_GroupChatForm> createState() => _GroupChatFormState();
}

class _GroupChatFormState extends ConsumerState<_GroupChatForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Nombre del grupo',
              prefixIcon: Icon(Icons.groups_rounded),
              hintText: 'Ej: Novedades de producción',
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              prefixIcon: Icon(Icons.notes_rounded),
              hintText: 'Encuestas, avisos, eventos, etc.',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.groups_rounded),
            label: const Text('Crear Grupo'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final conversationId = await ref.read(chatProvider.notifier).createGroupChat(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (conversationId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupo creado'), backgroundColor: Color(0xFF2E7D32)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error creando grupo'), backgroundColor: Color(0xFFC62828)),
        );
      }
    }
  }
}

// ===================== EXPENSE FORM =====================

class _ExpenseForm extends ConsumerStatefulWidget {
  final String assignedTo;
  const _ExpenseForm({super.key, required this.assignedTo});

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'general';
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción del gasto',
              prefixIcon: Icon(Icons.description_rounded),
            ),
            maxLines: 2,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe el gasto' : null,
          ),
          const SizedBox(height: AppSpacing.base),
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Monto',
              prefixIcon: Icon(Icons.attach_money_rounded),
              prefixText: '\$ ',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa el monto';
              final amount = double.tryParse(v);
              if (amount == null || amount <= 0) return 'Monto inválido';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.base),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'general', child: Text('General')),
              DropdownMenuItem(value: 'mantenimiento', child: Text('Mantenimiento')),
              DropdownMenuItem(value: 'transporte', child: Text('Transporte')),
              DropdownMenuItem(value: 'servicios', child: Text('Servicios')),
              DropdownMenuItem(value: 'papeleria', child: Text('Papelería')),
              DropdownMenuItem(value: 'alimentacion', child: Text('Alimentación')),
              DropdownMenuItem(value: 'otro', child: Text('Otro')),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text('Enviar Solicitud'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final conversationId = await ref.read(chatProvider.notifier).createExpenseRequest(
      description: _descriptionController.text.trim(),
      amount: double.parse(_amountController.text),
      category: _category,
      assignedTo: widget.assignedTo,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (conversationId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada'), backgroundColor: Color(0xFF2E7D32)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error enviando solicitud'), backgroundColor: Color(0xFFC62828)),
        );
      }
    }
  }
}
