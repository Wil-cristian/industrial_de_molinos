# Plan: Módulo de Remisiones y Entregas

> **Fecha**: 28/03/2026  
> **Estado**: Planificación  
> **Página actual**: `PendingDeliveriesPage` → Se transforma en `ShipmentsPage`  
> **Ruta**: `/shipments` (antes `/pending-deliveries`)

---

## 1. Visión General

Transformar la página actual de "Entregas Pendientes" (que solo muestra facturas con adelanto) en un módulo completo de **Remisiones y Entregas** que integra:

1. **Entregas futuras** conectadas a Producción (estado en tiempo real)
2. **Crear órdenes de envío** con detalle de todo lo que va en el camión
3. **Generar e imprimir remisiones** (documento formal de despacho)
4. **Historial de remisiones** creadas y enviadas

### Flujo Principal

```
Producción (OP completada) → Orden de Envío → Remisión (documento impreso) → Entrega confirmada
```

---

## 2. Conceptos Clave

| Concepto | Descripción |
|---|---|
| **Orden de Producción (OP)** | Ya existe. Status: `planificada`, `en_proceso`, `pausada`, `completada`, `cancelada` |
| **Orden de Envío** | NUEVA entidad. Agrupa ítems a despachar (productos terminados + materiales de inventario + piezas). Vinculada a cliente y factura. |
| **Remisión** | Documento impreso generado desde una Orden de Envío. Contiene: destinatario, transportista, lista de ítems, cantidades, firmas. Tiene número consecutivo `REM-XXXXX`. |
| **Entrega Futura** | Vista de OPs en proceso conectadas a facturas con `delivery_date`. Muestra progreso de producción en tiempo real. |

---

## 3. Estructura de la Página (Tabs)

La nueva página tiene **3 pestañas principales**:

### Tab 1: Entregas Futuras
- Muestra OPs en proceso/completadas vinculadas a facturas con `delivery_date`
- Para cada entrega muestra:
  - Número de factura + cliente
  - Fecha de entrega pactada (con indicador de atraso)
  - Progreso de producción (barra + etapas completadas/total)
  - Estado de la OP: `en_proceso` | `completada` | `pausada`
  - Materiales pendientes de comprar
- Acciones: Ver detalle OP, Crear orden de envío (cuando OP completada)

### Tab 2: Remisiones
- **Crear nueva remisión** (botón principal)
- Lista de remisiones existentes con:
  - Número `REM-XXXXX`
  - Fecha de creación
  - Cliente/Destinatario
  - # ítems
  - Estado: `borrador` | `despachada` | `entregada` | `anulada`
  - Transportista
- Acciones: Editar (si borrador), Imprimir PDF, Marcar entregada, Anular
- Filtros: Por estado, por fecha, por cliente

### Tab 3: Historial de Envíos
- Timeline de todos los envíos realizados
- Filtros por rango de fechas, cliente, estado
- Resumen: Total enviado, en tránsito, entregado

---

## 4. Entidad: Orden de Envío / Remisión

### 4.1 Tabla `shipment_orders` (Orden de Envío / Remisión)

