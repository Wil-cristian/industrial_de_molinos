# Plan de Reestructuración — Módulo Escaneo de Facturas de Venta

**Fecha:** Marzo 20, 2026  
**Archivo principal:** `lib/presentation/widgets/sale_invoice_scan_dialog.dart` (2,549 líneas)  
**Objetivo:** Corregir la lógica de inventario, rediseñar la UI para móvil, y mejorar la experiencia de creación de materiales, proveedores y productos desde datos escaneados por IA.

---

## Diagnóstico de Problemas Actuales

### 1. Lógica de Inventario Invertida / Incorrecta

**Problema:** Al guardar facturas de venta escaneadas, los materiales se están **sumando** al inventario en lugar de **restarse**.

**Causa raíz identificada:** La función RPC `deduct_inventory_for_invoice` SÍ resta correctamente (`stock = stock - qty`), pero el problema es más fundamental:

- **Estas son facturas HISTÓRICAS** — las ventas ya ocurrieron hace meses. El inventario físico actual ya refleja esas ventas. No debería ajustarse el stock actual al registrar facturas del pasado.
- **Materiales nuevos creados desde scan** se crean con `stock: 0`, luego la deducción los pone en negativo (`0 - qty = -qty`), lo cual es incorrecto y confuso.
- **Items sin `material_id`/`product_id`** simplemente no generan movimiento de inventario alguno, creando inconsistencia.

**Lógica correcta que debemos implementar:**

| Escenario | Acción sobre inventario |
|-----------|------------------------|
| Factura de venta **actual** (fecha = hoy o reciente) | SÍ descontar stock + crear movimiento `outgoing` |
| Factura de venta **histórica** (fecha > 30 días antigüedad) | **NO** modificar stock actual. Solo registrar factura + deuda CxC |
| Material nuevo creado desde scan | Crear con `stock: 0`, SIN deducción posterior |
| Item sin asociar a producto/material | Solo registrar en `invoice_items` sin mover inventario |

**Propuesta de implementación:**

```dart
// En _saveOneInvoice():
final isHistorical = DateTime.now().difference(issueDate).inDays > 30;

if (isHistorical) {
  // Solo cambiar status SIN deducir inventario
  await InvoicesDataSource.setStatusDirect(invoice.id, 'issued');
  // Recalcular balance del cliente (CxC) manualmente
  await CustomersDataSource.recalculateBalance(customer.id);
} else {
  // Factura reciente → deducir stock normalmente
  await InvoicesDataSource.updateStatus(invoice.id, 'issued');
}
```

> **Nota:** El método `setStatusDirect()` ya existe en el datasource (línea 306). Solo hay que agregar la recalculación del balance del cliente después.

**Alternativa mejorada:** Dar al usuario la opción explícita con un checkbox:
- ☑ "Descontar inventario" (default OFF para facturas con fecha > 30 días)
- El usuario decide caso por caso

---

### 2. UI No Adaptada a Móvil

**Problema:** El diálogo usa un ancho fijo que no se adapta al celular. El usuario usa el teléfono para tomar fotos y escanear, pero todo se ve diminuto.

**Causa en el código actual (línea ~341):**
```dart
final sw = MediaQuery.of(context).size.width;
final w = sw > 1200 ? 960.0 : sw * 0.92; // El 92% sigue siendo un diálogo flotante
// Dialog con maxHeight: 860 fijo
```

**Problemas específicos:**
- Tablas con muchas columnas que no caben en pantalla móvil
- Botones de acción pequeños e inaccesibles
- Campos de texto muy angostos
- Scroll horizontal necesario pero difícil de usar en touch
- Controles de selección de cliente/material demasiado compactos

---

### 3. Creación de Materiales Limitada

**Problema:** `_createMaterialFromItem()` crea un material muy básico (solo nombre, precio y código genérico) sin dar al usuario la oportunidad de completar los datos.

**Lo que debería pasar:**
1. La IA extrae el nombre y lo que pueda del item escaneado
2. El usuario toca "Editar Material" 
3. Se abre el **mismo formulario completo** de materiales que existe en `materials_page.dart` (línea ~1833)
4. Los campos vienen pre-llenados con lo que la IA pudo extraer
5. El usuario completa categoría, dimensiones, precios, etc.
6. Se guarda y se asocia automáticamente al item de la factura

