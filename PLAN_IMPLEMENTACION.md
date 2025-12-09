# 📋 PLAN DE IMPLEMENTACIÓN - Industrial de Molinos

## OBJETIVO GENERAL
Conectar completamente la aplicación Flutter con Supabase para que:
- ✅ Se lean datos reales de la base de datos
- ✅ Se muestren correctamente en el Dashboard
- ✅ Se creen registros al hacer operaciones (facturas, ventas, cotizaciones)
- ✅ Se actualicen los datos en tiempo real

---

## FASE 1: PREPARACIÓN DE DATOS EN SUPABASE ✅ (YA HECHO)

### 1.1 Schema SQL
- ✅ Tablas creadas: customers, products, quotations, invoices, materials, etc.
- ✅ Políticas RLS configuradas
- ✅ Funciones y triggers listos

### 1.2 Datos de Prueba Necesarios
**Acciones requeridas:**
- [ ] Insertar 5-10 clientes de prueba en tabla `customers`
- [ ] Insertar 10-15 productos de prueba en tabla `products`
- [ ] Verificar que `material_prices` tiene datos (ya tiene 16 registros)
- [ ] Verificar que `categories` tiene datos (ya tiene 4 registros)

---

## FASE 2: BACKEND - DATASOURCES Y PROVIDERS 📊

### Estado Actual
- ✅ `customers_datasource.dart` - CRUD completo
- ✅ `products_datasource.dart` - CRUD completo
- ✅ `quotations_datasource.dart` - CRUD completo
- ✅ `materials_datasource.dart` - CRUD completo
- ✅ Todos los providers (Riverpod 3.0) funcionan

### Acciones Requeridas
- [ ] **Crear `invoices_datasource.dart`** - CRUD para facturas/ventas
  - `createInvoice()`
  - `updateInvoice()`
  - `getInvoices()`
  - `getInvoiceById()`
  - `deleteInvoice()`

- [ ] **Crear `invoices_provider.dart`** - Provider para gestionar estado de facturas
  - `InvoicesState` con lista de facturas
  - `InvoicesNotifier` con métodos load/create/update/delete
  - NotifierProvider<InvoicesNotifier, InvoicesState>

- [ ] **Crear `payments_datasource.dart`** - CRUD para pagos
  - `createPayment()`
  - `getPaymentsByInvoice()`

- [ ] **Crear `payments_provider.dart`** - Provider para gestionar pagos

---

## FASE 3: INTERFAZ DE USUARIO 🎨

### 3.1 Dashboard (HOME PAGE) ✅ Parcialmente hecho
**Estado:**
- ✅ Layout scrollable (menú lateral resuelto)
- ✅ Cards de resumen conectadas a providers

**Acciones necesarias:**
- [ ] Agregar sección "Últimas Ventas" con tabla de facturas
- [ ] Agregar gráfico de ventas del mes
- [ ] Agregar sección "Cotizaciones Pendientes" con acciones rápidas
- [ ] Hacer que se actualicen datos en tiempo real

### 3.2 Products Page ❌ No completa
**Acciones:**
- [ ] Mostrar lista de productos con scroll
- [ ] Agregar botón "Nuevo Producto"
- [ ] Implementar búsqueda/filtrado por categoría
- [ ] Mostrar indicador de stock bajo
- [ ] Permitir editar productos

### 3.3 Invoices/Sales Page ❌ No existe
**Acciones:**
- [ ] Crear `lib/presentation/pages/sales_page.dart` (nueva página de ventas)
- [ ] Listar todas las facturas
- [ ] Botón "Nueva Venta"
- [ ] Mostrar estado de pago (draft, issued, paid, etc.)
- [ ] Permitir editar/eliminar facturas

### 3.4 New Sales/Invoice Page ❌ No existe
**Acciones:**
- [ ] Crear `lib/presentation/pages/new_sale_page.dart`
- [ ] Formulario con:
  - Selección de cliente
  - Selección de productos
  - Cantidad y precio
  - Cálculo automático de totales
  - Botón guardar/crear factura

### 3.5 Quotations Page 🔶 Parcial
**Acciones:**
- [ ] Mejorar vista de cotizaciones
- [ ] Agregar opción "Convertir a Venta"

### 3.6 Customers Page ✅ Ya completa
- ✅ Lista de clientes
- ✅ Agregar cliente
- ✅ Búsqueda

