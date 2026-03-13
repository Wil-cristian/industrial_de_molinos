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
      report: json['report']?.toString(),
      notes: json['notes']?.toString(),
    );
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
  });

  double get progress {
    if (stages.isEmpty) return 0;
    final completed = stages.where((s) => s.isDone).length;
    return completed / stages.length;
  }

  double get estimatedMaterialCost =>
      materials.fold(0, (sum, m) => sum + m.estimatedCost);

  int get completedStages => stages.where((s) => s.isDone).length;

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
    );
  }
}

class ProductionOrderCreationInput {
  final CompositeProduct product;
  final double quantity;
  final DateTime? dueDate;
  final String priority;
  final String? notes;
  final List<String> processChain;

  const ProductionOrderCreationInput({
    required this.product,
    required this.quantity,
    this.dueDate,
    this.priority = 'media',
    this.notes,
    this.processChain = const [],
  });
}