---

### 4. Creación/Edición de Proveedores

**Problema similar:** No hay forma de editar/crear un proveedor con datos completos desde el scan.

> **Nota:** En facturas de VENTA, el "proveedor" no aplica directamente — el actor principal es el CLIENTE. Sin embargo, algunos items escaneados podrían necesitar asociarse a un proveedor para tracking de costos. Este punto se evalúa como secundario.

---

### 5. Creación de Productos — El Caso Complejo

**Problema:** Los productos en este sistema son complejos (llevan receta, componentes de materiales, costos laborales, márgenes). `_createProductFromItem()` actual solo crea un producto stub sin receta.

**Complejidad:** El formulario de productos (`composite_products_page.dart`) incluye:
- Componentes materiales con calculadora de peso
- Modos de cálculo: Lámina | Tubo | Eje | Eje Cuadrado
- Horas de mano de obra, tasas, costos indirectos
- Margen de utilidad

---

## Plan de Implementación

### FASE 1: Rediseño Mobile-First de la UI
**Prioridad: ALTA** | **Archivos: `sale_invoice_scan_dialog.dart`**

#### 1.1 — Convertir de Dialog a Página Completa en Móvil

```
Escritorio (>900dp): Mantener como Dialog/overlay grande
Móvil (<600dp): Página completa (fullscreen) con navegación por pasos
Tablet (600-900dp): Dialog expandido, 95% del ancho
```

**Cambios clave:**
- En móvil, usar `Navigator.push()` con `MaterialPageRoute` en lugar de `showDialog()`
- Implementar `Scaffold` con `AppBar` que muestre el paso actual
- Botones de acción como `BottomNavigationBar` o `FloatingActionButton`

#### 1.2 — Paso 1: Selección de Imagen (Mobile-friendly)

```
┌──────────────────────────┐
│  ←  Escanear Ventas      │
│                          │
│  ┌────────────────────┐  │
│  │                    │  │
│  │    📷 CÁMARA       │  │
│  │   (botón grande)   │  │
│  │                    │  │
│  └────────────────────┘  │
│                          │
│  ┌────────────────────┐  │
│  │  📁 Archivo/Galería│  │
│  └────────────────────┘  │
│                          │
│  ── Facturas cargadas ── │
│  │ fact_001.jpg  ✅ esc. │
│  │ fact_002.jpg  ⏳ pend.│
│  └───────────────────────│
│                          │
│  [ Escanear todas ]      │
└──────────────────────────┘
```

#### 1.3 — Paso 2: Revisión (Diseño de Tarjetas para Móvil)

En lugar de tabla, usar **tarjetas desplegables (ExpansionTile)** por factura:

```
┌──────────────────────────┐
│  ←  Revisar (3 facturas) │
├──────────────────────────┤
│ ▼ Factura #1234          │
│   Cliente: Juan Pérez    │  ← Tappable → dialog de selección
│   NIT: 900.123.456       │
│   Fecha: 15/01/2026      │
│   Total: $2,450,000      │
│                          │
│   ── Items ──            │
│   ┌────────────────────┐ │
│   │ Tubo 2" SCH40      │ │
│   │ 5 UND × $120,000   │ │
│   │ → Tubo Acero 2"  ✏️│ │  ← Material asociado + botón editar
│   └────────────────────┘ │
│   ┌────────────────────┐ │
│   │ Lámina HR 1/4"     │ │
│   │ 3 UND × $85,000    │ │
│   │ → ⚠️ Sin asociar  │ │
│   │  [Asociar] [Crear] │ │  ← Dos botones claros
│   └────────────────────┘ │
│                          │
│   ☐ Descontar inventario │  ← Checkbox (OFF por defecto si histórica)
│                          │
│ ▶ Factura #1235          │
│ ▶ Factura #1236          │
├──────────────────────────┤
│  [Guardar 3 facturas]    │  ← Botón fijo abajo
└──────────────────────────┘
```

