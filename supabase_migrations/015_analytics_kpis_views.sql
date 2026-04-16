-- =====================================================
-- VISTAS ANALÍTICAS MEJORADAS PARA KPIs
-- Industrial de Molinos
-- Fecha: 24 de Diciembre, 2025
-- =====================================================

-- =====================================================
-- 1. VISTAS DE INVENTARIO
-- =====================================================

-- Vista: Análisis ABC de Productos
CREATE OR REPLACE VIEW v_inventory_abc_analysis AS
WITH product_sales AS (
    SELECT 
        COALESCE(ii.product_code, ii.product_name) as product_key,
        ii.product_name,
        ii.product_code,
        SUM(ii.total) as total_revenue,
        SUM(ii.quantity) as total_quantity,
        COUNT(DISTINCT ii.invoice_id) as times_sold
    FROM invoice_items ii
    JOIN invoices i ON ii.invoice_id = i.id
    WHERE i.status != 'cancelled'
    AND i.issue_date >= NOW() - INTERVAL '12 months'
    GROUP BY product_key, ii.product_name, ii.product_code
),
ranked_products AS (
    SELECT 
        product_key,
        product_name,
        product_code,
        total_revenue,
        total_quantity,
        times_sold,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) as running_total,
        SUM(total_revenue) OVER () as grand_total,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) as rank
    FROM product_sales
)
SELECT 
    product_key,
    product_name,
    product_code,
    total_revenue,
    total_quantity,
    times_sold,
    rank,
    ROUND((running_total / NULLIF(grand_total, 0) * 100)::NUMERIC, 2) as cumulative_percentage,
    CASE 
        WHEN (running_total / NULLIF(grand_total, 0)) <= 0.80 THEN 'A'
        WHEN (running_total / NULLIF(grand_total, 0)) <= 0.95 THEN 'B'
        ELSE 'C'
    END as abc_category,
    CASE 
        WHEN (running_total / NULLIF(grand_total, 0)) <= 0.80 THEN 'Alto valor - Prioridad máxima'
        WHEN (running_total / NULLIF(grand_total, 0)) <= 0.95 THEN 'Valor medio - Monitorear'
        ELSE 'Bajo valor - Stock mínimo'
    END as recommendation
FROM ranked_products
ORDER BY total_revenue DESC;

-- Vista: KPIs de Materiales
CREATE OR REPLACE VIEW v_material_inventory_kpis AS
SELECT 
    m.id,
    m.name,
    m.code,
    m.category,
    m.stock,
    m.min_stock,
    m.unit,
    m.price_per_kg as unit_price,
    COALESCE(m.cost_price, m.price_per_kg * 0.65) as cost_price,
    
    -- Valor del Inventario
    ROUND((m.stock * COALESCE(m.cost_price, m.price_per_kg * 0.65))::NUMERIC, 2) as inventory_value,
    
    -- Consumo últimos 30 días
    COALESCE(consumption.qty_30d, 0) as consumed_30_days,
    COALESCE(consumption.qty_90d, 0) as consumed_90_days,
    
    -- Consumo diario promedio (últimos 90 días)
    ROUND((COALESCE(consumption.qty_90d, 0) / 90.0)::NUMERIC, 2) as avg_daily_consumption,
    
    -- Días de Cobertura
    CASE 
        WHEN COALESCE(consumption.qty_90d, 0) > 0 
        THEN ROUND((m.stock / (consumption.qty_90d / 90.0))::NUMERIC, 0)
        ELSE 999
    END as days_of_coverage,
    
    -- Estado del Stock
    CASE 
        WHEN m.stock = 0 THEN 'SIN_STOCK'
        WHEN m.stock < m.min_stock THEN 'BAJO_STOCK'
        WHEN m.stock <= m.min_stock * 2 THEN 'NORMAL'
        ELSE 'EXCESO'
    END as stock_status,
    
    -- Última entrada y salida
    movements.last_incoming,
    movements.last_outgoing,
    
    -- Días sin movimiento
    EXTRACT(DAY FROM NOW() - GREATEST(
        COALESCE(movements.last_incoming, '2020-01-01'),
        COALESCE(movements.last_outgoing, '2020-01-01')
    ))::INTEGER as days_without_movement,
    
    -- Clasificación FSN
    CASE 
        WHEN COALESCE(consumption.qty_90d, 0) / 90.0 * 365 > m.stock * 4 THEN 'FAST'
        WHEN COALESCE(consumption.qty_90d, 0) > 0 THEN 'SLOW'
        ELSE 'NON_MOVING'
    END as fsn_category