```sql
CREATE TABLE IF NOT EXISTS shipment_orders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(20) NOT NULL UNIQUE,  -- REM-00001
    invoice_id      UUID REFERENCES invoices(id) ON DELETE SET NULL,
    production_order_id UUID REFERENCES production_orders(id) ON DELETE SET NULL,
    customer_id     UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name   VARCHAR(200) NOT NULL,
    customer_address TEXT,
    
    -- Transporte
    carrier_name    VARCHAR(200),        -- Nombre del transportista
    carrier_document VARCHAR(50),        -- CC/NIT transportista
    vehicle_plate   VARCHAR(20),         -- Placa del vehículo
    driver_name     VARCHAR(200),        -- Conductor
    driver_document VARCHAR(50),         -- CC conductor
    
    -- Datos del envío
    dispatch_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    delivery_date   DATE,                -- Fecha estimada de entrega
    delivered_at    TIMESTAMPTZ,         -- Fecha real de entrega
    
    -- Estado
    status          VARCHAR(20) NOT NULL DEFAULT 'borrador',
    
    -- Observaciones
    notes           TEXT,
    internal_notes  TEXT,                -- Notas internas (no se imprimen)
    
    -- Firmas (para el documento impreso)
    prepared_by     VARCHAR(200),        -- Quien preparó
    approved_by     VARCHAR(200),        -- Quien aprobó
    received_by     VARCHAR(200),        -- Quien recibió (se llena al entregar)
    
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT shipment_orders_status_check
        CHECK (status IN ('borrador', 'despachada', 'en_transito', 'entregada', 'anulada'))
);

CREATE INDEX IF NOT EXISTS idx_shipment_orders_status ON shipment_orders(status);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_invoice ON shipment_orders(invoice_id);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_production ON shipment_orders(production_order_id);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_customer ON shipment_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_dispatch ON shipment_orders(dispatch_date);
```

### 4.2 Tabla `shipment_order_items` (Ítems de la Remisión)

```sql
CREATE TABLE IF NOT EXISTS shipment_order_items (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_order_id   UUID NOT NULL REFERENCES shipment_orders(id) ON DELETE CASCADE,
    
    -- Tipo de ítem
    item_type           VARCHAR(20) NOT NULL DEFAULT 'producto',
    -- Referencias opcionales
    product_id          UUID REFERENCES products(id) ON DELETE SET NULL,
    material_id         UUID REFERENCES materials(id) ON DELETE SET NULL,
    
    -- Detalle
    description         VARCHAR(500) NOT NULL,
    code                VARCHAR(100),
    quantity            DECIMAL(12,3) NOT NULL DEFAULT 1,
    unit                VARCHAR(20) NOT NULL DEFAULT 'UND',
    weight_kg           DECIMAL(10,3),      -- Peso en kg (opcional)
    dimensions          VARCHAR(100),        -- Largo x Ancho x Alto
    
    -- Observaciones por ítem
    notes               TEXT,
    
    sequence_order      INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT shipment_items_type_check
        CHECK (item_type IN ('producto', 'material', 'pieza', 'herramienta', 'otro'))
);

CREATE INDEX IF NOT EXISTS idx_shipment_items_order ON shipment_order_items(shipment_order_id);
CREATE INDEX IF NOT EXISTS idx_shipment_items_product ON shipment_order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_shipment_items_material ON shipment_order_items(material_id);
```

### 4.3 Tabla `shipment_order_sequence` (Consecutivo)

```sql
CREATE TABLE IF NOT EXISTS shipment_order_sequence (
    id          INTEGER PRIMARY KEY DEFAULT 1,
    last_number INTEGER NOT NULL DEFAULT 0,
    prefix      VARCHAR(10) NOT NULL DEFAULT 'REM',
    CONSTRAINT shipment_sequence_single_row CHECK (id = 1)
);

INSERT INTO shipment_order_sequence (id, last_number, prefix)
VALUES (1, 0, 'REM')
ON CONFLICT (id) DO NOTHING;

-- Función para obtener el siguiente número
CREATE OR REPLACE FUNCTION next_shipment_number()
RETURNS VARCHAR AS $$
DECLARE
    new_number INTEGER;
    prefix_val VARCHAR;
BEGIN
    UPDATE shipment_order_sequence
    SET last_number = last_number + 1
    WHERE id = 1
    RETURNING last_number, prefix INTO new_number, prefix_val;
    
    RETURN prefix_val || '-' || LPAD(new_number::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;
```

### 4.4 Vincular Producción con Factura (columna nueva)

```sql
-- Vincular OP con factura para rastrear entregas futuras
ALTER TABLE production_orders
    ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_production_orders_invoice ON production_orders(invoice_id);
```

---

## 5. Entidades Dart

### 5.1 `ShipmentOrder`

