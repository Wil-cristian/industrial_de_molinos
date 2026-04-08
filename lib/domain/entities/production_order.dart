import 'composite_product.dart';

class ProductionOrderMaterial {
  final String id;
  final String productionOrderId;
  final String materialId;
  final String materialName;
  final String? materialCode;
  final double requiredQuantity;
  final double consumedQuantity;
  final String unit;
  final double estimatedCost;
  final String? pieceTitle;
  final String? dimensions;

  const ProductionOrderMaterial({
    required this.id,
    required this.productionOrderId,
    required this.materialId,
    required this.materialName,
    this.materialCode,
    required this.requiredQuantity,
    required this.consumedQuantity,
    required this.unit,
    required this.estimatedCost,
    this.pieceTitle,
    this.dimensions,
  });

  double get pendingQuantity =>
      (requiredQuantity - consumedQuantity).clamp(0, requiredQuantity);

  factory ProductionOrderMaterial.fromJson(Map<String, dynamic> json) {
    final material = json['materials'] as Map<String, dynamic>?;
    return ProductionOrderMaterial(
      id: (json['id'] ?? '').toString(),
      productionOrderId: (json['production_order_id'] ?? '').toString(),
      materialId: (json['material_id'] ?? '').toString(),
      materialName: (json['material_name'] ?? material?['name'] ?? 'Material')
          .toString(),
      materialCode: (json['material_code'] ?? material?['code'])?.toString(),
      requiredQuantity: (json['required_quantity'] as num?)?.toDouble() ?? 0,
      consumedQuantity: (json['consumed_quantity'] as num?)?.toDouble() ?? 0,
      unit: (json['unit'] ?? 'UND').toString(),
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble() ?? 0,
      pieceTitle: json['piece_title']?.toString(),
      dimensions: json['dimensions']?.toString(),
    );
  }
}

class ProductionStage {
  final String id;
  final String productionOrderId;
  final int sequenceOrder;
  final String processName;
  final String workstation;
  final double estimatedHours;
  final double actualHours;
  final String status;
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final List<String> resources;
  final List<String> materialIds;
  final List<String> assetIds;
  final String? report;
  final String? notes;

  const ProductionStage({
    required this.id,
    required this.productionOrderId,
    required this.sequenceOrder,
    required this.processName,
    required this.workstation,
    required this.estimatedHours,
    required this.actualHours,
    required this.status,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.resources = const [],
    this.materialIds = const [],
    this.assetIds = const [],
    this.report,
    this.notes,
  });

  bool get isDone => status == 'completada';

  ProductionStage copyWith({
    String? id,
    String? productionOrderId,
    int? sequenceOrder,
    String? processName,
    String? workstation,
    double? estimatedHours,
    double? actualHours,
    String? status,
    String? assignedEmployeeId,
    String? assignedEmployeeName,
    List<String>? resources,
    List<String>? materialIds,
    List<String>? assetIds,
    String? report,
    String? notes,
  }) {
    return ProductionStage(
      id: id ?? this.id,
      productionOrderId: productionOrderId ?? this.productionOrderId,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      processName: processName ?? this.processName,
      workstation: workstation ?? this.workstation,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      status: status ?? this.status,
      assignedEmployeeId: assignedEmployeeId ?? this.assignedEmployeeId,
      assignedEmployeeName: assignedEmployeeName ?? this.assignedEmployeeName,
      resources: resources ?? this.resources,
      materialIds: materialIds ?? this.materialIds,
      assetIds: assetIds ?? this.assetIds,
      report: report ?? this.report,
      notes: notes ?? this.notes,
    );
  }