FROM materials m
LEFT JOIN (
    SELECT 
        material_id,
        SUM(CASE WHEN created_at >= NOW() - INTERVAL '30 days' AND type = 'outgoing' 
            THEN quantity ELSE 0 END) as qty_30d,
        SUM(CASE WHEN type = 'outgoing' THEN quantity ELSE 0 END) as qty_90d
    FROM material_movements
    WHERE created_at >= NOW() - INTERVAL '90 days'
    GROUP BY material_id
) consumption ON m.id = consumption.material_id
LEFT JOIN (
    SELECT 
        material_id,
        MAX(CASE WHEN type = 'incoming' THEN created_at END) as last_incoming,
        MAX(CASE WHEN type = 'outgoing' THEN created_at END) as last_outgoing
    FROM material_movements
    GROUP BY material_id
) movements ON m.id = movements.material_id
WHERE m.is_active = true;

-- Vista: Resumen General de Inventario
CREATE OR REPLACE VIEW v_inventory_summary AS
SELECT 
    COUNT(*) as total_products,
    SUM(CASE WHEN stock = 0 THEN 1 ELSE 0 END) as out_of_stock_count,
    SUM(CASE WHEN stock > 0 AND stock < min_stock THEN 1 ELSE 0 END) as low_stock_count,
    SUM(CASE WHEN stock >= min_stock THEN 1 ELSE 0 END) as in_stock_count,
    ROUND(SUM(inventory_value)::NUMERIC, 2) as total_inventory_value,
    ROUND(AVG(days_of_coverage)::NUMERIC, 0) as avg_days_coverage,
    SUM(CASE WHEN fsn_category = 'FAST' THEN 1 ELSE 0 END) as fast_moving_count,
    SUM(CASE WHEN fsn_category = 'SLOW' THEN 1 ELSE 0 END) as slow_moving_count,
    SUM(CASE WHEN fsn_category = 'NON_MOVING' THEN 1 ELSE 0 END) as non_moving_count
FROM v_material_inventory_kpis;

-- =====================================================
-- 2. VISTAS DE COBRANZAS
-- =====================================================

-- Vista: Resumen de Antigüedad de Cartera (Aging)
CREATE OR REPLACE VIEW v_receivables_aging_summary AS
SELECT 
    CASE 
        WHEN due_date >= CURRENT_DATE THEN '0_vigente'
        WHEN CURRENT_DATE - due_date BETWEEN 1 AND 30 THEN '1_1_30_dias'
        WHEN CURRENT_DATE - due_date BETWEEN 31 AND 60 THEN '2_31_60_dias'
        WHEN CURRENT_DATE - due_date BETWEEN 61 AND 90 THEN '3_61_90_dias'
        ELSE '4_mas_90_dias'
    END as aging_bucket,
    CASE 
        WHEN due_date >= CURRENT_DATE THEN 'Vigente'
        WHEN CURRENT_DATE - due_date BETWEEN 1 AND 30 THEN '1-30 días'
        WHEN CURRENT_DATE - due_date BETWEEN 31 AND 60 THEN '31-60 días'
        WHEN CURRENT_DATE - due_date BETWEEN 61 AND 90 THEN '61-90 días'
        ELSE 'Más de 90 días'
    END as aging_label,
    COUNT(*) as num_invoices,
    COUNT(DISTINCT customer_id) as num_customers,
    ROUND(SUM(total - paid_amount)::NUMERIC, 2) as pending_amount,
    ROUND(AVG(total - paid_amount)::NUMERIC, 2) as avg_pending,
    ROUND(AVG(GREATEST(CURRENT_DATE - due_date, 0))::NUMERIC, 0) as avg_days_overdue
