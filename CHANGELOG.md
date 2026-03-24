# Changelog - Industrial de Molinos

Todos los cambios notables en esta aplicacion seran documentados en este archivo.

El formato esta basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

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
