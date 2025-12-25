import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../datasources/activities_datasource.dart';
import '../../domain/entities/activity.dart';

/// Modelo de deuda con intereses
class DebtWithInterest {
  final String customerId;
  final String customerName;
  final String invoiceId;
  final String invoiceNumber;
  final double originalAmount;
  final double pendingAmount;
  final double interestAmount;
  final double totalWithInterest;
  final DateTime dueDate;
  final int daysOverdue;
  final double interestRate;
  final bool notificationSent;
  final bool interestApplied;

  DebtWithInterest({
    required this.customerId,
    required this.customerName,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.originalAmount,
    required this.pendingAmount,
    required this.interestAmount,
    required this.totalWithInterest,
    required this.dueDate,
    required this.daysOverdue,
    required this.interestRate,
    this.notificationSent = false,
    this.interestApplied = false,
  });

  String get status {
    if (daysOverdue <= 0) return 'vigente';
    if (daysOverdue <= 30) return 'vencido';
    if (daysOverdue <= 60) return 'moroso';
    return 'critico';
  }

  String get statusLabel {
    switch (status) {
      case 'vigente':
        return 'Vigente';
      case 'vencido':
        return 'Vencido';
      case 'moroso':
        return 'En Mora';
      case 'critico':
        return 'Crítico';
      default:
        return 'Desconocido';
    }
  }
}

/// Estado para gestión de mora e intereses
class DebtManagementState {
  final List<DebtWithInterest> overdueDebts;
  final double defaultInterestRate; // % mensual
  final bool isLoading;
  final String? error;
  final int notificationsSentToday;

  DebtManagementState({
    this.overdueDebts = const [],
    this.defaultInterestRate = 2.0, // 2% mensual por defecto
    this.isLoading = false,
    this.error,
    this.notificationsSentToday = 0,
  });

  DebtManagementState copyWith({
    List<DebtWithInterest>? overdueDebts,
    double? defaultInterestRate,
    bool? isLoading,
    String? error,
    int? notificationsSentToday,
  }) {
    return DebtManagementState(
      overdueDebts: overdueDebts ?? this.overdueDebts,
      defaultInterestRate: defaultInterestRate ?? this.defaultInterestRate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      notificationsSentToday:
          notificationsSentToday ?? this.notificationsSentToday,
    );
  }

  /// Total de deuda vencida
  double get totalOverdue =>
      overdueDebts.fold(0, (sum, d) => sum + d.pendingAmount);

  /// Total de intereses acumulados
  double get totalInterest =>
      overdueDebts.fold(0, (sum, d) => sum + d.interestAmount);

  /// Total con intereses
  double get totalWithInterest =>
      overdueDebts.fold(0, (sum, d) => sum + d.totalWithInterest);

  /// Deudas que necesitan notificación (>30 días)
  List<DebtWithInterest> get debtsNeedingNotification => overdueDebts
      .where((d) => d.daysOverdue > 30 && !d.notificationSent)
      .toList();
}

/// Notifier para gestión de mora e intereses
class DebtManagementNotifier extends Notifier<DebtManagementState> {
  static SupabaseClient get _client => Supabase.instance.client;

  @override
  DebtManagementState build() {
    return DebtManagementState();
  }

  /// Cargar deudas vencidas con cálculo de intereses
  Future<void> loadOverdueDebts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🔄 Cargando deudas vencidas...');

      // Obtener facturas pendientes y vencidas
      final response = await _client
          .from('invoices')
          .select('''
            id,
            full_number,
            total,
            paid_amount,
            due_date,
            customer_id,
            customers(name, trade_name)
          ''')
          .inFilter('status', ['draft', 'issued', 'partial', 'overdue'])
          .lt('due_date', DateTime.now().toIso8601String())
          .order('due_date', ascending: true);

      final List<DebtWithInterest> debts = [];
      final today = DateTime.now();

      for (var invoice in response) {
        final total = (invoice['total'] ?? 0).toDouble();
        final paidAmount = (invoice['paid_amount'] ?? 0).toDouble();
        final pending = total - paidAmount;

        if (pending <= 0) continue;

        final dueDate = DateTime.parse(invoice['due_date']);
        final daysOverdue = today.difference(dueDate).inDays;

        if (daysOverdue <= 0) continue;

        // Calcular intereses
        final monthsOverdue = daysOverdue / 30;
        final interestAmount =
            pending * (state.defaultInterestRate / 100) * monthsOverdue;
        final totalWithInterest = pending + interestAmount;

        final customerData = invoice['customers'];
        final customerName = customerData != null
            ? customerData['trade_name'] ?? customerData['name'] ?? 'Cliente'
            : 'Cliente';

        debts.add(
          DebtWithInterest(
            customerId: invoice['customer_id'] ?? '',
            customerName: customerName,
            invoiceId: invoice['id'],
            invoiceNumber: invoice['full_number'] ?? '',
            originalAmount: total,
            pendingAmount: pending,
            interestAmount: interestAmount,
            totalWithInterest: totalWithInterest,
            dueDate: dueDate,
            daysOverdue: daysOverdue,
            interestRate: state.defaultInterestRate,
          ),
        );
      }