```dart
// lib/domain/entities/shipment_order.dart

enum ShipmentStatus { borrador, despachada, enTransito, entregada, anulada }
enum ShipmentItemType { producto, material, pieza, herramienta, otro }

class ShipmentOrder {
  final String id;
  final String code;              // REM-00001
  final String? invoiceId;
  final String? productionOrderId;
  final String? customerId;
  final String customerName;
  final String? customerAddress;
  
  // Transporte
  final String? carrierName;
  final String? carrierDocument;
  final String? vehiclePlate;
  final String? driverName;
  final String? driverDocument;
  
  // Fechas
  final DateTime dispatchDate;
  final DateTime? deliveryDate;
  final DateTime? deliveredAt;
  
  // Estado
  final ShipmentStatus status;
  
  // Notas
  final String? notes;
  final String? internalNotes;
  
  // Firmas
  final String? preparedBy;
  final String? approvedBy;
  final String? receivedBy;
  
  final List<ShipmentOrderItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Campos de relación (opcionales, para display)
  final String? invoiceFullNumber;
  final String? productionOrderCode;
}

class ShipmentOrderItem {
  final String id;
  final String shipmentOrderId;
  final ShipmentItemType itemType;
  final String? productId;
  final String? materialId;
  final String description;
  final String? code;
  final double quantity;
  final String unit;
  final double? weightKg;
  final String? dimensions;
  final String? notes;
  final int sequenceOrder;
}
```

---

## 6. Arquitectura de Archivos

```
lib/
├── domain/entities/
│   └── shipment_order.dart          # ShipmentOrder + ShipmentOrderItem
├── data/
│   ├── datasources/
│   │   └── shipments_datasource.dart    # CRUD estático contra Supabase
│   └── providers/
│       └── shipments_provider.dart      # ShipmentsState + ShipmentsNotifier
├── presentation/
│   ├── pages/
│   │   └── shipments_page.dart          # Página principal con 3 tabs
│   └── widgets/
│       ├── shipment_form_dialog.dart    # Dialog para crear/editar remisión
│       ├── shipment_print_preview.dart  # Vista previa para impresión
│       └── future_deliveries_card.dart  # Card de entrega futura (con OP)
```

---

## 7. DataSource: `ShipmentsDataSource`

```dart
class ShipmentsDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  // Obtener todas las remisiones
  static Future<List<ShipmentOrder>> getAll({String? status}) async { ... }
  
  // Obtener por ID con ítems
  static Future<ShipmentOrder?> getById(String id) async { ... }
  
  // Crear nueva remisión (genera código automático)
  static Future<ShipmentOrder?> create(ShipmentOrder order) async { ... }
  
  // Actualizar remisión (solo si borrador)
  static Future<void> update(ShipmentOrder order) async { ... }
  
  // Agregar ítem a remisión
  static Future<void> addItem(ShipmentOrderItem item) async { ... }
  
  // Eliminar ítem
  static Future<void> removeItem(String itemId) async { ... }
  
  // Cambiar estado (despachar, entregar, anular)
  static Future<void> updateStatus(String id, ShipmentStatus status) async { ... }
  
  // Obtener OPs completadas vinculadas a facturas (entregas futuras)
  static Future<List<Map<String, dynamic>>> getFutureDeliveries() async { ... }
  
  // Obtener siguiente número de remisión
  static Future<String> getNextCode() async { ... }
}
```

---

## 8. Provider: `ShipmentsProvider`

```dart
class ShipmentsState {
  final List<ShipmentOrder> shipments;
  final List<FutureDelivery> futureDeliveries;
  final bool isLoading;
  final String? error;
  final int selectedTab;           // 0=Futuras, 1=Remisiones, 2=Historial
  final String filterStatus;       // todos, borrador, despachada, entregada
  final String searchQuery;
}

class ShipmentsNotifier extends Notifier<ShipmentsState> {
  Future<void> loadShipments() async { ... }
  Future<void> loadFutureDeliveries() async { ... }
  Future<bool> createShipment(ShipmentOrder order) async { ... }
  Future<bool> dispatchShipment(String id) async { ... }
  Future<bool> confirmDelivery(String id, String receivedBy) async { ... }
  Future<bool> cancelShipment(String id) async { ... }
  void setTab(int tab) { ... }
  void setFilter(String status) { ... }
  void setSearch(String query) { ... }
}
```

