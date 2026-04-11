# Changelog - Industrial de Molinos

Todos los cambios notables en esta aplicacion seran documentados en este archivo.

El formato esta basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## [1.0.9] - 2026-04-10

### Mejorado
- Cotizaciones responsive: página de nueva cotización completamente adaptada para móvil (~360dp)
  - Sidebar oculto en móvil, accesible via FAB con bottom sheet
  - Header, stepper, componentes y costos con layout compacto
  - Diálogo de selección de producto: lista a pantalla completa + detalle en bottom sheet
  - Preview de cotización: fullscreen con tabs (Cliente/Empresa)
  - Diálogos de agregar componente/material/producto redimensionados
- Mano de Obra en cotizaciones: toggle entre porcentaje (%) y valor fijo ($), igual que en ventas
- Ventas responsive: correcciones adicionales de overflow en página de nueva venta

### Corregido
- Overflow en diálogo de selección de producto en móvil (ListTile con trailing aplastado)
- DropdownButtonFormField con isExpanded en todos los dropdowns de cotización
- Múltiples overflows de Row en paneles estrechos de cotización

## [1.0.8] - 2026-04-08

### Mejorado
- Limpieza masiva de código muerto: ~55 warnings eliminados (~1000+ líneas de código no utilizado)
- Mano de Obra en ventas: toggle entre porcentaje (%) y valor fijo ($), visible en recibo y detalle
- Analítica de inventario: línea histórica con score (salud) basado en stock real por mes
- Triggers automáticos para rastrear cambios de stock en productos y materiales

### Corregido
- Import incorrecto en production_orders_datasource (package:supabase interno → supabase_flutter)
- Dead code en quotations_datasource (operador ?? innecesario en customerName)
- Backfill de movimientos históricos de stock desde invoice_items

## [1.0.7] - 2026-04-08

### Nuevo
- Órdenes de producción: números de orden (#1, #2...) en cada tarjeta
- Botones rápidos pausar/reanudar y eliminar en lista de órdenes
- Drag-to-reorder: arrastrar para reorganizar órdenes (mobile y desktop)
- Auto-código de materiales por categoría (formato XX-NN-SUBCAT-####)
- Campo sort_order en production_orders (migración 079)
- Campo code_prefix en material_categories (migración 078)

### Corregido
- Precios Compra/Venta separados correctamente en productos compuestos
- Preview de componentes usa effectiveCostPrice para Compra y effectivePrice para Venta

## [1.0.6] - 2026-03-31

### Mejorado
- Actualización general de estabilidad y correcciones

## [1.0.5] - 2026-03-28

### Corregido
- Fix crítico: createStage solo guardaba 4 de 12 campos (materiales, activos, empleado, reporte, notas se perdían)
- Fix crítico: updateStage y updateOrderStatus fallaban silenciosamente (sin .select().single())
- Fix UX: diálogos mostraban éxito aunque la operación fallara (agregado try/catch con error SnackBar)

### Nuevo
- Módulo Remisiones y Entregas completo (migración 073)
- Vinculación factura ↔ orden de producción
- Auto-llenado de ítems desde materiales de OP
- Deducción automática de stock al despachar remisión
- Alertas de plazos de entrega vencidos (tarjeta resumen + badge días)

## [1.0.4] - 2026-03-25

### Corregido
- Fix panel de auditoría: error silenciado impedía cargar logs para admin (Monica)
- Fix navegación móvil: índice incorrecto para IVA Control en bottom nav bar
- Fix overflow en móvil: diálogo de categorías de materiales (RenderFlex 90px)
- Fix bug auth: campo email_change NULL causaba error al consultar schema

### Mejorado
- Pestaña Nómina (empleados): tarjetas resumen responsivas con LayoutBuilder (3 filas en móvil)
- Pestaña Nómina: header responsivo, tabla oculta columna SALARIO QUINC. en móvil
- Pestaña Nómina: 5 diálogos convertidos a ConstrainedBox para móvil
- Pestaña Principal (empleados): filtros responsivos con LayoutBuilder
- Pestaña Principal: 8 diálogos convertidos a ConstrainedBox para móvil
- Pestaña Incapacidades: tarjetas resumen 2x2 en móvil, diálogo responsivo
- Pestaña Préstamos: 3 diálogos convertidos a ConstrainedBox para móvil
- Diálogo de categorías de materiales: título con Expanded y botón compacto

## [1.0.3] - 2026-03-20

### Corregido
- Fix overflow en móvil: dashboard (fila de facturas), suppliers (header + tiles)
- Fix overflow en móvil: purchase_orders (header), accounting (header + journal entries)
- Fix overflow en móvil: expenses (nombre de persona en tarjeta de movimiento)
- Fix creación de cuentas de empleado: error "duplicate key user_profiles_user_id_key"
  - Conflicto entre trigger on_auth_user_created y función create_employee_account
  - Cambiado INSERT a UPSERT con ON CONFLICT DO UPDATE

### Mejorado
- Headers responsivos con LayoutBuilder en suppliers, purchase_orders y accounting
- Journal entries usan Wrap en vez de Row para adaptarse a pantallas angostas
- Widgets reutilizables: CustomerFormDialog, QuickProductDialog extraídos
- Refactorizado materials_page y customers_page para usar los widgets compartidos

### Agregado
- Migración 064: fix upsert user_profiles en create_employee_account
- Soporte Android APK

## [1.0.0] - 2026-03-11

### Agregado
- Release inicial del Sistema de Gestion
- Caja Diaria: registro de ingresos y egresos
- Contabilidad: plan de cuentas, libro diario, balance general
- Facturacion: cotizaciones y facturas de venta
- Inventario: materiales, productos compuestos, recetas
- Ordenes de compra y gestion de proveedores
- Gestion de empleados y nomina
- Control de activos fijos
- Control de IVA
- Dashboard con indicadores principales
- Reportes y analiticas
- Calendario de actividades
- Sistema de auto-actualizacion integrado
- Instalador para Windows

### Notas
- Backend: Supabase (PostgreSQL)
- Plataforma: Windows Desktop
