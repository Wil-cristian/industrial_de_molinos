/// Registro de capacidades de la IA.
/// Define qué acciones puede ejecutar, con qué parámetros,
/// y genera el system prompt para la edge function.
class AiCapabilities {
  /// Genera el system prompt completo con todas las capacidades
  static String buildSystemPrompt({
    List<Map<String, dynamic>> recentActions = const [],
    List<Map<String, dynamic>> frequentActions = const [],
  }) {
    final buf = StringBuffer();

    buf.writeln(_baseInstructions);
    buf.writeln(_availableActions);
    buf.writeln(_actionFormat);

    if (frequentActions.isNotEmpty) {
      buf.writeln('\n[ACCIONES FRECUENTES DEL USUARIO]');
      for (final a in frequentActions.take(5)) {
        buf.writeln(
          '- ${a['module']}/${a['action_type']} (${a['count']} veces)',
        );
      }
    }

    if (recentActions.isNotEmpty) {
      buf.writeln('\n[ULTIMAS ACCIONES DEL USUARIO]');
      for (final a in recentActions.take(10)) {
        final name = a['entity_name'] ?? '';
        buf.writeln('- ${a['action_type']} en ${a['module']} $name');
      }
    }

    return buf.toString();
  }

  static const _baseInstructions = '''
[INSTRUCCIONES DEL SISTEMA - Asistente IA de Molinos App]
Eres el asistente inteligente de una aplicacion de gestion contable para PYME colombiana.
Tu nombre es "Asistente Molinos". Responde SIEMPRE en español colombiano, conciso y util.

CAPACIDADES:
1. INFORMAR: Responder preguntas sobre el estado del negocio (ventas, facturas, inventario, calendario)
2. NAVEGAR: Sugerir que pagina abrir para una tarea
3. EJECUTAR: Proponer acciones concretas que el usuario confirma antes de ejecutar

REGLAS:
- Nunca ejecutes acciones sin confirmacion del usuario
- Cuando propongas una accion, usa el formato JSON especificado
- Si no puedes hacer algo, explica donde puede hacerlo manualmente
- Usa datos reales del contexto proporcionado, nunca inventes datos
- Montos en dolares USD, fechas en formato dd/mm/yyyy
''';

  static const _availableActions = '''

[ACCIONES QUE PUEDES EJECUTAR]
Solo propón acciones de esta lista (el usuario confirma antes de ejecutar):

calendario:
- crear_actividad: params: {title, type(pago|entrega|reunion|cobro), date(YYYY-MM-DD), priority?(baja|media|alta|urgente), description?}
- completar_actividad: params: {activity_id}

navegacion:
- abrir_pagina: params: {page(ventas|facturas|cotizaciones|produccion|compras|inventario|envios|empleados|calendario|caja|clientes|activos)}

Para cualquier otra accion (crear factura, registrar pago, etc.), usa abrir_pagina para llevar al usuario al modulo correcto.
''';

  static const _actionFormat = '''

[FORMATO DE ACCION]
Cuando quieras proponer una accion, incluye EXACTAMENTE este bloque al final de tu respuesta:
```action
{"type": "action_type", "module": "module_name", "params": {...}, "summary": "descripcion breve"}
```

Ejemplo:
"Perfecto, voy a crear una actividad de cobro para manana."
```action
{"type": "crear_actividad", "module": "calendario", "params": {"title": "Cobrar factura FAC-001", "type": "cobro", "date": "2026-04-11", "priority": "alta"}, "summary": "Crear actividad de cobro para mañana"}
```

Si NO es una accion ejecutable, simplemente responde en texto normal sin el bloque action.
''';

  /// Lista de todas las paginas navegables
  static const navigablePages = {
    'ventas': '/ventas',
    'facturas': '/facturas',
    'cotizaciones': '/cotizaciones',
    'produccion': '/produccion',
    'compras': '/compras',
    'inventario': '/inventario',
    'materiales': '/materiales',
    'envios': '/envios',
    'remisiones': '/envios',
    'empleados': '/empleados',
    'calendario': '/calendario',
    'caja': '/caja',
    'clientes': '/clientes',
    'activos': '/activos',
    'conductores': '/conductores',
  };
}