---

## 9. Diseño de UI

### 9.1 Versión Desktop (>1024dp)

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 🚚 Remisiones y Entregas                              [🔄 Actualizar] │
│ Gestión de envíos, remisiones y seguimiento de entregas                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐│
│ │ 📦 En Prod.  │ │ ✅ Listas    │ │ 🚛 En Ruta   │ │ 📋 Remisiones   ││
│ │     3        │ │     2        │ │     1        │ │     12          ││
│ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────────┘│
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ [Entregas Futuras]  [Remisiones]  [Historial de Envíos]           │ │
│ ├─────────────────────────────────────────────────────────────────────┤ │
│                                                                         │
│ ── TAB 1: Entregas Futuras ──                                          │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ OP-0012  │ REMOLEDOR 20"x60CM │ Jairo Giraldo  │ 📅 21/03/2026    │ │
│ │          │ ████████████░░░ 80% │ VTA-00005      │ ⚠️ ATRASADA      │ │
│ │          │ Etapa: Soldadura (4/5 completadas)   │ [Crear Envío ▶]  │ │
│ ├─────────────────────────────────────────────────────────────────────┤ │
│ │ OP-0015  │ MARTILLO IND. 5KG  │ Carlos López   │ 📅 25/03/2026    │ │
│ │          │ ████████░░░░░░░ 50% │ VTA-00008      │ 🟡 En proceso    │ │
│ │          │ Etapa: Mecanizado (3/6 completadas)  │                  │ │
│ ├─────────────────────────────────────────────────────────────────────┤ │
│ │ OP-0018  │ CUCHILLA MOLINO    │ Pedro Ramírez  │ 📅 30/03/2026    │ │
│ │          │ ██████████████ 100% │ VTA-00010      │ ✅ COMPLETADA    │ │
│ │          │ Todas las etapas completadas         │ [Crear Envío ▶]  │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ── TAB 2: Remisiones ──                                                │
│                                                                         │
│ [+ Nueva Remisión]  Filtro: [Todos ▼]  Buscar: [____________]          │
│                                                                         │
│ ┌──────┬───────────┬──────────────┬────────┬────────┬─────────────────┐ │
│ │ #    │ Fecha     │ Cliente      │ Items  │ Estado │ Acciones        │ │
│ ├──────┼───────────┼──────────────┼────────┼────────┼─────────────────┤ │
│ │REM-05│ 28/03/26  │ Jairo Girald │ 4      │Borrador│ ✏️ 🖨️ 🚛 ❌    │ │
│ │REM-04│ 25/03/26  │ Carlos López │ 2      │Desp.   │ 🖨️ ✅          │ │
│ │REM-03│ 20/03/26  │ Pedro Ramírez│ 6      │Entreg. │ 🖨️ 👁️          │ │
│ └──────┴───────────┴──────────────┴────────┴────────┴─────────────────┘ │
│                                                                         │
│ ── DIALOG: Crear/Editar Remisión ──                                    │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │ Nueva Remisión - REM-00006                                         │ │
│ ├─────────────────────────────────────────────────────────────────────┤ │
│ │ Factura: [VTA-00005 ▼]    Cliente: Jairo Giraldo                   │ │
│ │ Dirección: [_________________________________]                     │ │
│ ├─────────────────────────────────────────────────────────────────────┤ │
│ │ TRANSPORTE                                                         │ │
│ │ Transportista: [__________]  CC: [__________]                      │ │
│ │ Placa: [_______]  Conductor: [__________]  CC: [__________]        │ │
│ ├─────────────────────────────────────────────────────────────────────┤ │
│ │ ÍTEMS DEL ENVÍO                                    [+ Agregar]     │ │
│ │ ┌────┬─────────────────────────┬─────┬─────┬──────┬──────────────┐ │ │
│ │ │ #  │ Descripción             │ Cant│ Und │ Peso │ Tipo         │ │ │
│ │ ├────┼─────────────────────────┼─────┼─────┼──────┼──────────────┤ │ │
│ │ │ 1  │ Remoledor 20"x60CM Cal 1│ 1   │ UND │ 45kg │ 📦 Producto  │ │ │
│ │ │ 2  │ Lámina HR 1/2" sobrante │ 3   │ UND │ 30kg │ 🔩 Material  │ │ │
│ │ │ 3  │ Eje torneado Ø4"       │ 2   │ UND │ 12kg │ ⚙️ Pieza     │ │ │
│ │ │ 4  │ Manual de instalación   │ 1   │ UND │  -   │ 📄 Otro      │ │ │
│ │ └────┴─────────────────────────┴─────┴─────┴──────┴──────────────┘ │ │
│ │                                                                     │ │
│ │ Notas: [___________________________]                                │ │
│ │ Preparado por: [_____________]  Aprobado por: [_____________]       │ │
│ │                                      [Guardar Borrador] [Despachar]│ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Versión Mobile (<600dp)

