-- =====================================================
-- 052: ANALYTICS MEJORADO - KPIs para Negocio Industrial
-- =====================================================
-- Fecha: 2025-01-XX
-- Descripción:
--   1. Crear vistas faltantes (v_customer_metrics, v_customer_purchase_history)
--   2. Crear función get_dso_trend (optimizada, reemplaza fallback N+1)
--   3. Nuevos KPIs para negocio industrial de molinos:
--      - Salud del negocio (crédito vs ganancia vs inventario)
--      - Rotación de inventario
--      - Eficiencia de materia prima
--      - Tendencia mensual comparativa
-- =====================================================

-- =====================================================
-- 1. VISTAS FALTANTES
-- =====================================================

-- Vista: Métricas de Clientes (optimizada, reemplaza fallback N+1 en Dart)
CREATE OR REPLACE VIEW v_customer_metrics AS
SELECT 
    c.id,
    c.name,
    c.document_number,
    c.type,
    c.current_balance AS debt,
    c.credit_limit,
    c.created_at AS customer_since,
    COALESCE(inv.total_purchases, 0) AS total_purchases,
    COALESCE(inv.total_spent, 0) AS total_spent,
    CASE WHEN COALESCE(inv.total_purchases, 0) > 0 
         THEN ROUND((COALESCE(inv.total_spent, 0) / inv.total_purchases)::NUMERIC, 2)
         ELSE 0 END AS average_ticket,
    inv.last_purchase_date,
    inv.first_purchase_date,
    CASE WHEN inv.last_purchase_date IS NOT NULL 
         THEN (CURRENT_DATE - inv.last_purchase_date::DATE)
         ELSE NULL END AS days_since_last_purchase
FROM customers c
LEFT JOIN LATERAL (
    SELECT 
        COUNT(*)::INT AS total_purchases,
        ROUND(SUM(total)::NUMERIC, 2) AS total_spent,
        MAX(issue_date) AS last_purchase_date,
        MIN(issue_date) AS first_purchase_date
    FROM invoices i
    WHERE i.customer_id = c.id
    AND i.status != 'cancelled'
) inv ON TRUE
WHERE c.is_active = TRUE;

-- Vista: Historial de Compras por Cliente (line items)
CREATE OR REPLACE VIEW v_customer_purchase_history AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.document_number,
    c.type AS customer_type,
    i.id AS invoice_id,
    i.full_number AS invoice_number,
    i.issue_date,
    i.total AS invoice_total,
    i.status::TEXT AS invoice_status,
    ii.product_name,
    ii.product_code,
    ii.quantity,
    ii.unit_price,
    ii.total AS item_total
FROM customers c
JOIN invoices i ON c.id = i.customer_id
JOIN invoice_items ii ON i.id = ii.invoice_id
WHERE i.status != 'cancelled'
ORDER BY i.issue_date DESC;

-- =====================================================
-- 2. FUNCIÓN get_dso_trend (optimizada, single query)
-- =====================================================