#### 1.4 — Breakpoints de Layout

| Zona | Escritorio (>900dp) | Móvil (<600dp) |
|------|---------------------|----------------|
| Contenedor | Dialog 960px, centrado | Fullscreen page |
| Header factura | Row horizontal | Column vertical |
| Campos cliente | 2 columnas (nombre + NIT) | 1 columna apilada |
| Tabla items | DataTable con columnas | Cards/ListTiles apiladas |
| Campos totales | Row 4 campos | Wrap/Column 2×2 |
| Botones acción | Row de TextButtons | Column de ElevatedButtons grandes |
| Navegación pasos | Stepper horizontal | Stepper vertical o AppBar |

#### 1.5 — Tamaño Mínimo de Touch Targets

- Todos los botones: mínimo 48×48dp
- Campos de texto: altura mínima 56dp
- Chips/tags de asociación: mínimo 40dp de alto
- Padding entre elementos interactivos: mínimo 8dp

---

### FASE 2: Corregir Lógica de Inventario
**Prioridad: ALTA** | **Archivos: `sale_invoice_scan_dialog.dart`**

#### 2.1 — Agregar control de deducción de inventario

**En `_BatchItem`:** Agregar campo `bool deductInventory`

```dart
class _BatchItem {
  // ... campos existentes ...
  bool deductInventory; // false por defecto si es factura histórica
}
```

**En `populateFromResult()`:** Auto-detectar si es histórica:

```dart
// En populateFromResult(), después de parsear la fecha:
final invoiceDate = r.invoiceDate ?? DateTime.now();
final daysSinceInvoice = DateTime.now().difference(invoiceDate).inDays;
deductInventory = daysSinceInvoice <= 30; // Solo si es reciente
```

#### 2.2 — Modificar `_saveOneInvoice()`

```dart
if (item.deductInventory) {
  // Factura reciente — descontar stock normalmente
  await InvoicesDataSource.updateStatus(invoice.id, 'issued');
} else {
  // Factura histórica — solo registrar sin mover inventario
  await InvoicesDataSource.setStatusDirect(invoice.id, 'issued');
  // Pero SÍ recalcular balance del cliente (genera la deuda CxC)
  if (customer.id.isNotEmpty) {
    await CustomersDataSource.recalculateBalance(customer.id);
  }
}
```

#### 2.3 — UI del control

En la tarjeta de cada factura, mostrar:

```
☐ Descontar inventario (materiales y productos)
   ℹ️ Desactivado automáticamente para facturas con más de 30 días
```

---

### FASE 3: Mejorar Creación/Edición de Materiales
**Prioridad: ALTA** | **Archivos: `sale_invoice_scan_dialog.dart`, extraer form de `materials_page.dart`**

#### 3.1 — Extraer el formulario de material a widget reutilizable

**Actualmente:** El formulario de material está embebido en `materials_page.dart` (~200 líneas, dentro de `_showMaterialFormDialog`).

**Acción:** Crear `lib/presentation/widgets/material_form_dialog.dart`:

```dart
class MaterialFormDialog extends ConsumerStatefulWidget {
  final mat.Material? initial;         // null = crear nuevo
  final String? suggestedName;         // pre-llenado por IA
  final double? suggestedUnitPrice;    // pre-llenado por IA
  final String? suggestedUnit;         // pre-llenado por IA
  final String? suggestedCategory;     // sugerencia IA (nullable)
  
  static Future<mat.Material?> show(BuildContext context, {
    mat.Material? initial,
    String? suggestedName,
    double? suggestedUnitPrice,
    String? suggestedUnit,
  }) { ... }
}
```

**Campos del formulario (mismos que materials_page):**
- Código (auto-generado si vacío)
- Nombre* (pre-llenado por IA)
- Descripción
- Categoría (dropdown)
- Precio costo (pre-llenado por IA con `unitPrice`)
- Precio/KG (si aplica)
- Precio unitario (pre-llenado por IA)
- Stock (default 0 para scan)
- Stock mínimo
- Proveedor (dropdown + quick-create)
- Ubicación
- Dimensiones (diámetro, espesor, largo, ancho)
- Unidad (pre-llenado por IA)

