# 📊 INVESTIGACIÓN: KPIs y MÉTRICAS para Analytics
## Industrial de Molinos - Sistema ERP
### Fecha: 24 de Diciembre, 2025

---

## 1. 📦 ANÁLISIS DE INVENTARIO (KPIs y Métricas)

### 1.1 Métodos de Análisis de Inventario

#### 🔵 Análisis ABC (Pareto 80/20)
Clasifica el inventario en tres categorías basándose en el valor/importancia:

| Categoría | Descripción | % Productos | % Valor |
|-----------|-------------|-------------|---------|
| **A** | Productos de alto valor/rotación | 10-20% | 70-80% |
| **B** | Productos de valor medio | 30% | 15-25% |
| **C** | Productos de bajo valor | 50% | 5% |

**Implementación SQL:**
```sql
-- Vista para Análisis ABC
CREATE OR REPLACE VIEW v_inventory_abc_analysis AS
WITH product_sales AS (
    SELECT 
        ii.product_code,
        ii.product_name,
        SUM(ii.total) as total_revenue,
        SUM(ii.quantity) as total_quantity
    FROM invoice_items ii
    JOIN invoices i ON ii.invoice_id = i.id
    WHERE i.status != 'cancelled'
    AND i.issue_date >= NOW() - INTERVAL '12 months'
    GROUP BY ii.product_code, ii.product_name
),
cumulative_revenue AS (
    SELECT 
        product_code,
        product_name,
        total_revenue,
        total_quantity,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) as running_total,
        SUM(total_revenue) OVER () as grand_total
    FROM product_sales
)
SELECT 
    product_code,
    product_name,
    total_revenue,
    total_quantity,
    running_total,
    grand_total,
    ROUND((running_total / grand_total * 100)::NUMERIC, 2) as cumulative_percentage,
    CASE 
        WHEN (running_total / grand_total) <= 0.80 THEN 'A'
        WHEN (running_total / grand_total) <= 0.95 THEN 'B'
        ELSE 'C'
    END as abc_category
FROM cumulative_revenue
ORDER BY total_revenue DESC;
```

#### 🔵 Análisis FSN (Fast, Slow, Non-moving)
Clasifica productos por velocidad de movimiento:

| Categoría | Descripción | Acción Recomendada |
|-----------|-------------|-------------------|
| **Fast** | Alta rotación (>12 veces/año) | Mantener stock alto |
| **Slow** | Baja rotación (3-12 veces/año) | Reducir stock |
| **Non-moving** | Sin movimiento (>6 meses) | Liquidar/Eliminar |

---

### 1.2 KPIs Clave de Inventario

#### 📈 1. Tasa de Rotación de Inventario (Inventory Turnover Rate)
```
ITR = Costo de Ventas / Inventario Promedio
```
- **Interpretación:** Cuántas veces se renueva el inventario en un período
- **Meta ideal:** Depende de industria (para manufactura: 4-8 veces/año)

#### 📈 2. Días de Inventario (DSI - Days Sales of Inventory)
```
DSI = (Inventario Promedio / Costo de Ventas) × 365
```
- **Interpretación:** Días promedio que el inventario permanece en almacén
- **Meta ideal:** Menor = mejor (menos capital inmovilizado)

#### 📈 3. Tasa de Desabastecimiento (Stockout Rate)
```
Stockout Rate = (Órdenes no cumplidas / Total órdenes) × 100
```
- **Meta ideal:** < 2%
- **Impacto:** Pérdida de ventas y clientes

#### 📈 4. Tasa de Sell-Through (Rendimiento de Venta)
```
Sell-Through = (Unidades Vendidas / Unidades Recibidas) × 100
```
- **Interpretación:** % del inventario que se vende
- **Meta ideal:** > 80%

#### 📈 5. GMROI (Gross Margin Return on Inventory Investment)
```
GMROI = Margen Bruto / Costo Promedio del Inventario
```
- **Interpretación:** Rentabilidad por cada S/ invertido en inventario
- **Meta ideal:** > 1.0 (significa ganancia)

