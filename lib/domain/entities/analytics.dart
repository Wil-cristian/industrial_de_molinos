// Entidades para Analytics y Reportes

/// Historial de compra individual de un cliente
class CustomerPurchaseHistory {
  final String customerId;
  final String customerName;
  final String? documentNumber;
  final String? customerType;
  final String? invoiceId;
  final String? invoiceNumber;
  final DateTime? issueDate;
  final double? invoiceTotal;
  final String? invoiceStatus;
  final String? productName;
  final String? productCode;
  final double? quantity;
  final double? unitPrice;
  final double? itemTotal;

  CustomerPurchaseHistory({
    required this.customerId,
    required this.customerName,
    this.documentNumber,
    this.customerType,
    this.invoiceId,
    this.invoiceNumber,
    this.issueDate,
    this.invoiceTotal,
    this.invoiceStatus,
    this.productName,
    this.productCode,
    this.quantity,
    this.unitPrice,
    this.itemTotal,
  });

  factory CustomerPurchaseHistory.fromJson(Map<String, dynamic> json) {
    return CustomerPurchaseHistory(
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      documentNumber: json['document_number'],
      customerType: json['customer_type'],
      invoiceId: json['invoice_id'],
      invoiceNumber: json['invoice_number'],
      issueDate: json['issue_date'] != null
          ? DateTime.tryParse(json['issue_date'])
          : null,
      invoiceTotal: (json['invoice_total'] as num?)?.toDouble(),
      invoiceStatus: json['invoice_status'],
      productName: json['product_name'],
      productCode: json['product_code'],
      quantity: (json['quantity'] as num?)?.toDouble(),
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      itemTotal: (json['item_total'] as num?)?.toDouble(),
    );
  }
}

/// Métricas resumidas de un cliente
class CustomerMetrics {
  final String id;
  final String name;
  final String? documentNumber;
  final String? type;
  final double debt;
  final double creditLimit;
  final DateTime? customerSince;
  final int totalPurchases;
  final double totalSpent;
  final double averageTicket;
  final DateTime? lastPurchaseDate;
  final DateTime? firstPurchaseDate;
  final int? daysSinceLastPurchase;

  CustomerMetrics({
    required this.id,
    required this.name,
    this.documentNumber,
    this.type,
    this.debt = 0,
    this.creditLimit = 0,
    this.customerSince,
    this.totalPurchases = 0,
    this.totalSpent = 0,
    this.averageTicket = 0,
    this.lastPurchaseDate,
    this.firstPurchaseDate,
    this.daysSinceLastPurchase,
  });

  factory CustomerMetrics.fromJson(Map<String, dynamic> json) {
    return CustomerMetrics(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      documentNumber: json['document_number'],
      type: json['type'],
      debt: (json['debt'] as num?)?.toDouble() ?? 0,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
      customerSince: json['customer_since'] != null
          ? DateTime.tryParse(json['customer_since'])
          : null,
      totalPurchases: (json['total_purchases'] as num?)?.toInt() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      averageTicket: (json['average_ticket'] as num?)?.toDouble() ?? 0,
      lastPurchaseDate: json['last_purchase_date'] != null
          ? DateTime.tryParse(json['last_purchase_date'])
          : null,
      firstPurchaseDate: json['first_purchase_date'] != null
          ? DateTime.tryParse(json['first_purchase_date'])
          : null,
      daysSinceLastPurchase:
          (json['days_since_last_purchase'] as num?)?.toInt(),
    );
  }

  // Helper para estado del cliente
  String get activityStatus {
    if (daysSinceLastPurchase == null) return 'Nuevo';
    if (daysSinceLastPurchase! <= 30) return 'Activo';
    if (daysSinceLastPurchase! <= 90) return 'Regular';
    return 'Inactivo';
  }
}

/// Producto más vendido
class TopSellingProduct {
  final String productKey;
  final String? productName;
  final String? productCode;
  final double totalQuantity;
  final int timesSold;
  final double totalRevenue;
  final double avgPrice;

  TopSellingProduct({
    required this.productKey,
    this.productName,
    this.productCode,
    this.totalQuantity = 0,
    this.timesSold = 0,
    this.totalRevenue = 0,
    this.avgPrice = 0,
  });