#### 3.2 — Integrar en el scan dialog

Cuando el usuario toca ✏️ "Editar Material" en un item:

```dart
final editedMaterial = await MaterialFormDialog.show(
  context,
  initial: itemMatch.matchedMaterial, // si ya existe
  suggestedName: itemMatch.scannedItem.description,
  suggestedUnitPrice: itemMatch.scannedItem.unitPrice,
  suggestedUnit: itemMatch.scannedItem.unit,
);

if (editedMaterial != null) {
  setState(() {
    itemMatch.matchedMaterial = editedMaterial;
    itemMatch.matchedProduct = null;
  });
}
```

#### 3.3 — Flujo de botones por item

Para cada item escaneado, mostrar exactamente estos botones:

| Estado del item | Botones disponibles |
|----------------|---------------------|
| ✅ Asociado a material existente | `[Cambiar] [Editar ✏️] [Quitar]` |
| ✅ Asociado a producto existente | `[Cambiar] [Editar ✏️] [Quitar]` |
| ⚠️ Sin asociar | `[Buscar existente] [Crear Material] [Crear Producto]` |
| 🆕 Material recién creado | `[Editar ✏️] [Quitar]` |

---

### FASE 4: Mejorar Creación/Edición de Clientes
**Prioridad: MEDIA** | **Archivos: `sale_invoice_scan_dialog.dart`**

#### 4.1 — Extraer formulario de cliente a widget reutilizable

Similar a materiales, extraer de `customers_page.dart` (~300 líneas):

```dart
class CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? initial;
  final String? suggestedName;
  final String? suggestedDocument;
  final String? suggestedDocumentType; // 'NIT', 'CC', etc.
  final String? suggestedPhone;
  final String? suggestedEmail;
  final String? suggestedAddress;
  
  static Future<Customer?> show(BuildContext context, { ... });
}
```

#### 4.2 — Integrar en el scan

En la sección de cliente de cada factura:

```
Cliente: [dropdown búsqueda] [+ Nuevo desde IA]
         Juan Pérez (NIT 900.123.456) ✏️
```

El botón ✏️ abre `CustomerFormDialog` con datos pre-llenados de:
- `result.buyerName`
- `result.buyerDocument`
- Teléfono/email si la IA los extrajo

---

### FASE 5: Manejo de Productos (Complejo)
**Prioridad: MEDIA-BAJA** | **Requiere diseño cuidadoso**

#### 5.1 — Opciones para productos escaneados

Los productos son complejos. Propuesta de flujo en 3 niveles:

**Nivel 1 — Producto Simple (sin receta):**
- La IA extrae nombre, precio, unidad
- Se crea un producto básico sin componentes
- El usuario puede agregarle receta después desde la página de productos

**Nivel 2 — Asociar a Producto Existente:**
- Búsqueda inteligente por nombre similar
- Si el producto ya existe, solo asociar y seguir

**Nivel 3 — Producto con Receta (diferido):**
- Marcar el item como "Producto pendiente de completar"
- Crear el producto stub con una flag `needsRecipe: true`
- En la página de productos, mostrar badge "⚠️ Sin receta"
- El usuario va después a completar la receta con la calculadora completa

#### 5.2 — UI de creación rápida de producto

```dart
class QuickProductDialog extends StatefulWidget {
  final String suggestedName;
  final double suggestedPrice;
  final String suggestedUnit;
  
  // Campos mínimos:
  // - Nombre* (pre-llenado)
  // - Precio venta* (pre-llenado)
  // - Precio costo
  // - Unidad (pre-llenado)
  // - Categoría (dropdown)
  // - ☐ Requiere receta (checkbox → se completa después)
}
```

#### 5.3 — NO intentar crear recetas desde el scan

La creación de recetas requiere:
- Seleccionar materiales específicos
- Calcular pesos según dimensiones
- Definir procesos de manufactura
- Todo eso es imposible de extraer de una factura de venta

**Decisión:** Solo crear el producto básico desde scan. La receta se agrega después en la página de productos.

---