#### 📈 6. Exactitud del Inventario
```
Exactitud = (Ítems correctos / Total ítems contados) × 100
```
- **Meta ideal:** > 97%

---

### 1.3 Métricas Adicionales de Inventario

| Métrica | Fórmula | Para qué sirve |
|---------|---------|----------------|
| **Cobertura de Stock** | Inventario Actual / Demanda Diaria | Días que dura el stock |
| **Valor del Inventario** | Σ(Stock × Costo Unitario) | Capital inmovilizado |
| **% Stock Crítico** | Productos bajo mínimo / Total productos | Alertas de reabastecimiento |
| **% Stock Muerto** | Productos sin movimiento / Total | Inventario obsoleto |
| **Costo de Mantenimiento** | Valor inventario × % costo almacén | Gasto en almacenamiento |

---

## 2. 💰 ANÁLISIS DE COBRANZAS (Accounts Receivable KPIs)

### 2.1 KPIs Principales de Cobranzas

#### 📊 1. DSO (Days Sales Outstanding) - Días de Cartera
```
DSO = (Cuentas por Cobrar / Ventas Netas a Crédito) × Días del Período
```
- **Interpretación:** Días promedio para cobrar una factura
- **Meta ideal:** < 30 días (depende de términos de crédito)
- **Ejemplo:** Si términos son 30 días, DSO debería ser ~33 días

#### 📊 2. CEI (Collection Effectiveness Index) - Índice de Efectividad de Cobro
```
CEI = [(Cartera Inicial + Ventas a Crédito - Cartera Final) / 
       (Cartera Inicial + Ventas a Crédito - Cartera Vigente)] × 100
```
- **Interpretación:** % de deuda que se logró cobrar en el período
- **Meta ideal:** > 80%
- **Excelente:** > 90%

#### 📊 3. AR Turnover (Rotación de Cartera)
```
AR Turnover = Ventas Netas a Crédito / Promedio Cuentas por Cobrar
```
- **Interpretación:** Veces que se cobra la cartera en un año
- **Meta ideal:** > 12 (cobra más de 1 vez al mes)

#### 📊 4. Bad Debt Ratio (Tasa de Deuda Incobrable)
```
Bad Debt Ratio = (Deuda Incobrable / Total Ventas a Crédito) × 100
```
- **Meta ideal:** < 1%
- **Alerta:** > 3%

#### 📊 5. ADD (Average Days Delinquent) - Días de Mora Promedio
```
ADD = DSO - Mejor DSO Posible (términos de crédito)
```
- **Interpretación:** Días promedio de retraso en pagos
- **Meta ideal:** < 10 días

---

### 2.2 Análisis de Antigüedad de Cartera (Aging Report)

#### Estructura del Reporte de Antigüedad:

| Bucket | Rango | Riesgo | Acción |
|--------|-------|--------|--------|
| **Vigente** | 0-30 días | ✅ Bajo | Recordatorio |
| **30-60 días** | 31-60 días | ⚠️ Medio | Llamada |
| **60-90 días** | 61-90 días | 🔴 Alto | Cobranza activa |
| **+90 días** | >90 días | 🔴🔴 Crítico | Gestión legal |

**SQL para Aging Analysis:**
```sql
CREATE OR REPLACE VIEW v_ar_aging_summary AS
SELECT 
    CASE 
        WHEN CURRENT_DATE - due_date <= 0 THEN 'Vigente'
        WHEN CURRENT_DATE - due_date BETWEEN 1 AND 30 THEN '1-30 días'
        WHEN CURRENT_DATE - due_date BETWEEN 31 AND 60 THEN '31-60 días'
        WHEN CURRENT_DATE - due_date BETWEEN 61 AND 90 THEN '61-90 días'
        ELSE 'Más de 90 días'
    END as aging_bucket,
    COUNT(*) as num_invoices,
    COUNT(DISTINCT customer_id) as num_customers,
    SUM(total - paid_amount) as pending_amount,
    AVG(CURRENT_DATE - due_date) as avg_days_overdue
FROM invoices
WHERE status NOT IN ('paid', 'cancelled')
AND (total - paid_amount) > 0
GROUP BY aging_bucket
ORDER BY 
    CASE aging_bucket
        WHEN 'Vigente' THEN 1
        WHEN '1-30 días' THEN 2
        WHEN '31-60 días' THEN 3
        WHEN '61-90 días' THEN 4
        ELSE 5
    END;
```