      state = state.copyWith(overdueDebts: debts, isLoading: false);

      print('✅ ${debts.length} deudas vencidas cargadas');

      // Verificar si hay que enviar notificaciones automáticas
      await _checkAndSendNotifications();
    } catch (e) {
      print('❌ Error cargando deudas: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cambiar tasa de interés por defecto
  void setDefaultInterestRate(double rate) {
    state = state.copyWith(defaultInterestRate: rate);
    loadOverdueDebts(); // Recalcular con nueva tasa
  }

  /// Aplicar intereses a una factura específica
  Future<bool> applyInterestToInvoice(DebtWithInterest debt) async {
    try {
      print('🔄 Aplicando interés a factura ${debt.invoiceNumber}...');

      // Crear registro de interés aplicado
      await _client.from('invoice_interests').insert({
        'invoice_id': debt.invoiceId,
        'customer_id': debt.customerId,
        'original_amount': debt.pendingAmount,
        'interest_rate': debt.interestRate,
        'interest_amount': debt.interestAmount,
        'total_amount': debt.totalWithInterest,
        'days_overdue': debt.daysOverdue,
        'applied_at': DateTime.now().toIso8601String(),
      });

      // Actualizar el total de la factura
      await _client
          .from('invoices')
          .update({
            'total': debt.originalAmount + debt.interestAmount,
            'notes':
                'Interés por mora aplicado: S/ ${debt.interestAmount.toStringAsFixed(2)}',
          })
          .eq('id', debt.invoiceId);

      print('✅ Interés aplicado correctamente');
      await loadOverdueDebts();
      return true;
    } catch (e) {
      print('❌ Error aplicando interés: $e');
      return false;
    }
  }

  /// Verificar y enviar notificaciones automáticas
  Future<void> _checkAndSendNotifications() async {
    final debtsToNotify = state.debtsNeedingNotification;

    if (debtsToNotify.isEmpty) return;

    int sentCount = 0;
    for (var debt in debtsToNotify) {
      final sent = await _sendOverdueNotification(debt);
      if (sent) sentCount++;
    }

    if (sentCount > 0) {
      state = state.copyWith(notificationsSentToday: sentCount);
    }
  }

  /// Enviar notificación de mora individual
  Future<bool> _sendOverdueNotification(DebtWithInterest debt) async {
    try {
      // Crear actividad/notificación en el sistema
      final now = DateTime.now();
      final activity = Activity(
        id: '',
        title: '⚠️ Deuda vencida: ${debt.customerName}',
        description:
            'Factura ${debt.invoiceNumber} vencida hace ${debt.daysOverdue} días. '
            'Monto pendiente: S/ ${debt.pendingAmount.toStringAsFixed(2)} + '
            'Intereses: S/ ${debt.interestAmount.toStringAsFixed(2)} = '
            'Total: S/ ${debt.totalWithInterest.toStringAsFixed(2)}',
        activityType: ActivityType.collection,
        startDate: now,
        dueDate: debt.dueDate,
        status: ActivityStatus.pending,
        priority: debt.daysOverdue > 60
            ? ActivityPriority.urgent
            : ActivityPriority.high,
        customerId: debt.customerId,
        customerName: debt.customerName,
        invoiceId: debt.invoiceId,
        amount: debt.totalWithInterest,
        color: '#F44336', // Rojo para alertas
        notes: 'Notificación automática de mora',
        createdAt: now,
        updatedAt: now,
      );

      await ActivitiesDatasource.createActivity(activity);

      print('📧 Notificación enviada para ${debt.customerName}');
      return true;
    } catch (e) {
      print('❌ Error enviando notificación: $e');
      return false;
    }
  }

  /// Enviar recordatorio manual de mora
  Future<bool> sendManualReminder(DebtWithInterest debt) async {
    try {
      final now = DateTime.now();
      final activity = Activity(
        id: '',
        title: '📨 Recordatorio de pago enviado',
        description:
            'Se envió recordatorio a ${debt.customerName} por factura ${debt.invoiceNumber}. '
            'Deuda: S/ ${debt.totalWithInterest.toStringAsFixed(2)} (incluye intereses)',
        activityType: ActivityType.reminder,
        startDate: now,
        status: ActivityStatus.completed,
        priority: ActivityPriority.medium,
        customerId: debt.customerId,
        customerName: debt.customerName,
        invoiceId: debt.invoiceId,
        amount: debt.totalWithInterest,
        color: '#FF9800', // Naranja para recordatorios
        notes: 'Recordatorio manual de cobranza',
        createdAt: now,
        updatedAt: now,
      );

      await ActivitiesDatasource.createActivity(activity);
      return true;
    } catch (e) {
      print('❌ Error enviando recordatorio: $e');
      return false;
    }
  }
}

/// Provider de gestión de mora
final debtManagementProvider =
    NotifierProvider<DebtManagementNotifier, DebtManagementState>(() {
      return DebtManagementNotifier();
    });