CREATE OR REPLACE FUNCTION get_dso_trend(p_months INT DEFAULT 12)
RETURNS TABLE (
    month TEXT,
    dso_days NUMERIC,
    total_billed NUMERIC,
    total_outstanding NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH months AS (
        SELECT generate_series(
            DATE_TRUNC('month', NOW()) - (p_months - 1 || ' months')::INTERVAL,
            DATE_TRUNC('month', NOW()),
            '1 month'::INTERVAL
        )::DATE AS month_start
    ),
    monthly_data AS (
        SELECT 
            m.month_start,
            COALESCE(SUM(i.total), 0) AS billed,
            COALESCE(SUM(i.total - i.paid_amount), 0) AS outstanding,
            EXTRACT(DAY FROM (m.month_start + INTERVAL '1 month' - INTERVAL '1 day'))::INT AS days_in_month
        FROM months m
        LEFT JOIN invoices i ON 
            DATE_TRUNC('month', i.issue_date) = m.month_start
            AND i.status != 'cancelled'
        GROUP BY m.month_start
    )
    SELECT 
        md.month_start::TEXT AS month,
        CASE WHEN md.billed > 0 
             THEN ROUND((md.outstanding / (md.billed / md.days_in_month))::NUMERIC, 1) 
             ELSE 0 END AS dso_days,
        ROUND(md.billed::NUMERIC, 2) AS total_billed,
        ROUND(md.outstanding::NUMERIC, 2) AS total_outstanding
    FROM monthly_data md
    ORDER BY md.month_start;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. NUEVOS KPIs PARA NEGOCIO INDUSTRIAL
-- =====================================================

-- Vista: Salud del Negocio - Crédito vs Ganancia vs Inventario (mensual)
-- Esta es la gráfica solicitada: comparar créditos, ganancias e inventario
CREATE OR REPLACE VIEW v_business_health_monthly AS
WITH months AS (
    SELECT generate_series(
        DATE_TRUNC('month', NOW()) - INTERVAL '11 months',
        DATE_TRUNC('month', NOW()),
        '1 month'::INTERVAL
    )::DATE AS month_start
),
credit_data AS (
    -- Total de crédito otorgado (facturas emitidas no pagadas al final del mes)
    SELECT 
        m.month_start,
        COALESCE(SUM(i.total - i.paid_amount), 0) AS credit_extended
    FROM months m
    LEFT JOIN invoices i ON 
        i.issue_date <= (m.month_start + INTERVAL '1 month' - INTERVAL '1 day')
        AND i.status NOT IN ('cancelled', 'paid', 'draft')
    GROUP BY m.month_start
),
revenue_data AS (
    -- Ganancias del mes (ventas - costos estimados)
    SELECT 
        m.month_start,
        COALESCE(SUM(i.total), 0) AS revenue,
        COALESCE(SUM(i.paid_amount), 0) AS collected
    FROM months m
    LEFT JOIN invoices i ON 
        DATE_TRUNC('month', i.issue_date) = m.month_start
        AND i.status != 'cancelled'
    GROUP BY m.month_start
),
inventory_data AS (
    -- Valor del inventario (snapshot, se usa el valor actual para todos los meses - simplificación)
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN p.cost_price > 0 THEN p.stock * p.cost_price
                ELSE p.stock * p.unit_price
            END
        ), 0) AS product_value
    FROM products p 
    WHERE p.is_active = TRUE AND p.stock > 0
),
material_inventory AS (
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN mt.cost_price > 0 THEN mt.stock * mt.cost_price
                WHEN mt.price_per_kg > 0 THEN mt.stock * mt.price_per_kg
                ELSE mt.stock * mt.unit_price
            END
        ), 0) AS material_value
    FROM materials mt 
    WHERE mt.is_active = TRUE AND mt.stock > 0
)
SELECT 
    m.month_start AS month,
    EXTRACT(YEAR FROM m.month_start)::INT AS year,
    EXTRACT(MONTH FROM m.month_start)::INT AS month_num,
    ROUND(cd.credit_extended::NUMERIC, 2) AS credit_extended,
    ROUND(rd.revenue::NUMERIC, 2) AS revenue,
    ROUND(rd.collected::NUMERIC, 2) AS collected,
    ROUND((rd.revenue * 0.35)::NUMERIC, 2) AS estimated_profit,  -- 35% margen estimado
    ROUND((iv.product_value + mi.material_value)::NUMERIC, 2) AS inventory_value,
    ROUND(iv.product_value::NUMERIC, 2) AS product_inventory,
    ROUND(mi.material_value::NUMERIC, 2) AS material_inventory,
    -- Ratio crédito/ganancia (mientras más bajo, mejor)
    CASE WHEN rd.revenue > 0 
         THEN ROUND((cd.credit_extended / rd.revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS credit_to_revenue_ratio,
    -- Ratio cobrado/vendido
    CASE WHEN rd.revenue > 0 
         THEN ROUND((rd.collected / rd.revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS collection_ratio
FROM months m
JOIN credit_data cd ON m.month_start = cd.month_start
JOIN revenue_data rd ON m.month_start = rd.month_start
CROSS JOIN inventory_data iv
CROSS JOIN material_inventory mi
ORDER BY m.month_start;

-- Vista: Rotación de Inventario por Producto
CREATE OR REPLACE VIEW v_inventory_turnover AS
SELECT 
    p.id AS product_id,
    p.code AS product_code,
    p.name AS product_name,
    c.name AS category,
    p.stock AS current_stock,
    p.unit_price,
    p.cost_price,
    p.stock * COALESCE(NULLIF(p.cost_price, 0), p.unit_price) AS stock_value,
    COALESCE(sales.qty_sold_90d, 0) AS qty_sold_90_days,
    COALESCE(sales.revenue_90d, 0) AS revenue_90_days,
    -- Rotación = Ventas / Stock promedio (anualizado)
    CASE WHEN p.stock > 0 AND COALESCE(sales.qty_sold_90d, 0) > 0
         THEN ROUND(((sales.qty_sold_90d / 90.0 * 365) / p.stock)::NUMERIC, 2)
         ELSE 0 END AS annual_turnover_rate,
    -- Días de inventario = Stock / (Ventas diarias promedio)
    CASE WHEN COALESCE(sales.qty_sold_90d, 0) > 0
         THEN ROUND((p.stock / (sales.qty_sold_90d / 90.0))::NUMERIC, 0)
         ELSE 999 END AS days_of_inventory,
    -- Estado
    CASE 
        WHEN p.stock <= 0 THEN 'SIN_STOCK'
        WHEN p.stock <= p.min_stock THEN 'STOCK_BAJO'
        WHEN COALESCE(sales.qty_sold_90d, 0) = 0 THEN 'SIN_MOVIMIENTO'
        WHEN p.stock / NULLIF(sales.qty_sold_90d / 90.0, 0) > 180 THEN 'SOBREINVENTARIO'
        ELSE 'NORMAL'
    END AS inventory_status
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
LEFT JOIN LATERAL (
    SELECT 
        COALESCE(SUM(ii.quantity), 0) AS qty_sold_90d,
        COALESCE(SUM(ii.total), 0) AS revenue_90d
    FROM invoice_items ii
    JOIN invoices i ON i.id = ii.invoice_id
    WHERE ii.product_id = p.id
    AND i.status != 'cancelled'
    AND i.issue_date >= NOW() - INTERVAL '90 days'
) sales ON TRUE
WHERE p.is_active = TRUE;

-- Vista: Eficiencia de Materia Prima
CREATE OR REPLACE VIEW v_material_efficiency AS
SELECT 
    mt.id AS material_id,
    mt.code AS material_code,
    mt.name AS material_name,
    mt.category,
    mt.unit,
    mt.stock AS current_stock,
    COALESCE(mt.cost_price, mt.price_per_kg, mt.unit_price) AS unit_cost,
    mt.stock * COALESCE(NULLIF(mt.cost_price, 0), NULLIF(mt.price_per_kg, 0), mt.unit_price) AS stock_value,
    COALESCE(consumption.consumed_90d, 0) AS consumed_90_days,
    COALESCE(consumption.received_90d, 0) AS received_90_days,
    COALESCE(consumption.movements_90d, 0) AS movements_90_days,
    -- Tasa de consumo diaria
    CASE WHEN COALESCE(consumption.consumed_90d, 0) > 0
         THEN ROUND((consumption.consumed_90d / 90.0)::NUMERIC, 2)
         ELSE 0 END AS daily_consumption_rate,
    -- Días de stock restante
    CASE WHEN COALESCE(consumption.consumed_90d, 0) > 0
         THEN ROUND((mt.stock / (consumption.consumed_90d / 90.0))::NUMERIC, 0)
         ELSE 999 END AS days_of_stock_remaining,
    -- Semáforo de reabastecimiento
    CASE 
        WHEN mt.stock <= 0 THEN 'URGENTE'
        WHEN COALESCE(consumption.consumed_90d, 0) > 0 
             AND mt.stock / (consumption.consumed_90d / 90.0) <= 7 THEN 'CRITICO'
        WHEN COALESCE(consumption.consumed_90d, 0) > 0 
             AND mt.stock / (consumption.consumed_90d / 90.0) <= 15 THEN 'ALERTA'
        WHEN mt.stock <= mt.min_stock THEN 'BAJO'
        ELSE 'NORMAL'
    END AS reorder_status
FROM materials mt
LEFT JOIN LATERAL (
    SELECT 
        ABS(COALESCE(SUM(CASE WHEN mm.type = 'consumption' OR mm.quantity < 0 THEN ABS(mm.quantity) ELSE 0 END), 0)) AS consumed_90d,
        COALESCE(SUM(CASE WHEN mm.type = 'purchase' OR (mm.type != 'consumption' AND mm.quantity > 0) THEN mm.quantity ELSE 0 END), 0) AS received_90d,
        COUNT(*) AS movements_90d
    FROM material_movements mm
    WHERE mm.material_id = mt.id
    AND mm.created_at >= NOW() - INTERVAL '90 days'
) consumption ON TRUE
WHERE mt.is_active = TRUE
ORDER BY days_of_stock_remaining ASC;

-- Vista: Resumen de Salud del Negocio (snapshot actual)
CREATE OR REPLACE VIEW v_business_health_snapshot AS
WITH active_invoices AS (
    SELECT 
        COUNT(*) AS total_invoices,
        SUM(total) AS total_revenue,
        SUM(paid_amount) AS total_collected,
        SUM(total - paid_amount) AS total_receivables,
        SUM(CASE WHEN status IN ('issued', 'partial', 'overdue') AND due_date < CURRENT_DATE 
            THEN total - paid_amount ELSE 0 END) AS overdue_amount,
        COUNT(CASE WHEN status IN ('issued', 'partial', 'overdue') AND due_date < CURRENT_DATE 
            THEN 1 END) AS overdue_count,
        AVG(total) AS avg_invoice_value
    FROM invoices WHERE status != 'cancelled'
),
product_inv AS (
    SELECT 
        COUNT(*) AS total_products,
        SUM(stock) AS total_product_stock,
        SUM(stock * COALESCE(NULLIF(cost_price, 0), unit_price)) AS product_inventory_value,
        COUNT(CASE WHEN stock <= min_stock AND stock > 0 THEN 1 END) AS low_stock_products,
        COUNT(CASE WHEN stock <= 0 THEN 1 END) AS out_of_stock_products
    FROM products WHERE is_active = TRUE
),
material_inv AS (
    SELECT 
        COUNT(*) AS total_materials,
        SUM(stock * COALESCE(NULLIF(cost_price, 0), NULLIF(price_per_kg, 0), unit_price)) AS material_inventory_value,
        COUNT(CASE WHEN stock <= min_stock AND stock > 0 THEN 1 END) AS low_stock_materials,
        COUNT(CASE WHEN stock <= 0 THEN 1 END) AS out_of_stock_materials
    FROM materials WHERE is_active = TRUE
),
credit_info AS (
    SELECT 
        SUM(credit_limit) AS total_credit_limit,
        SUM(current_balance) AS total_credit_used
    FROM customers WHERE is_active = TRUE
),
last_30d AS (
    SELECT 
        COALESCE(SUM(total), 0) AS revenue_30d,
        COALESCE(SUM(paid_amount), 0) AS collected_30d,
        COUNT(*) AS invoices_30d
    FROM invoices 
    WHERE status != 'cancelled' 
    AND issue_date >= NOW() - INTERVAL '30 days'
)
SELECT 
    -- Ventas
    ai.total_invoices,
    ROUND(COALESCE(ai.total_revenue, 0)::NUMERIC, 2) AS total_revenue,
    ROUND(COALESCE(ai.total_collected, 0)::NUMERIC, 2) AS total_collected,
    ROUND(COALESCE(ai.total_receivables, 0)::NUMERIC, 2) AS total_receivables,
    ROUND(COALESCE(ai.overdue_amount, 0)::NUMERIC, 2) AS overdue_amount,
    ai.overdue_count,
    ROUND(COALESCE(ai.avg_invoice_value, 0)::NUMERIC, 2) AS avg_invoice_value,
    
    -- Inventario
    pi.total_products,
    ROUND(COALESCE(pi.product_inventory_value, 0)::NUMERIC, 2) AS product_inventory_value,
    pi.low_stock_products,
    pi.out_of_stock_products,
    mi.total_materials,
    ROUND(COALESCE(mi.material_inventory_value, 0)::NUMERIC, 2) AS material_inventory_value,
    mi.low_stock_materials,
    mi.out_of_stock_materials,
    ROUND(COALESCE(pi.product_inventory_value, 0) + COALESCE(mi.material_inventory_value, 0))::NUMERIC AS total_inventory_value,
    
    -- Crédito
    ROUND(COALESCE(ci.total_credit_limit, 0)::NUMERIC, 2) AS total_credit_limit,
    ROUND(COALESCE(ci.total_credit_used, 0)::NUMERIC, 2) AS total_credit_used,
    CASE WHEN COALESCE(ci.total_credit_limit, 0) > 0 
         THEN ROUND((ci.total_credit_used / ci.total_credit_limit * 100)::NUMERIC, 1)
         ELSE 0 END AS credit_utilization_pct,
    
    -- Últimos 30 días
    ROUND(l30.revenue_30d::NUMERIC, 2) AS revenue_last_30d,
    ROUND(l30.collected_30d::NUMERIC, 2) AS collected_last_30d,
    l30.invoices_30d,
    
    -- Ratios de salud
    CASE WHEN COALESCE(ai.total_revenue, 0) > 0
         THEN ROUND((ai.total_receivables / ai.total_revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS receivables_to_revenue_pct,
    CASE WHEN COALESCE(ai.total_revenue, 0) > 0
         THEN ROUND(((pi.product_inventory_value + mi.material_inventory_value) / ai.total_revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS inventory_to_revenue_pct,
    
    -- Score de salud (0-100)
    GREATEST(0, LEAST(100, (
        -- Base de 50 si hay actividad
        CASE WHEN ai.total_invoices > 0 THEN 50 ELSE 0 END
        -- +20 si la tasa de cobro es > 80%
        + CASE WHEN ai.total_revenue > 0 AND (ai.total_collected / ai.total_revenue) >= 0.8 THEN 20
               WHEN ai.total_revenue > 0 AND (ai.total_collected / ai.total_revenue) >= 0.5 THEN 10
               ELSE 0 END
        -- +15 si no hay stock crítico
        + CASE WHEN pi.out_of_stock_products = 0 AND mi.out_of_stock_materials = 0 THEN 15
               WHEN (COALESCE(pi.out_of_stock_products, 0) + COALESCE(mi.out_of_stock_materials, 0)) <= 2 THEN 8
               ELSE 0 END
        -- +15 si mora < 10% de ventas
        + CASE WHEN ai.total_revenue > 0 AND (ai.overdue_amount / ai.total_revenue) < 0.1 THEN 15
               WHEN ai.total_revenue > 0 AND (ai.overdue_amount / ai.total_revenue) < 0.3 THEN 8
               ELSE 0 END
    ))) AS health_score

FROM active_invoices ai
CROSS JOIN product_inv pi
CROSS JOIN material_inv mi
CROSS JOIN credit_info ci
CROSS JOIN last_30d l30;

-- =====================================================
-- 4. PERMISOS
-- =====================================================

GRANT SELECT ON v_customer_metrics TO anon, authenticated;
GRANT SELECT ON v_customer_purchase_history TO anon, authenticated;
GRANT SELECT ON v_business_health_monthly TO anon, authenticated;
GRANT SELECT ON v_inventory_turnover TO anon, authenticated;
GRANT SELECT ON v_material_efficiency TO anon, authenticated;
GRANT SELECT ON v_business_health_snapshot TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_dso_trend TO anon, authenticated;

-- =====================================================
-- RESUMEN
-- =====================================================
SELECT '✅ Migración 052 - Analytics Mejorado' AS info;
SELECT '   Vistas creadas/actualizadas:' AS detalle;
SELECT '   - v_customer_metrics (NUEVA - reemplaza fallback Dart)' AS vista;
SELECT '   - v_customer_purchase_history (NUEVA)' AS vista;
SELECT '   - v_business_health_monthly (NUEVA - Crédito vs Ganancia vs Inventario)' AS vista;
SELECT '   - v_inventory_turnover (NUEVA - Rotación de inventario)' AS vista;
SELECT '   - v_material_efficiency (NUEVA - Eficiencia materia prima)' AS vista;
SELECT '   - v_business_health_snapshot (NUEVA - Score de salud del negocio)' AS vista;
SELECT '   Funciones:' AS detalle;
SELECT '   - get_dso_trend() (NUEVA - reemplaza fallback N+1 Dart)' AS funcion;