---

### 2.3 Métricas de Cliente (Customer Metrics)

| Métrica | Descripción | Uso |
|---------|-------------|-----|
| **CLV** (Customer Lifetime Value) | Valor total esperado del cliente | Priorizar clientes |
| **Comportamiento de Pago** | Historial de pagos a tiempo vs tarde | Evaluar riesgo |
| **Límite de Crédito Utilizado** | % del límite usado | Gestionar exposición |
| **Frecuencia de Compra** | Compras por período | Identificar patrones |
| **Ticket Promedio** | Valor promedio de factura | Segmentación |

**SQL para Customer Payment Behavior:**
```sql
CREATE OR REPLACE VIEW v_customer_payment_behavior AS
SELECT 
    c.id,
    c.name,
    COUNT(i.id) as total_invoices,
    SUM(CASE WHEN i.paid_date <= i.due_date THEN 1 ELSE 0 END) as on_time_payments,
    SUM(CASE WHEN i.paid_date > i.due_date THEN 1 ELSE 0 END) as late_payments,
    AVG(CASE WHEN i.paid_date IS NOT NULL 
        THEN i.paid_date - i.issue_date ELSE NULL END) as avg_days_to_pay,
    ROUND(
        SUM(CASE WHEN i.paid_date <= i.due_date THEN 1 ELSE 0 END)::NUMERIC / 
        NULLIF(COUNT(i.id), 0) * 100, 2
    ) as on_time_percentage,
    CASE 
        WHEN SUM(CASE WHEN i.paid_date <= i.due_date THEN 1 ELSE 0 END)::NUMERIC / 
             NULLIF(COUNT(i.id), 0) >= 0.90 THEN 'Excelente'
        WHEN SUM(CASE WHEN i.paid_date <= i.due_date THEN 1 ELSE 0 END)::NUMERIC / 
             NULLIF(COUNT(i.id), 0) >= 0.70 THEN 'Bueno'
        WHEN SUM(CASE WHEN i.paid_date <= i.due_date THEN 1 ELSE 0 END)::NUMERIC / 
             NULLIF(COUNT(i.id), 0) >= 0.50 THEN 'Regular'
        ELSE 'Riesgoso'
    END as payment_rating
FROM customers c
LEFT JOIN invoices i ON c.id = i.customer_id AND i.status = 'paid'
GROUP BY c.id, c.name
HAVING COUNT(i.id) > 0;
```

---

### 2.4 Dashboard de Cobranzas - Métricas Clave

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DASHBOARD DE COBRANZAS                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────┐ │
│  │     DSO      │  │     CEI      │  │  Bad Debt    │  │ AR Turn │ │
│  │   32 días    │  │    85.5%     │  │    0.8%      │  │  14.2x  │ │
│  │   ▼ 3 días   │  │   ▲ 2.3%     │  │   ▼ 0.2%     │  │  ▲ 1.1  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └─────────┘ │
│                                                                     │
│  ANTIGÜEDAD DE CARTERA                    TENDENCIA DSO             │
│  ┌─────────────────────────────┐         ┌─────────────────────┐   │
│  │ Vigente    ████████ 65%     │         │    35 ─┐            │   │
│  │ 1-30 días  ███      20%     │         │    30 ─┼──────┐     │   │
│  │ 31-60 días ██        8%     │         │    25 ─┼──────┼─    │   │
│  │ 61-90 días █         4%     │         │       E F M A M J   │   │
│  │ +90 días   █         3%     │         └─────────────────────┘   │
│  └─────────────────────────────┘                                    │
│                                                                     │
│  TOP CLIENTES MOROSOS              RESUMEN POR VENDEDOR             │
│  ┌─────────────────────────────┐  ┌─────────────────────────────┐  │
│  │ 1. Cliente A   S/ 15,230    │  │ Vendedor 1  DSO: 28  ★★★★☆  │  │
│  │ 2. Cliente B   S/ 12,100    │  │ Vendedor 2  DSO: 35  ★★★☆☆  │  │
│  │ 3. Cliente C   S/  8,500    │  │ Vendedor 3  DSO: 42  ★★☆☆☆  │  │
│  └─────────────────────────────┘  └─────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 📐 FÓRMULAS ESPECÍFICAS PARA INDUSTRIAL DE MOLINOS