### FASE 6: Panel de Reconciliación de Deudas
**Prioridad: MEDIA** | **Mejora la utilidad del módulo**

#### 6.1 — Resumen post-guardado

Después de guardar todas las facturas, mostrar un resumen de reconciliación:

```
┌──────────────────────────────┐
│  ✅ Reconciliación Completa  │
│                              │
│  3 facturas registradas      │
│  2 clientes actualizados     │
│  $7,250,000 en deudas CxC   │
│                              │
│  ── Deudas por Cliente ──    │
│  Juan Pérez:    $3,200,000   │
│  María López:   $4,050,000   │
│                              │
│  5 materiales asociados      │
│  2 productos nuevos creados  │
│  (inventario NO descontado)  │
│                              │
│  [Ver facturas] [Cerrar]     │
└──────────────────────────────┘
```

#### 6.2 — Comparación de deudas

Agregar vista que compare:
- Balance actual del cliente (antes del scan)
- Facturas escaneadas pendientes
- Nuevo balance proyectado

```
Cliente: Juan Pérez
  Balance anterior:  $1,000,000
  + Factura #1234:   $2,200,000
  = Nuevo balance:   $3,200,000  (crédito: $5,000,000)
```

---

## Orden de Ejecución

| # | Tarea | Fase | Esfuerzo |
|---|-------|------|----------|
| 1 | ~~Corregir lógica de inventario (agregar `deductInventory` flag y lógica condicional)~~ | F2 | ✅ Hecho |
| 2 | ~~Rediseñar Step 1 (selector de imagen) para móvil~~ | F1.2 | ✅ Hecho |
| 3 | ~~Rediseñar Step 2 (revisión) con tarjetas en vez de tablas~~ | F1.3 | ✅ Hecho |
| 4 | ~~Extraer `MaterialFormDialog` reutilizable~~ | F3.1 | ✅ Hecho |
| 5 | ~~Integrar form de material en scan con pre-llenado IA~~ | F3.2 | ✅ Hecho |
| 6 | ~~Diálogo de creación de cliente con pre-llenado~~ | F4 | ✅ Hecho |
| 7 | ~~Picker de cliente responsive~~ | F4 | ✅ Hecho |
| 8 | ~~Crear `QuickProductDialog` con modo simple~~ | F5.2 | ✅ Hecho |
| 9 | ~~Implementar resumen de reconciliación~~ | F6.1 | ✅ Hecho |
| 10 | ~~Implementar comparación de deudas~~ | F6.2 | ✅ Hecho |

---

## Archivos a Crear/Modificar

| Archivo | Acción |
|---------|--------|
| `lib/presentation/widgets/sale_invoice_scan_dialog.dart` | **Modificar** — Rediseño completo de UI + lógica de inventario |
| `lib/presentation/widgets/material_form_dialog.dart` | **Crear** — Formulario reutilizable extraído de materials_page |
| `lib/presentation/widgets/customer_form_dialog.dart` | **Crear** — Formulario reutilizable extraído de customers_page |
| `lib/presentation/widgets/quick_product_dialog.dart` | **Crear** — Formulario simplificado de producto |
| `lib/presentation/pages/materials_page.dart` | **Modificar** — Reemplazar form inline con `MaterialFormDialog` |
| `lib/presentation/pages/customers_page.dart` | **Modificar** — Reemplazar form inline con `CustomerFormDialog` |

---

## Notas Técnicas

1. **Encoding:** Todos los archivos `.dart` deben ser UTF-8 sin BOM.
2. **Estado:** Mantener Riverpod + `setState` local para el dialog (no crear provider nuevo para el scan).
3. **Responsive:** Usar `LayoutBuilder` + breakpoints, NO `Expanded` dentro de `AlertDialog.actions`.
4. **Touch targets:** Mínimo 48×48dp para todo lo que sea tappable.
5. **El `setStatusDirect()` ya existe** en `InvoicesDataSource` (línea 306) — solo cambia status sin tocar inventario.
6. **`recalculateBalance()`** ya existe en `CustomersDataSource` — asegura que la deuda CxC se refleje aunque no se descuente inventario.
