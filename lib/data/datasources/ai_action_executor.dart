import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/colombia_time.dart';
import '../../domain/entities/activity.dart';
import '../datasources/activities_datasource.dart';
import '../datasources/ai_action_logger.dart';
import '../datasources/ai_capabilities.dart';

/// Resultado de la ejecucion de una accion
class ActionResult {
  final bool success;
  final String message;

  const ActionResult({required this.success, required this.message});
}

/// Parsea la respuesta de la IA y extrae acciones propuestas
class AiActionParser {
  static final _actionRegex = RegExp(
    r'```action\s*\n?(.*?)\n?```',
    dotAll: true,
  );

  /// Extrae un bloque de accion del texto de respuesta
  static Map<String, dynamic>? parseAction(String response) {
    final match = _actionRegex.firstMatch(response);
    if (match == null) return null;

    try {
      final jsonStr = match.group(1)?.trim();
      if (jsonStr == null) return null;
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing AI action: $e');
      return null;
    }
  }

  /// Extrae el texto de respuesta sin el bloque de accion
  static String getTextWithoutAction(String response) {
    return response.replaceAll(_actionRegex, '').trim();
  }
}

/// Ejecuta acciones propuestas por la IA (después de confirmación del usuario)
class AiActionExecutor {
  /// Ejecuta una accion y retorna resultado
  static Future<ActionResult> execute(
    Map<String, dynamic> action,
    BuildContext context,
  ) async {
    final type = action['type'] as String? ?? '';
    final module = action['module'] as String? ?? '';
    final params = action['params'] as Map<String, dynamic>? ?? {};

    try {
      switch (type) {
        // ═══════ NAVEGACION ═══════
        case 'abrir_pagina':
          return _navigateTo(params, context);

        // ═══════ CALENDARIO ═══════
        case 'crear_actividad':
          return await _createActivity(params);
        case 'completar_actividad':
          return await _completeActivity(params);

        // Las demas acciones redirigen al modulo correspondiente
        default:
          return _redirectToModule(type, module, params, context);
      }
    } catch (e) {
      return ActionResult(
        success: false,
        message: 'Error ejecutando accion: $e',
      );
    }
  }

  static ActionResult _navigateTo(
    Map<String, dynamic> params,
    BuildContext context,
  ) {
    final page = params['page'] as String? ?? '';
    final route = AiCapabilities.navigablePages[page.toLowerCase()];

    if (route != null) {
      context.go(route);
      AiActionLogger.logNavigation(page);
      return ActionResult(success: true, message: 'Navegando a $page');
    }

    return ActionResult(
      success: false,
      message: 'Pagina "$page" no encontrada',
    );
  }

  static Future<ActionResult> _createActivity(
    Map<String, dynamic> params,
  ) async {
    try {
      final title = params['title'] as String? ?? 'Nueva actividad';
      final typeStr = params['type'] as String? ?? 'pago';
      final dateStr = params['date'] as String?;
      final priorityStr = params['priority'] as String? ?? 'media';
      final description = params['description'] as String? ?? '';

      final date = dateStr != null
          ? DateTime.tryParse(dateStr) ?? ColombiaTime.now()
          : ColombiaTime.now();

      final type = _parseActivityType(typeStr);
      final priority = _parseActivityPriority(priorityStr);

      final activity = Activity(
        id: '',
        title: title,
        description: description,
        activityType: type,
        startDate: date,
        dueDate: date,
        status: ActivityStatus.pending,
        priority: priority,
        color: _activityColor(type),
        createdAt: ColombiaTime.now(),
        updatedAt: ColombiaTime.now(),
      );

      final result = await ActivitiesDatasource.createActivity(activity);
      if (result != null) {
        AiActionLogger.logActivity(
          'crear_actividad',
          activityId: result.id,
          activityName: title,
          params: params,
        );
        return ActionResult(
          success: true,
          message:
              'Actividad "$title" creada para el ${date.day}/${date.month}/${date.year}',
        );
      }
      return const ActionResult(
        success: false,
        message: 'No se pudo crear la actividad',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Error: $e');
    }
  }

  static Future<ActionResult> _completeActivity(
    Map<String, dynamic> params,
  ) async {
    try {
      final id = params['activity_id'] as String? ?? '';
      if (id.isEmpty) {
        return const ActionResult(
          success: false,
          message: 'Se necesita el ID de la actividad',
        );
      }

      final success = await ActivitiesDatasource.completeActivity(id);
      if (success) {
        AiActionLogger.logActivity('completar_actividad', activityId: id);
        return const ActionResult(
          success: true,
          message: 'Actividad completada',
        );
      }
      return const ActionResult(
        success: false,
        message: 'No se pudo completar la actividad',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Error: $e');
    }
  }

  static ActionResult _redirectToModule(
    String type,
    String module,
    Map<String, dynamic> params,
    BuildContext context,
  ) {
    // Mapear modulo a ruta
    final routes = {
      'facturas': '/facturas',
      'cotizaciones': '/cotizaciones',
      'produccion': '/produccion',
      'compras': '/compras',
      'envios': '/envios',
      'inventario': '/inventario',
      'empleados': '/empleados',
    };

    final route = routes[module];
    if (route != null) {
      context.go(route);
      AiActionLogger.log(actionType: type, module: module, parameters: params);
      return ActionResult(
        success: true,
        message:
            'Abriendo modulo de $module. Puedes completar la acción "$type" desde ahi.',
      );
    }

    return ActionResult(
      success: false,
      message:
          'Accion "$type" aun no soportada para ejecucion automatica. Puedes hacerlo manualmente desde $module.',
    );
  }

  static ActivityType _parseActivityType(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'pago':
        return ActivityType.payment;
      case 'entrega':
        return ActivityType.delivery;
      case 'reunion':
        return ActivityType.meeting;
      case 'cobro':
        return ActivityType.collection;
      default:
        return ActivityType.general;
    }
  }

  static ActivityPriority _parseActivityPriority(String p) {
    switch (p.toLowerCase()) {
      case 'baja':
        return ActivityPriority.low;
      case 'media':
        return ActivityPriority.medium;
      case 'alta':
        return ActivityPriority.high;
      case 'urgente':
        return ActivityPriority.urgent;
      default:
        return ActivityPriority.medium;
    }
  }

  static String _activityColor(ActivityType type) {
    switch (type) {
      case ActivityType.payment:
        return '#4CAF50';
      case ActivityType.delivery:
        return '#2196F3';
      case ActivityType.meeting:
        return '#FF9800';
      case ActivityType.collection:
        return '#F44336';
      case ActivityType.projectStart:
      case ActivityType.projectEnd:
        return '#9C27B0';
      case ActivityType.reminder:
        return '#FF5722';
      case ActivityType.maintenance:
        return '#607D8B';
      case ActivityType.stockAlert:
        return '#E91E63';
      case ActivityType.general:
        return '#2196F3';
    }
  }
}