  factory ProductionStage.fromJson(Map<String, dynamic> json) {
    final employee = json['employees'] as Map<String, dynamic>?;
    final firstName = (employee?['first_name'] ?? '').toString().trim();
    final lastName = (employee?['last_name'] ?? '').toString().trim();
    final fullName = [firstName, lastName].where((v) => v.isNotEmpty).join(' ');

    final rawResources = json['resources'];
    final List<String> parsedResources;
    if (rawResources is List) {
      parsedResources = rawResources
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    } else {
      parsedResources = const [];
    }

    return ProductionStage(
      id: (json['id'] ?? '').toString(),
      productionOrderId: (json['production_order_id'] ?? '').toString(),
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 0,
      processName: (json['process_name'] ?? 'Proceso').toString(),
      workstation: (json['workstation'] ?? '').toString(),
      estimatedHours: (json['estimated_hours'] as num?)?.toDouble() ?? 0,
      actualHours: (json['actual_hours'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? 'pendiente').toString(),
      assignedEmployeeId: json['assigned_employee_id']?.toString(),
      assignedEmployeeName: fullName.isEmpty ? null : fullName,
      resources: parsedResources,
      materialIds: _parseStringList(json['material_ids']),
      assetIds: _parseStringList(json['asset_ids']),
      report: json['report']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  Map<String, dynamic> toJson() {
    return {
      'production_order_id': productionOrderId,
      'sequence_order': sequenceOrder,
      'process_name': processName,
      'workstation': workstation,
      'estimated_hours': estimatedHours,
      'actual_hours': actualHours,
      'status': status,
      'assigned_employee_id': assignedEmployeeId,
      'resources': resources,
      'material_ids': materialIds,
      'asset_ids': assetIds,
      'report': report,
      'notes': notes,
    };
  }
}

class ProductionOrder {
  final String id;
  final String code;
  final String productId;
  final String productCode;
  final String productName;
  final double quantity;
  final String status;
  final String priority;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductionOrderMaterial> materials;
  final List<ProductionStage> stages;
  final String? invoiceId;
  final int sortOrder;

  const ProductionOrder({
    required this.id,
    required this.code,
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.status,
    required this.priority,
    this.startDate,
    this.dueDate,
    this.completedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.materials = const [],
    this.stages = const [],
    this.invoiceId,
    this.sortOrder = 0,
  });

  double get progress {
    if (stages.isEmpty) return 0;
    final completed = stages.where((s) => s.isDone).length;
    return completed / stages.length;
  }

  double get estimatedMaterialCost =>
      materials.fold(0, (sum, m) => sum + m.estimatedCost);

  int get completedStages => stages.where((s) => s.isDone).length;

  double get totalEstimatedHours =>
      stages.fold(0.0, (sum, s) => sum + s.estimatedHours);

  double get totalActualHours =>
      stages.fold(0.0, (sum, s) => sum + s.actualHours);

  /// null when no actual hours recorded yet
  double? get efficiencyRatio {
    if (totalActualHours == 0) return null;
    return totalEstimatedHours / totalActualHours;
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == 'completada') return false;
    return dueDate!.isBefore(DateTime.now());
  }

  /// Positive = days remaining; negative = days overdue; null = no due date
  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  ProductionOrder copyWith({
    String? id,
    String? code,
    String? productId,
    String? productCode,
    String? productName,
    double? quantity,
    String? status,
    String? priority,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? completedAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProductionOrderMaterial>? materials,
    List<ProductionStage>? stages,
    String? invoiceId,
    int? sortOrder,
  }) {
    return ProductionOrder(
      id: id ?? this.id,
      code: code ?? this.code,
      productId: productId ?? this.productId,
      productCode: productCode ?? this.productCode,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      materials: materials ?? this.materials,
      stages: stages ?? this.stages,
      invoiceId: invoiceId ?? this.invoiceId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory ProductionOrder.fromJson(
    Map<String, dynamic> json, {
    List<ProductionOrderMaterial> materials = const [],
    List<ProductionStage> stages = const [],
  }) {
    final product = json['products'] as Map<String, dynamic>?;

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.parse(value.toString());
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      return DateTime.parse(value.toString());
    }

    return ProductionOrder(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productCode: (json['product_code'] ?? product?['code'] ?? '').toString(),
      productName: (json['product_name'] ?? product?['name'] ?? 'Producto')
          .toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? 'planificada').toString(),
      priority: (json['priority'] ?? 'media').toString(),
      startDate: parseNullableDate(json['start_date']),
      dueDate: parseNullableDate(json['due_date']),
      completedAt: parseNullableDate(json['completed_at']),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      materials: materials,
      stages: stages,
      invoiceId: json['invoice_id']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProcessChainItem {
  final String processName;
  final String? employeeId;
  final String? employeeName;

  const ProcessChainItem({
    required this.processName,
    this.employeeId,
    this.employeeName,
  });
}

class ProductionOrderCreationInput {
  final CompositeProduct product;
  final double quantity;
  final DateTime? dueDate;
  final String priority;
  final String? notes;
  final List<ProcessChainItem> processChain;

  const ProductionOrderCreationInput({
    required this.product,
    required this.quantity,
    this.dueDate,
    this.priority = 'media',
    this.notes,
    this.processChain = const [],
  });
}