```
┌───────────────────────────────┐
│ 🚚 Remisiones y Entregas  🔄 │
│ Envíos y seguimiento          │
├───────────────────────────────┤
│                               │
│ ┌─────────┐ ┌─────────┐      │
│ │📦 Prod. │ │✅ Listas │      │
│ │   3     │ │   2     │      │
│ ├─────────┤ ├─────────┤      │
│ │🚛 Ruta  │ │📋 Remis.│      │
│ │   1     │ │   12    │      │
│ └─────────┘ └─────────┘      │
│                               │
│ [Futuras] [Remisiones] [Hist]│
│ ─────────────────────────────│
│                               │
│ ── Entregas Futuras ──        │
│                               │
│ ┌───────────────────────────┐ │
│ │ OP-0012 │ 📅 21/03/2026  │ │
│ │ REMOLEDOR 20"x60CM       │ │
│ │ Jairo Giraldo │ VTA-0005 │ │
│ │ ████████████░░░ 80%      │ │
│ │ Soldadura (4/5)          │ │
│ │ ⚠️ ATRASADA               │ │
│ │         [Crear Envío ▶]  │ │
│ └───────────────────────────┘ │
│                               │
│ ┌───────────────────────────┐ │
│ │ OP-0018 │ 📅 30/03/2026  │ │
│ │ CUCHILLA MOLINO          │ │
│ │ Pedro Ramírez │ VTA-0010 │ │
│ │ ██████████████ 100%      │ │
│ │ ✅ COMPLETADA             │ │
│ │         [Crear Envío ▶]  │ │
│ └───────────────────────────┘ │
│                               │
│ ── Remisiones ──              │
│                               │
│ [+ Nueva Remisión]            │
│ Filtro: [Todos ▼] [🔍___]    │
│                               │
│ ┌───────────────────────────┐ │
│ │ REM-00005  │  28/03/2026  │ │
│ │ Jairo Giraldo             │ │
│ │ 4 ítems │ 📝 Borrador     │ │
│ │     [✏️] [🖨️] [🚛] [❌]   │ │
│ └───────────────────────────┘ │
│                               │
│ ┌───────────────────────────┐ │
│ │ REM-00004  │  25/03/2026  │ │
│ │ Carlos López              │ │
│ │ 2 ítems │ 🚛 Despachada   │ │
│ │          [🖨️] [✅]         │ │
│ └───────────────────────────┘ │
│                               │
│ ── Formulario (BottomSheet) ──│
│                               │
│ ┌───────────────────────────┐ │
│ │ Nueva Remisión REM-00006  │ │
│ │                           │ │
│ │ Factura: [VTA-00005 ▼]   │ │
│ │ Cliente: Jairo Giraldo    │ │
│ │ Dirección: [___________]  │ │
│ │                           │ │
│ │ ── Transporte ──          │ │
│ │ Transportista: [________] │ │
│ │ Placa: [____]             │ │
│ │ Conductor: [____________] │ │
│ │                           │ │
│ │ ── Ítems ── [+ Agregar]   │ │
│ │ 1. Remoledor 20"x60CM    │ │
│ │    1 UND │ 45kg │ Prod.   │ │
│ │ 2. Lámina HR 1/2"        │ │
│ │    3 UND │ 30kg │ Mat.    │ │
│ │                           │ │
│ │ [Guardar] [Despachar]     │ │
│ └───────────────────────────┘ │
└───────────────────────────────┘
```