### 3.1 Para Inventario de Materiales (Acero, etc.)

```sql
-- KPIs específicos para materiales industriales
CREATE OR REPLACE VIEW v_material_kpis AS
SELECT 
    m.id,
    m.name,
    m.code,
    m.category,
    m.stock,
    m.min_stock,
    m.price_per_kg as unit_price,
    (m.stock * m.price_per_kg) as inventory_value,
    
    -- Días de Cobertura
    CASE 
        WHEN COALESCE(daily_consumption.avg_daily, 0) > 0 
        THEN ROUND((m.stock / daily_consumption.avg_daily)::NUMERIC, 1)
        ELSE 999
    END as days_of_coverage,
    
    -- Estado del Stock
    CASE 
        WHEN m.stock = 0 THEN 'SIN STOCK'
        WHEN m.stock < m.min_stock THEN 'BAJO STOCK'
        WHEN m.stock < m.min_stock * 1.5 THEN 'STOCK NORMAL'
        ELSE 'EXCESO DE STOCK'
    END as stock_status,
    
    -- Rotación últimos 30 días
    COALESCE(movements.outgoing_qty, 0) as consumed_30d,
    COALESCE(movements.incoming_qty, 0) as received_30d
    
FROM materials m
LEFT JOIN (
    SELECT 
        material_id,
        AVG(quantity) as avg_daily
    FROM material_movements
    WHERE type = 'outgoing'
    AND created_at >= NOW() - INTERVAL '90 days'
    GROUP BY material_id
) daily_consumption ON m.id = daily_consumption.material_id
LEFT JOIN (
    SELECT 
        material_id,
        SUM(CASE WHEN type = 'outgoing' THEN quantity ELSE 0 END) as outgoing_qty,
        SUM(CASE WHEN type = 'incoming' THEN quantity ELSE 0 END) as incoming_qty
    FROM material_movements
    WHERE created_at >= NOW() - INTERVAL '30 days'
    GROUP BY material_id
) movements ON m.id = movements.material_id;
```

### 3.2 Para Productos Terminados (Molinos)

```sql
-- KPIs para productos manufacturados
CREATE OR REPLACE VIEW v_product_performance AS
SELECT 
    ii.product_name,
    ii.product_code,
    COUNT(DISTINCT ii.invoice_id) as times_sold,
    SUM(ii.quantity) as units_sold,
    SUM(ii.total) as total_revenue,
    AVG(ii.unit_price) as avg_selling_price,
    
    -- Margen estimado (35% por defecto si no hay costo)
    SUM(ii.total) * 0.35 as estimated_gross_margin,
    
    -- Frecuencia (días entre ventas)
    CASE 
        WHEN COUNT(DISTINCT DATE(i.issue_date)) > 1 
        THEN (MAX(i.issue_date) - MIN(i.issue_date)) / 
             NULLIF(COUNT(DISTINCT DATE(i.issue_date)) - 1, 0)
        ELSE NULL 
    END as avg_days_between_sales,
    
    -- Categoría ABC basada en revenue
    CASE 
        WHEN SUM(ii.total) >= (
            SELECT PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY product_revenue)
            FROM (SELECT SUM(total) as product_revenue FROM invoice_items GROUP BY product_code) x
        ) THEN 'A'
        WHEN SUM(ii.total) >= (
            SELECT PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY product_revenue)
            FROM (SELECT SUM(total) as product_revenue FROM invoice_items GROUP BY product_code) x
        ) THEN 'B'
        ELSE 'C'
    END as abc_category
    
FROM invoice_items ii
JOIN invoices i ON ii.invoice_id = i.id
WHERE i.status != 'cancelled'
AND i.issue_date >= NOW() - INTERVAL '12 months'
GROUP BY ii.product_name, ii.product_code
ORDER BY total_revenue DESC;
```

