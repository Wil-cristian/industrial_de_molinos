# Ordenes de Produccion: Referencias y Modelo Operativo

## Objetivo
Definir un modelo para trabajar ordenes de produccion conectadas a productos (BOM), con procesos en cadena, mesas de trabajo, tareas, empleados, recursos e informes.

## Referencias consultadas (resumen)
- OEE.com (Takt Time): define takt como ritmo de produccion para alinear capacidad con demanda; impacta diseno de proceso, programacion y operacion de planta.
- Wikipedia (Flow/Mass Production): describe produccion en flujo/cadena con etapas secuenciales, subensambles y estandarizacion para reducir variabilidad.
- Wikipedia (Lean Manufacturing): enfoque de mejora continua, eliminacion de desperdicios, flujo tirado por demanda y estandar de trabajo.
- Wikipedia (MES): el MES controla ejecucion en piso de planta entre ERP y operacion real (estado, trazabilidad, calidad, tiempos).
- Atlassian Workflow: buenas practicas de flujo: estados claros, responsabilidades, monitorizacion continua y mejora iterativa.

## Principios para Industrial de Molinos
1. Orden central: toda OP nace de un producto compuesto para heredar BOM de materiales.
2. Flujo en cadena: cada OP tiene etapas secuenciales (ejemplo: corte -> torno -> soldadura -> armado -> calidad).
3. Mesa de trabajo por etapa: cada etapa asigna empleado, recursos, horas y reporte tecnico.
4. Visibilidad operativa: estado de OP y de etapa debe ser visible con avance porcentual.
5. Mejora continua: permitir agregar, editar, reordenar y adaptar etapas por tipo de producto.

## Estructura funcional recomendada
- Encabezado OP:
  - Codigo OP, producto, cantidad, fechas, prioridad, estado global.
- BOM operativo:
  - Material, cantidad requerida, cantidad consumida, costo estimado.
- Flujo de etapas:
  - Secuencia, proceso, workstation, estado de etapa.
- Mesa de trabajo:
  - Empleado asignado, recursos (maquinas/herramientas), horas estimadas/reales, informe.
- Reporte final OP:
  - Variaciones de tiempo y materiales, observaciones de calidad, cierre.

## Estados sugeridos
- OP: planificada, en_proceso, pausada, completada, cancelada.
- Etapa: pendiente, en_proceso, bloqueada, completada.

## KPIs iniciales recomendados
- Cumplimiento de fecha: OP completadas a tiempo / OP completadas.
- Eficiencia de etapa: horas estimadas vs horas reales.
- Avance de cadena: etapas completadas / etapas totales por OP.
- Consumo de material: requerido vs consumido por material.

## Lineamientos UI/UX (alineados al diseno del proyecto)
- Usar jerarquia visual clara:
  - Lista de OP a la izquierda (desktop) y detalle operativo a la derecha.
  - En mobile, lista y detalle en modal/bottom sheet.
- Chips de estado por color semantico y barra de progreso por OP.
- Tarjetas separadas por modulo:
  - BOM
  - Flujo de procesos
  - Mesa de trabajo
- Acciones rapidas:
  - Nueva OP
  - Cambiar estado OP
  - Agregar/editar etapa

## Uso de Stitch para co-diseno UX
- Prompt base sugerido para Stitch:
  "Disena una vista ERP de ordenes de produccion industrial con layout maestro-detalle. Incluye lista de OP, detalle con BOM, flujo de etapas secuenciales, asignacion de empleados y recursos por etapa, y reporte tecnico. Estilo Material 3 industrial, alta legibilidad de datos, prioridad en estados y progreso."
- Validar que el output respete:
  - Paleta semantica del proyecto.
  - Tipografia y espaciado del design system.
  - Breakpoints mobile/tablet/desktop ya definidos.

## Implementacion tecnica en app (esta iteracion)
- Nuevo modulo: production_orders
- Entidades: ProductionOrder, ProductionStage, ProductionOrderMaterial
- Persistencia: tablas nuevas en migracion 055
- Vista: pagina dedicada con CRUD de OP y etapas
- Integracion: router, sidebar, menu movil y acciones rapidas

## Siguiente fase recomendada
1. Reordenamiento drag-and-drop de etapas.
2. Registro de consumo real de materiales por etapa.
3. Creacion automatica de tareas en employee_tasks por etapa asignada.
4. Dashboard de KPIs de produccion (lead time, atraso, cuello de botella).