---

## 10. Documento Impreso: Remisión

La remisión impresa (PDF) contiene:

```
┌─────────────────────────────────────────────────────┐
│         INDUSTRIAL DE MOLINOS S.A.S.                │
│         NIT: XXX.XXX.XXX-X                          │
│         Dirección | Teléfono | Ciudad               │
│                                                     │
│              REMISIÓN DE MERCANCÍA                   │
│              No. REM-00005                           │
├──────────────────────┬──────────────────────────────┤
│ Fecha: 28/03/2026    │ Factura: VTA-00005           │
│ Cliente: Jairo G.    │ CC/NIT: 12.345.678          │
│ Dirección: Calle..   │ Ciudad: Bogotá              │
├──────────────────────┴──────────────────────────────┤
│ DATOS DE TRANSPORTE                                 │
│ Transportista: Trans ABC │ NIT: 900.123.456        │
│ Placa: ABC-123  │ Conductor: Juan Pérez            │
├─────┬──────────────────────┬─────┬─────┬───────────┤
│  #  │ Descripción          │ Cant│ Und │ Peso (kg) │
├─────┼──────────────────────┼─────┼─────┼───────────┤
│  1  │ Remoledor 20"x60CM   │  1  │ UND │   45.0    │
│  2  │ Lámina HR 1/2"       │  3  │ UND │   30.0    │
│  3  │ Eje torneado Ø4"     │  2  │ UND │   12.0    │
│  4  │ Manual instalación   │  1  │ UND │    -      │
├─────┴──────────────────────┴─────┴─────┴───────────┤
│ Total ítems: 4        │ Peso total: 87.0 kg        │
├─────────────────────────────────────────────────────┤
│ Observaciones: _________________________________    │
├──────────────────┬──────────────────┬───────────────┤
│ Preparó:         │ Aprobó:          │ Recibió:      │
│                  │                  │               │
│ _______________  │ _______________  │ _____________ │
│ Nombre           │ Nombre           │ Nombre        │
│ CC:              │ CC:              │ CC:           │
└──────────────────┴──────────────────┴───────────────┘
```

Se genera usando el paquete `printing` (ya disponible en el proyecto) con `pdf`/`printing`.

---

## 11. Migración SQL

**Archivo**: `supabase_migrations/073_shipment_orders.sql`

Contenido: Las tres tablas + función + trigger de `updated_at` descritas en la sección 4.

Además:
```sql
-- Vincular OP con factura
ALTER TABLE production_orders
    ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_production_orders_invoice ON production_orders(invoice_id);
```

---

## 12. Conexión Producción → Entregas

### Flujo Completo

```
1. Se crea Venta (factura) con delivery_date y advance
2. Se crea OP vinculada a esa factura (production_orders.invoice_id)
3. En "Entregas Futuras" aparece la OP con progreso en tiempo real
4. Cuando OP se completa → botón "Crear Envío" se habilita
5. Se crea Remisión (ShipmentOrder) con los ítems a despachar
6. Se pueden agregar ítems adicionales de inventario (materia prima sobrante, piezas, herramientas)
7. Se imprime la remisión → se marca como "despachada"
8. Al entregar → se marca "entregada" con firma de recibido
```