FROM invoices
WHERE status NOT IN ('paid', 'cancelled')
AND (total - paid_amount) > 0
GROUP BY aging_bucket, aging_label
ORDER BY aging_bucket;

-- Vista: KPIs de Cobranzas
CREATE OR REPLACE VIEW v_receivables_kpis AS
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', issue_date) as month,
        SUM(total) as total_sales,
        SUM(paid_amount) as total_collected,
        SUM(total - paid_amount) as total_pending
    FROM invoices
    WHERE status != 'cancelled'
    AND issue_date >= NOW() - INTERVAL '12 months'
    GROUP BY DATE_TRUNC('month', issue_date)
),
current_ar AS (
    SELECT 
        SUM(total - paid_amount) as total_receivables,
        COUNT(*) as pending_invoices,
        AVG(CURRENT_DATE - issue_date) as avg_invoice_age
    FROM invoices
    WHERE status NOT IN ('paid', 'cancelled')
    AND (total - paid_amount) > 0
),
dso_calc AS (
    SELECT 
        ROUND((
            (SELECT SUM(total - paid_amount) FROM invoices WHERE status NOT IN ('paid', 'cancelled')) /
            NULLIF((SELECT SUM(total) FROM invoices WHERE status != 'cancelled' AND issue_date >= NOW() - INTERVAL '30 days'), 0)
            * 30
        )::NUMERIC, 1) as dso
),
cei_calc AS (
    -- CEI = (Beginning AR + Credit Sales - Ending AR) / (Beginning AR + Credit Sales - Current AR)
    SELECT 
        ROUND((
            (COALESCE(beg.beginning_ar, 0) + COALESCE(sales.credit_sales, 0) - COALESCE(end_ar.ending_ar, 0)) /
            NULLIF((COALESCE(beg.beginning_ar, 0) + COALESCE(sales.credit_sales, 0) - COALESCE(curr.current_ar, 0)), 0)
            * 100
        )::NUMERIC, 1) as cei
    FROM 
        (SELECT SUM(total - paid_amount) as beginning_ar FROM invoices 
         WHERE issue_date < DATE_TRUNC('month', NOW()) AND status NOT IN ('paid', 'cancelled')) beg,
        (SELECT SUM(total) as credit_sales FROM invoices 
         WHERE issue_date >= DATE_TRUNC('month', NOW()) AND status != 'cancelled') sales,
        (SELECT SUM(total - paid_amount) as ending_ar FROM invoices 
         WHERE status NOT IN ('paid', 'cancelled')) end_ar,
        (SELECT SUM(total - paid_amount) as current_ar FROM invoices 
         WHERE status NOT IN ('paid', 'cancelled') AND due_date >= CURRENT_DATE) curr
)
SELECT 
    COALESCE(ar.total_receivables, 0) as total_receivables,
    ar.pending_invoices,
    ROUND(COALESCE(ar.avg_invoice_age, 0)::NUMERIC, 0) as avg_invoice_age,
    COALESCE(dso.dso, 0) as dso_days,
    COALESCE(cei.cei, 0) as collection_effectiveness_index,
    
    -- AR Turnover (anualizado)
    CASE 
        WHEN ar.total_receivables > 0 
        THEN ROUND((
            (SELECT SUM(total) FROM invoices WHERE status != 'cancelled' AND issue_date >= NOW() - INTERVAL '12 months') /
            ar.total_receivables
        )::NUMERIC, 2)
        ELSE 0
    END as ar_turnover,
    
    -- Porcentaje de morosidad
    ROUND((
        (SELECT SUM(total - paid_amount) FROM invoices WHERE status NOT IN ('paid', 'cancelled') AND due_date < CURRENT_DATE) /
        NULLIF(ar.total_receivables, 0) * 100
    )::NUMERIC, 1) as delinquency_rate

FROM current_ar ar
CROSS JOIN dso_calc dso
CROSS JOIN cei_calc cei;