---

## 4. 🎯 ALERTAS Y ACCIONES RECOMENDADAS

### 4.1 Alertas de Inventario

| Condición | Alerta | Acción |
|-----------|--------|--------|
| Stock = 0 | 🔴 CRÍTICO | Orden de compra urgente |
| Stock < Min | 🟠 BAJO | Programar reposición |
| Stock > 3x Min | 🟡 EXCESO | Evaluar reducción |
| Sin movimiento 60+ días | ⚪ OBSOLETO | Revisar/liquidar |
| Rotación < 2x/año | ⚪ LENTO | Reducir stock |

### 4.2 Alertas de Cobranzas

| Condición | Alerta | Acción |
|-----------|--------|--------|
| DSO > Términos + 15 días | 🟠 ATENCIÓN | Revisar procesos |
| CEI < 70% | 🔴 CRÍTICO | Reforzar cobranza |
| Cliente > 90 días mora | 🔴 INCOBRABLE | Acción legal |
| Cliente > límite crédito | 🟠 RIESGO | Suspender crédito |
| Bad Debt > 3% | 🔴 CRÍTICO | Revisar políticas crédito |

---

## 5. 📱 IMPLEMENTACIÓN EN LA APP

### 5.1 Tab de Inventario (Mejorado)

```dart
// KPIs a mostrar en el dashboard de Inventario:
class InventoryKPIs {
  final double totalValue;          // Valor total del inventario
  final int totalProducts;          // Total de productos/materiales
  final int lowStockCount;          // Productos bajo mínimo
  final int outOfStockCount;        // Productos sin stock
  final double turnoverRate;        // Tasa de rotación
  final int daysOfCoverage;         // Días de cobertura promedio
  final int slowMovingCount;        // Productos de lenta rotación
  final List<ProductABC> abcAnalysis; // Análisis ABC
}
```

### 5.2 Tab de Cobranzas (Mejorado)

```dart
// KPIs a mostrar en el dashboard de Cobranzas:
class ReceivablesKPIs {
  final double totalReceivables;    // Total por cobrar
  final double dso;                 // Días de cartera
  final double cei;                 // Índice de efectividad
  final double arTurnover;          // Rotación de cartera
  final double badDebtRatio;        // Tasa de incobrable
  final Map<String, AgingBucket> aging; // Antigüedad
  final List<CustomerDebt> topDebtors; // Top morosos
}
```

---

## 6. 📋 RESUMEN EJECUTIVO

### Métricas Mínimas Recomendadas

#### Para INVENTARIO:
1. ✅ **Valor Total del Inventario** - Capital inmovilizado
2. ✅ **Productos Bajo Stock** - Alertas de reposición
3. ✅ **Rotación de Inventario** - Eficiencia
4. ✅ **Análisis ABC** - Priorización
5. ✅ **Días de Cobertura** - Planificación

#### Para COBRANZAS:
1. ✅ **DSO** - Días para cobrar
2. ✅ **CEI** - Efectividad de cobro
3. ✅ **Aging Report** - Antigüedad de deuda
4. ✅ **Bad Debt Ratio** - Riesgo de pérdida
5. ✅ **Top Morosos** - Priorización de gestión

---

*Documento actualizado: 24 de Diciembre, 2025*
*Fuentes: NetSuite, Investopedia, Billtrust, mejores prácticas de industria*