### Query: Entregas Futuras

```sql
SELECT 
    po.id, po.code, po.product_name, po.status, po.quantity,
    po.due_date AS production_due_date,
    i.id AS invoice_id, i.series || '-' || i.number AS invoice_number,
    i.customer_name, i.delivery_date, i.total, i.paid_amount,
    -- Progreso
    (SELECT COUNT(*) FROM production_stages ps 
     WHERE ps.production_order_id = po.id AND ps.status = 'completada') AS completed_stages,
    (SELECT COUNT(*) FROM production_stages ps 
     WHERE ps.production_order_id = po.id) AS total_stages
FROM production_orders po
JOIN invoices i ON po.invoice_id = i.id
WHERE po.status IN ('en_proceso', 'completada', 'planificada')
  AND i.delivery_date IS NOT NULL
ORDER BY i.delivery_date ASC;
```

---

## 13. Plan de Implementación (Fases)

### Fase 1: Base de datos y entidades
1. Crear migración `073_shipment_orders.sql`
2. Ejecutar migración en Supabase
3. Crear entidad `ShipmentOrder` + `ShipmentOrderItem`
4. Agregar `invoice_id` a `ProductionOrder` entity

### Fase 2: DataSource y Provider
5. Crear `ShipmentsDataSource` con CRUD completo
6. Crear `ShipmentsProvider` (state + notifier)
7. Agregar método `getFutureDeliveries()` al datasource

### Fase 3: UI - Página principal
8. Crear `ShipmentsPage` con 3 tabs
9. Implementar Tab "Entregas Futuras" con cards de progreso OP
10. Implementar Tab "Remisiones" con lista y filtros
11. Implementar Tab "Historial" con timeline

### Fase 4: Formularios
12. Dialog/BottomSheet para crear remisión
13. Formulario de ítems (selector de productos, materiales, piezas)
14. Sección de datos de transporte

### Fase 5: Impresión
15. Generar PDF de remisión con `printing` package
16. Vista previa de impresión
17. Botón de impresión directa

### Fase 6: Integración y Router
18. Actualizar router: `/pending-deliveries` → `/shipments`
19. Actualizar sidebar label e icono
20. Conectar producción: al crear OP, vincular factura
21. Testing y ajustes responsive

---

## 14. Cards de Resumen (Header)

| Card | Valor | Color | Icono |
|---|---|---|---|
| En Producción | # OPs en proceso | `#FF9800` naranja | `factory` |
| Listas para Envío | # OPs completadas sin remisión | `#4CAF50` verde | `check_circle` |
| En Ruta | # Remisiones despachadas | `#2196F3` azul | `local_shipping` |
| Total Remisiones | # Remisiones del mes | `#9C27B0` morado | `description` |

---

## 15. Impresión: Componentes del PDF

Usando `pdf` + `printing` packages:

```dart
// lib/presentation/widgets/shipment_print_preview.dart

Future<pw.Document> generateShipmentPdf(ShipmentOrder order) {
  // Header con logo empresa
  // Datos del cliente
  // Datos de transporte
  // Tabla de ítems con #, descripción, cant, und, peso
  // Totales: ítems, peso total
  // Observaciones
  // Firmas: Preparó, Aprobó, Recibió (con líneas)
}
```

---

## 16. Notas Técnicas

- **Responsive**: Desktop usa `Row` con tabs normales; Mobile usa `TabBar` con `isScrollable: true` y BottomSheet para formulario
- **Filtros**: Los filtros de la tab Remisiones persisten en el provider state
- **Impresión**: Se usa `printing` package que ya está en el proyecto (ver `pubspec.yaml`)
- **Consecutivo**: El número de remisión se genera con la función SQL `next_shipment_number()` para evitar duplicados
- **RLS**: Las tablas nuevas heredarán las políticas RLS del proyecto (full access para authenticated)
- **Encoding**: Todos los archivos nuevos en UTF-8 sin BOM