-- Vista: Clientes Morosos (Top Debtors)
CREATE OR REPLACE VIEW v_top_debtors AS
SELECT 
    c.id as customer_id,
    c.name as customer_name,
    c.document_number,
    c.phone,
    COUNT(i.id) as pending_invoices,
    ROUND(SUM(i.total - i.paid_amount)::NUMERIC, 2) as total_debt,
    MIN(i.due_date) as oldest_due_date,
    MAX(CURRENT_DATE - i.due_date) as max_days_overdue,
    ROUND(AVG(CURRENT_DATE - i.due_date)::NUMERIC, 0) as avg_days_overdue,
    CASE 
        WHEN MAX(CURRENT_DATE - i.due_date) > 90 THEN 'CRITICO'
        WHEN MAX(CURRENT_DATE - i.due_date) > 60 THEN 'ALTO'
        WHEN MAX(CURRENT_DATE - i.due_date) > 30 THEN 'MEDIO'
        ELSE 'BAJO'
    END as risk_level
FROM customers c
JOIN invoices i ON c.id = i.customer_id
WHERE i.status NOT IN ('paid', 'cancelled')
AND (i.total - i.paid_amount) > 0
AND i.due_date < CURRENT_DATE
GROUP BY c.id, c.name, c.document_number, c.phone
ORDER BY total_debt DESC;

-- Vista: Comportamiento de Pago de Clientes
CREATE OR REPLACE VIEW v_customer_payment_behavior AS
SELECT 
    c.id,
    c.name,
    c.document_number,
    c.credit_limit,
    c.current_balance,
    
    -- Estadísticas de facturas
    COUNT(i.id) as total_invoices,
    SUM(CASE WHEN i.status = 'paid' THEN 1 ELSE 0 END) as paid_invoices,
    SUM(CASE WHEN i.status NOT IN ('paid', 'cancelled') THEN 1 ELSE 0 END) as pending_invoices,
    
    -- Montos
    ROUND(COALESCE(SUM(i.total), 0)::NUMERIC, 2) as total_billed,
    ROUND(COALESCE(SUM(i.paid_amount), 0)::NUMERIC, 2) as total_paid,
    ROUND(COALESCE(SUM(i.total - i.paid_amount), 0)::NUMERIC, 2) as total_pending,
    
    -- Promedio de días para pagar (usando issue_date y due_date como referencia)
    ROUND(AVG(
        CASE WHEN i.status = 'paid' 
        THEN COALESCE(i.due_date - i.issue_date, 30)
        ELSE NULL END
    )::NUMERIC, 0) as avg_days_to_pay,
    
    -- Facturas pagadas antes/después del vencimiento
    SUM(CASE WHEN i.status = 'paid' AND i.due_date >= i.issue_date THEN 1 ELSE 0 END) as on_time_payments,
    SUM(CASE WHEN i.status = 'paid' AND i.due_date < i.issue_date THEN 1 ELSE 0 END) as late_payments,
    
    -- Porcentaje de pagos (basado en facturas pagadas vs total)
    ROUND(
        CASE WHEN COUNT(i.id) > 0
        THEN SUM(CASE WHEN i.status = 'paid' THEN 1 ELSE 0 END)::NUMERIC /
             COUNT(i.id) * 100
        ELSE 0 END, 1
    ) as payment_percentage,
    
    -- Rating del cliente (basado en % de facturas pagadas)
    CASE 
        WHEN COUNT(i.id) = 0 THEN 'Sin historial'
        WHEN SUM(CASE WHEN i.status = 'paid' THEN 1 ELSE 0 END)::NUMERIC /
             NULLIF(COUNT(i.id), 0) >= 0.90 THEN 'Excelente'
        WHEN SUM(CASE WHEN i.status = 'paid' THEN 1 ELSE 0 END)::NUMERIC /
             NULLIF(COUNT(i.id), 0) >= 0.70 THEN 'Bueno'
        WHEN SUM(CASE WHEN i.status = 'paid' THEN 1 ELSE 0 END)::NUMERIC /
             NULLIF(COUNT(i.id), 0) >= 0.50 THEN 'Regular'
        ELSE 'Riesgoso'
    END as payment_rating,
    
    -- Última compra
    MAX(i.issue_date) as last_purchase_date,
    MIN(i.issue_date) as first_purchase_date