---

## FASE 4: FUNCIONALIDADES CLAVE 🔑

### 4.1 Crear Venta (Factura)
**Flujo:**
1. Usuario selecciona "Nueva Venta"
2. Selecciona cliente
3. Agrega productos y cantidades
4. Sistema calcula: subtotal, IGV, total
5. Guarda en tabla `invoices` + `invoice_items`
6. Actualiza estado en provider
7. Muestra confirmación

### 4.2 Crear Cotización
**Flujo:**
1. Usuario selecciona "Nueva Cotización"
2. Selecciona cliente
3. Selecciona componentes/materiales
4. Sistema calcula costos automáticamente
5. Guarda en tabla `quotations` + `quotation_items`
6. Opción de convertir a venta

### 4.3 Registrar Pago
**Flujo:**
1. En lista de facturas, usuario abre una factura
2. Selecciona "Registrar Pago"
3. Ingresa monto y método de pago
4. Guarda en tabla `payments`
5. Actualiza estado de factura (draft → issued/paid)

### 4.4 Actualizar Stock
**Flujo:**
1. Al crear factura, restar cantidad del stock de productos
2. Guardar movimiento en `stock_movements`
3. Actualizar campo `stock` en tabla `products`

---

## FASE 5: INTEGRACIONES Y VALIDACIONES ✓

### 5.1 Validaciones de Datos
- [ ] Cliente debe estar seleccionado
- [ ] Productos deben tener cantidad > 0
- [ ] Precios deben ser válidos
- [ ] Stock no puede ser negativo

### 5.2 Manejo de Errores
- [ ] Try-catch en todas las operaciones Supabase
- [ ] Mensajes de error legibles al usuario
- [ ] Loading states en botones

### 5.3 Sincronización en Tiempo Real
- [ ] Usar listeners de Supabase para actualizaciones
- [ ] Refresh automático de listas cuando cambian datos

---

## FASE 6: REPORTES Y ANALYTICS 📈

**Acciones opcionales:**
- [ ] Gráfico de ventas por mes
- [ ] Resumen de clientes con deuda
- [ ] Productos más vendidos
- [ ] Proyección de ingresos

---

## CRONOGRAMA PROPUESTO

### Sprint 1 (Inmediato) - Funcionalidad básica
1. Insertar datos de prueba en Supabase
2. Crear datasources para invoices y payments
3. Crear providers para invoices y payments
4. Dashboard mostrando datos reales

### Sprint 2 - Páginas principales
1. Sales/Invoices page completamente funcional
2. New Sale page con formulario
3. Productos page mejorada

### Sprint 3 - Refinamiento
1. Reportes básicos
2. Validaciones robustas
3. Pruebas y bug fixes

---

## VERIFICACIONES FINALES ✓

Antes de dar por completado:
- [ ] Dashboard carga datos reales de Supabase
- [ ] Se pueden crear facturas
- [ ] Se pueden crear cotizaciones
- [ ] Se pueden registrar pagos
- [ ] Stock se actualiza automáticamente
- [ ] Datos persisten en Supabase
- [ ] No hay errores en consola
- [ ] La app responde rápidamente

---

## NOTAS TÉCNICAS

### Archivos a Crear
```
lib/data/datasources/
  ├── invoices_datasource.dart (NEW)
  └── payments_datasource.dart (NEW)

lib/data/providers/
  ├── invoices_provider.dart (NEW)
  └── payments_provider.dart (NEW)

lib/presentation/pages/
  ├── sales_page.dart (NEW)
  ├── new_sale_page.dart (NEW)
  └── (mejorar quotations_page.dart)
```

### Archivos a Actualizar
```
lib/presentation/pages/
  ├── dashboard_page.dart (agregar secciones)
  ├── products_page.dart (hacer funcional)
  └── quotations_page.dart (mejorar)

lib/data/providers/
  └── providers.dart (exportar nuevos providers)
```

---

## COMENZAR CON

**Fase 1 Completa:** Datos de prueba en Supabase
**Fase 2 Completa:** Datasources y providers
**Fase 3.1 Prioritario:** Dashboard actualizado
**Fase 3.3 Prioritario:** Nueva página de ventas

---

¿Estás listo para comenzar? Confirma y pasamos al siguiente paso 🚀