  factory TopSellingProduct.fromJson(Map<String, dynamic> json) {
    return TopSellingProduct(
      productKey: json['product_key'] ?? '',
      productName: json['product_name'],
      productCode: json['product_code'],
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0,
      timesSold: (json['times_sold'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      avgPrice: (json['avg_price'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Consumo de material por mes
class MaterialConsumption {
  final DateTime month;
  final String materialId;
  final String materialName;
  final String? materialCode;
  final String? category;
  final double consumed;
  final double received;
  final int movements;

  MaterialConsumption({
    required this.month,
    required this.materialId,
    required this.materialName,
    this.materialCode,
    this.category,
    this.consumed = 0,
    this.received = 0,
    this.movements = 0,
  });

  factory MaterialConsumption.fromJson(Map<String, dynamic> json) {
    return MaterialConsumption(
      month: DateTime.tryParse(json['month'] ?? '') ?? DateTime.now(),
      materialId: json['material_id'] ?? '',
      materialName: json['material_name'] ?? '',
      materialCode: json['material_code'],
      category: json['category'],
      consumed: (json['consumed'] as num?)?.toDouble() ?? 0,
      received: (json['received'] as num?)?.toDouble() ?? 0,
      movements: (json['movements'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Ventas por período
class SalesByPeriod {
  final DateTime day;
  final DateTime week;
  final DateTime month;
  final DateTime year;
  final int numInvoices;
  final double subtotal;
  final double tax;
  final double total;
  final double collected;
  final double pending;
  final double avgTicket;

  SalesByPeriod({
    required this.day,
    required this.week,
    required this.month,
    required this.year,
    this.numInvoices = 0,
    this.subtotal = 0,
    this.tax = 0,
    this.total = 0,
    this.collected = 0,
    this.pending = 0,
    this.avgTicket = 0,
  });

  factory SalesByPeriod.fromJson(Map<String, dynamic> json) {
    return SalesByPeriod(
      day: DateTime.tryParse(json['day'] ?? '') ?? DateTime.now(),
      week: DateTime.tryParse(json['week'] ?? '') ?? DateTime.now(),
      month: DateTime.tryParse(json['month'] ?? '') ?? DateTime.now(),
      year: DateTime.tryParse(json['year'] ?? '') ?? DateTime.now(),
      numInvoices: (json['num_invoices'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      collected: (json['collected'] as num?)?.toDouble() ?? 0,
      pending: (json['pending'] as num?)?.toDouble() ?? 0,
      avgTicket: (json['avg_ticket'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Ganancia/Pérdida mensual
class ProfitLossMonthly {
  final int year;
  final int month;
  final double revenue;
  final double fixedExpenses;
  final double variableExpenses;
  final double grossProfit;

  ProfitLossMonthly({
    required this.year,
    required this.month,
    this.revenue = 0,
    this.fixedExpenses = 0,
    this.variableExpenses = 0,
    this.grossProfit = 0,
  });

  factory ProfitLossMonthly.fromJson(Map<String, dynamic> json) {
    return ProfitLossMonthly(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      fixedExpenses: (json['fixed_expenses'] as num?)?.toDouble() ?? 0,
      variableExpenses: (json['variable_expenses'] as num?)?.toDouble() ?? 0,
      grossProfit: (json['gross_profit'] as num?)?.toDouble() ?? 0,
    );
  }

  double get totalExpenses => fixedExpenses + variableExpenses;
  double get profitMargin => revenue > 0 ? (grossProfit / revenue) * 100 : 0;
}

/// Análisis de productos por cliente
class CustomerProductAnalysis {
  final String customerId;
  final String customerName;
  final String? productName;
  final String? productCode;
  final int purchaseCount;
  final double totalQuantity;
  final double totalSpent;
  final DateTime? firstPurchase;
  final DateTime? lastPurchase;
  final double avgQuantityPerPurchase;

  CustomerProductAnalysis({
    required this.customerId,
    required this.customerName,
    this.productName,
    this.productCode,
    this.purchaseCount = 0,
    this.totalQuantity = 0,
    this.totalSpent = 0,
    this.firstPurchase,
    this.lastPurchase,
    this.avgQuantityPerPurchase = 0,
  });

  factory CustomerProductAnalysis.fromJson(Map<String, dynamic> json) {
    return CustomerProductAnalysis(
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      productName: json['product_name'],
      productCode: json['product_code'],
      purchaseCount: (json['purchase_count'] as num?)?.toInt() ?? 0,
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      firstPurchase: json['first_purchase'] != null
          ? DateTime.tryParse(json['first_purchase'])
          : null,
      lastPurchase: json['last_purchase'] != null
          ? DateTime.tryParse(json['last_purchase'])
          : null,
      avgQuantityPerPurchase:
          (json['avg_quantity_per_purchase'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Cuentas por cobrar con antigüedad
class AccountReceivableAging {
  final String customerId;
  final String customerName;
  final String? documentNumber;
  final String invoiceId;
  final String? fullNumber;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final double total;
  final double paidAmount;
  final double pendingAmount;
  final String agingBucket;
  final int daysOverdue;

  AccountReceivableAging({
    required this.customerId,
    required this.customerName,
    this.documentNumber,
    required this.invoiceId,
    this.fullNumber,
    this.issueDate,
    this.dueDate,
    this.total = 0,
    this.paidAmount = 0,
    this.pendingAmount = 0,
    this.agingBucket = 'current',
    this.daysOverdue = 0,
  });

  factory AccountReceivableAging.fromJson(Map<String, dynamic> json) {
    return AccountReceivableAging(
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      documentNumber: json['document_number'],
      invoiceId: json['invoice_id'] ?? '',
      fullNumber: json['full_number'],
      issueDate: json['issue_date'] != null
          ? DateTime.tryParse(json['issue_date'])
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'])
          : null,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0,
      agingBucket: json['aging_bucket'] ?? 'current',
      daysOverdue: (json['days_overdue'] as num?)?.toInt() ?? 0,
    );
  }

  String get agingBucketLabel {
    switch (agingBucket) {
      case 'current':
        return 'Vigente';
      case '1-30 days':
        return '1-30 días';
      case '31-60 days':
        return '31-60 días';
      case '61-90 days':
        return '61-90 días';
      case 'over 90 days':
        return '+90 días';
      default:
        return agingBucket;
    }
  }
}

/// CLV del cliente
class CustomerCLV {
  final double totalRevenue;
  final int totalPurchases;
  final double avgPurchaseValue;
  final int monthsAsCustomer;
  final double monthlyRevenue;
  final double estimatedAnnualValue;

  CustomerCLV({
    this.totalRevenue = 0,
    this.totalPurchases = 0,
    this.avgPurchaseValue = 0,
    this.monthsAsCustomer = 0,
    this.monthlyRevenue = 0,
    this.estimatedAnnualValue = 0,
  });

  factory CustomerCLV.fromJson(Map<String, dynamic> json) {
    return CustomerCLV(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      totalPurchases: (json['total_purchases'] as num?)?.toInt() ?? 0,
      avgPurchaseValue: (json['avg_purchase_value'] as num?)?.toDouble() ?? 0,
      monthsAsCustomer: (json['months_as_customer'] as num?)?.toInt() ?? 0,
      monthlyRevenue: (json['monthly_revenue'] as num?)?.toDouble() ?? 0,
      estimatedAnnualValue:
          (json['estimated_annual_value'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Productos relacionados
class RelatedProduct {
  final String productName;
  final String? productCode;
  final int timesBoughtTogether;
  final double avgQuantity;

  RelatedProduct({
    required this.productName,
    this.productCode,
    this.timesBoughtTogether = 0,
    this.avgQuantity = 0,
  });

  factory RelatedProduct.fromJson(Map<String, dynamic> json) {
    return RelatedProduct(
      productName: json['related_product_name'] ?? '',
      productCode: json['related_product_code'],
      timesBoughtTogether:
          (json['times_bought_together'] as num?)?.toInt() ?? 0,
      avgQuantity: (json['avg_quantity'] as num?)?.toDouble() ?? 0,
    );
  }
}
/// DSO (Days Sales Outstanding) mensual para tendencia
class DSOMonthly {
  final int year;
  final int month;
  final double dso; // Días promedio de cobro
  final double totalReceivables;
  final double totalSales;
  final double collectionRate; // Tasa de cobro %

  DSOMonthly({
    required this.year,
    required this.month,
    this.dso = 0,
    this.totalReceivables = 0,
    this.totalSales = 0,
    this.collectionRate = 0,
  });

  factory DSOMonthly.fromJson(Map<String, dynamic> json) {
    return DSOMonthly(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? 1,
      dso: (json['dso'] as num?)?.toDouble() ?? 0,
      totalReceivables: (json['total_receivables'] as num?)?.toDouble() ?? 0,
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
      collectionRate: (json['collection_rate'] as num?)?.toDouble() ?? 0,
    );
  }
  
  String get monthName {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[(month - 1).clamp(0, 11)];
  }
}

/// KPIs de Cobranzas completos
class CollectionKPIs {
  final double dso; // Days Sales Outstanding
  final double cei; // Collection Effectiveness Index (0-100)
  final double arTurnover; // Rotación de cartera (veces/año)
  final double badDebtRatio; // Tasa de deuda incobrable %
  final double totalReceivables;
  final double totalCollected;
  final double overdueAmount;
  final int overdueInvoices;
  final int totalInvoices;

  CollectionKPIs({
    this.dso = 0,
    this.cei = 0,
    this.arTurnover = 0,
    this.badDebtRatio = 0,
    this.totalReceivables = 0,
    this.totalCollected = 0,
    this.overdueAmount = 0,
    this.overdueInvoices = 0,
    this.totalInvoices = 0,
  });

  factory CollectionKPIs.fromJson(Map<String, dynamic> json) {
    return CollectionKPIs(
      dso: (json['dso'] as num?)?.toDouble() ?? 0,
      cei: (json['cei'] as num?)?.toDouble() ?? 0,
      arTurnover: (json['ar_turnover'] as num?)?.toDouble() ?? 0,
      badDebtRatio: (json['bad_debt_ratio'] as num?)?.toDouble() ?? 0,
      totalReceivables: (json['total_receivables'] as num?)?.toDouble() ?? 0,
      totalCollected: (json['total_collected'] as num?)?.toDouble() ?? 0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? 0,
      overdueInvoices: (json['overdue_invoices'] as num?)?.toInt() ?? 0,
      totalInvoices: (json['total_invoices'] as num?)?.toInt() ?? 0,
    );
  }
  
  // Estado del CEI
  String get ceiStatus {
    if (cei >= 90) return 'Excelente';
    if (cei >= 80) return 'Bueno';
    if (cei >= 70) return 'Regular';
    return 'Crítico';
  }
  
  // Color del CEI
  String get ceiColor {
    if (cei >= 90) return 'green';
    if (cei >= 80) return 'blue';
    if (cei >= 70) return 'orange';
    return 'red';
  }
}

/// Producto con análisis ABC (Pareto)
class ProductABC {
  final String productName;
  final String? productCode;
  final double totalRevenue;
  final double cumulativeRevenue;
  final double cumulativePercentage;
  final String abcCategory; // A, B, C
  final int timesSold;
  final double totalQuantity;

  ProductABC({
    required this.productName,
    this.productCode,
    this.totalRevenue = 0,
    this.cumulativeRevenue = 0,
    this.cumulativePercentage = 0,
    this.abcCategory = 'C',
    this.timesSold = 0,
    this.totalQuantity = 0,
  });

  factory ProductABC.fromTopSellingProduct(TopSellingProduct product, double cumRevenue, double total) {
    final cumPct = total > 0 ? (cumRevenue / total * 100) : 0.0;
    String category;
    if (cumPct <= 80) {
      category = 'A';
    } else if (cumPct <= 95) {
      category = 'B';
    } else {
      category = 'C';
    }
    
    return ProductABC(
      productName: product.productName ?? 'Sin nombre',
      productCode: product.productCode,
      totalRevenue: product.totalRevenue,
      cumulativeRevenue: cumRevenue,
      cumulativePercentage: cumPct.toDouble(),
      abcCategory: category,
      timesSold: product.timesSold,
      totalQuantity: product.totalQuantity,
    );
  }
}