FROM customers c
LEFT JOIN invoices i ON c.id = i.customer_id AND i.status != 'cancelled'
GROUP BY c.id, c.name, c.document_number, c.credit_limit, c.current_balance;

-- =====================================================
-- 3. FUNCIONES AUXILIARES
-- =====================================================

-- Función: Calcular DSO para un período específico
CREATE OR REPLACE FUNCTION calculate_dso(p_start_date DATE, p_end_date DATE)
RETURNS NUMERIC AS $$
DECLARE
    v_total_ar NUMERIC;
    v_total_sales NUMERIC;
    v_days INTEGER;
    v_dso NUMERIC;
BEGIN
    v_days := p_end_date - p_start_date;
    
    SELECT COALESCE(SUM(total - paid_amount), 0) INTO v_total_ar
    FROM invoices
    WHERE status NOT IN ('paid', 'cancelled')
    AND issue_date <= p_end_date;
    
    SELECT COALESCE(SUM(total), 0) INTO v_total_sales
    FROM invoices
    WHERE status != 'cancelled'
    AND issue_date BETWEEN p_start_date AND p_end_date;
    
    IF v_total_sales > 0 THEN
        v_dso := (v_total_ar / v_total_sales) * v_days;
    ELSE
        v_dso := 0;
    END IF;
    
    RETURN ROUND(v_dso, 1);
END;
$$ LANGUAGE plpgsql;

-- Función: Obtener resumen de inventario ABC
CREATE OR REPLACE FUNCTION get_inventory_abc_summary()
RETURNS TABLE (
    category VARCHAR,
    product_count INTEGER,
    total_revenue NUMERIC,
    percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        abc_category::VARCHAR as category,
        COUNT(*)::INTEGER as product_count,
        ROUND(SUM(total_revenue)::NUMERIC, 2) as total_revenue,
        ROUND((SUM(total_revenue) / NULLIF((SELECT SUM(total_revenue) FROM v_inventory_abc_analysis), 0) * 100)::NUMERIC, 1) as percentage
    FROM v_inventory_abc_analysis
    GROUP BY abc_category
    ORDER BY abc_category;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. PERMISOS
-- =====================================================

GRANT SELECT ON v_inventory_abc_analysis TO anon, authenticated;
GRANT SELECT ON v_material_inventory_kpis TO anon, authenticated;
GRANT SELECT ON v_inventory_summary TO anon, authenticated;
GRANT SELECT ON v_receivables_aging_summary TO anon, authenticated;
GRANT SELECT ON v_receivables_kpis TO anon, authenticated;
GRANT SELECT ON v_top_debtors TO anon, authenticated;
GRANT SELECT ON v_customer_payment_behavior TO anon, authenticated;
GRANT EXECUTE ON FUNCTION calculate_dso TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_inventory_abc_summary TO anon, authenticated;

-- =====================================================
-- RESUMEN
-- =====================================================
SELECT '✅ Vistas de Inventario:' AS info;
SELECT '   - v_inventory_abc_analysis (Análisis ABC)' AS vista;
SELECT '   - v_material_inventory_kpis (KPIs de materiales)' AS vista;
SELECT '   - v_inventory_summary (Resumen general)' AS vista;
SELECT '' AS spacer;
SELECT '✅ Vistas de Cobranzas:' AS info;
SELECT '   - v_receivables_aging_summary (Antigüedad)' AS vista;
SELECT '   - v_receivables_kpis (KPIs principales)' AS vista;
SELECT '   - v_top_debtors (Top morosos)' AS vista;
SELECT '   - v_customer_payment_behavior (Comportamiento de pago)' AS vista;
SELECT '' AS spacer;
SELECT '✅ Funciones:' AS info;
SELECT '   - calculate_dso(start_date, end_date)' AS funcion;
SELECT '   - get_inventory_abc_summary()' AS funcion;
