-- =====================================================
-- MIGRACIÓN 035: Vistas Materializadas para Analytics
-- =====================================================
-- Convierte las vistas más pesadas a materialized views
-- con función de refresh manual/periódico.
-- =====================================================

-- =====================================================
-- 1. v_receivables_kpis → MATERIALIZADA
-- (4 CTEs + sub-SELECTs + CROSS JOINs — dashboard KPI)
-- =====================================================
DROP VIEW IF EXISTS v_receivables_kpis CASCADE;

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_receivables_kpis AS
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', issue_date) AS month,
        SUM(total) AS total_billed,
        SUM(paid_amount) AS total_collected,
        COUNT(*) AS invoice_count
    FROM invoices
    WHERE status != 'anulada'
    GROUP BY DATE_TRUNC('month', issue_date)
),
current_ar AS (
    SELECT 
        COALESCE(SUM(total - paid_amount), 0) AS total_ar,
        COUNT(*) AS open_invoices,
        COALESCE(AVG(total - paid_amount), 0) AS avg_ar
    FROM invoices
    WHERE status IN ('pendiente', 'parcial', 'vencida')
),
dso_calc AS (
    SELECT 
        CASE 
            WHEN COALESCE(SUM(total), 0) > 0 
            THEN (COALESCE(SUM(total - paid_amount), 0) / COALESCE(SUM(total), 1)) * 30
            ELSE 0
        END AS dso_days
    FROM invoices
    WHERE status != 'anulada'
      AND issue_date >= CURRENT_DATE - INTERVAL '90 days'
),
cei_calc AS (
    SELECT 
        CASE 
            WHEN COALESCE(SUM(total), 0) > 0 
            THEN (COALESCE(SUM(paid_amount), 0) / COALESCE(SUM(total), 1)) * 100
            ELSE 0
        END AS cei_pct
    FROM invoices
    WHERE status != 'anulada'
      AND issue_date >= CURRENT_DATE - INTERVAL '90 days'
)
SELECT 
    ca.total_ar,
    ca.open_invoices,
    ca.avg_ar,
    dc.dso_days,
    cc.cei_pct,
    COALESCE((SELECT total_collected FROM monthly_data ORDER BY month DESC LIMIT 1), 0) AS last_month_collected,
    COALESCE((SELECT total_billed FROM monthly_data ORDER BY month DESC LIMIT 1), 0) AS last_month_billed,
    NOW() AS refreshed_at
FROM current_ar ca
CROSS JOIN dso_calc dc
CROSS JOIN cei_calc cc;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_receivables_kpis ON mv_receivables_kpis(refreshed_at);

-- =====================================================
-- 2. v_profit_loss_monthly → MATERIALIZADA
-- (CTE + 3-way LEFT JOIN — reportes)
-- =====================================================
DROP VIEW IF EXISTS v_profit_loss_monthly CASCADE;

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_profit_loss_monthly AS
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', issue_date) AS period,
        COALESCE(SUM(subtotal), 0) AS revenue,
        COALESCE(SUM(tax_amount), 0) AS tax_collected,
        COALESCE(SUM(total), 0) AS total_sales,
        COUNT(*) AS invoice_count
    FROM invoices
    WHERE status NOT IN ('anulada')
    GROUP BY DATE_TRUNC('month', issue_date)
),
monthly_variable_expenses AS (
    SELECT 
        DATE_TRUNC('month', date) AS period,
        COALESCE(SUM(amount), 0) AS variable_expenses
    FROM cash_movements
    WHERE type = 'expense'
      AND category NOT IN ('payroll', 'transfer_out')
    GROUP BY DATE_TRUNC('month', date)
)
SELECT 
    ms.period,
    ms.revenue,
    ms.tax_collected,
    ms.total_sales,
    ms.invoice_count,
    COALESCE(me.amount, 0) AS fixed_expenses,
    COALESCE(mve.variable_expenses, 0) AS variable_expenses,
    COALESCE(me.amount, 0) + COALESCE(mve.variable_expenses, 0) AS total_expenses,
    ms.revenue - COALESCE(me.amount, 0) - COALESCE(mve.variable_expenses, 0) AS net_profit,
    CASE 
        WHEN ms.revenue > 0 
        THEN ((ms.revenue - COALESCE(me.amount, 0) - COALESCE(mve.variable_expenses, 0)) / ms.revenue) * 100
        ELSE 0
    END AS profit_margin_pct,
    NOW() AS refreshed_at
FROM monthly_sales ms
LEFT JOIN monthly_expenses me ON me.year = EXTRACT(YEAR FROM ms.period)::INT 
    AND me.month = EXTRACT(MONTH FROM ms.period)::INT
LEFT JOIN monthly_variable_expenses mve ON mve.period = ms.period
ORDER BY ms.period DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_pnl_period ON mv_profit_loss_monthly(period);

-- =====================================================
-- 3. v_inventory_abc_analysis → MATERIALIZADA
-- (2 CTEs + window functions — inventario)
-- =====================================================
DROP VIEW IF EXISTS v_inventory_abc_analysis CASCADE;

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_inventory_abc_analysis AS
WITH product_sales AS (
    SELECT 
        p.id AS product_id,
        p.name,
        p.code,
        p.category_id,
        p.stock,
        p.sale_price,
        p.cost_price,
        COALESCE(SUM(ii.quantity), 0) AS total_sold,
        COALESCE(SUM(ii.subtotal), 0) AS total_revenue
    FROM products p
    LEFT JOIN invoice_items ii ON ii.product_id = p.id
    LEFT JOIN invoices i ON i.id = ii.invoice_id 
        AND i.status NOT IN ('anulada')
        AND i.issue_date >= CURRENT_DATE - INTERVAL '12 months'
    WHERE p.is_active = true
    GROUP BY p.id, p.name, p.code, p.category_id, p.stock, p.sale_price, p.cost_price
),
ranked AS (
    SELECT *,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS grand_total,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS rank
    FROM product_sales
)
SELECT 
    product_id, name, code, category_id, stock, sale_price, cost_price,
    total_sold, total_revenue, rank,
    CASE 
        WHEN grand_total > 0 AND (cumulative_revenue / grand_total) <= 0.80 THEN 'A'
        WHEN grand_total > 0 AND (cumulative_revenue / grand_total) <= 0.95 THEN 'B'
        ELSE 'C'
    END AS abc_category,
    CASE WHEN grand_total > 0 THEN (total_revenue / grand_total) * 100 ELSE 0 END AS revenue_pct,
    NOW() AS refreshed_at
FROM ranked;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_abc_product ON mv_inventory_abc_analysis(product_id);

-- =====================================================
-- 4. v_customer_payment_behavior → MATERIALIZADA
-- (12 aggregates — analytics)
-- =====================================================
DROP VIEW IF EXISTS v_customer_payment_behavior CASCADE;

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_customer_payment_behavior AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.document_number,
    COUNT(i.id) AS total_invoices,
    COUNT(CASE WHEN i.status = 'pagada' THEN 1 END) AS paid_invoices,
    COUNT(CASE WHEN i.status = 'vencida' THEN 1 END) AS overdue_invoices,
    COUNT(CASE WHEN i.status IN ('pendiente', 'parcial') THEN 1 END) AS pending_invoices,
    COALESCE(SUM(i.total), 0) AS total_billed,
    COALESCE(SUM(i.paid_amount), 0) AS total_paid,
    COALESCE(SUM(i.total - i.paid_amount), 0) AS total_outstanding,
    CASE 
        WHEN COUNT(i.id) > 0 
        THEN (COUNT(CASE WHEN i.status = 'pagada' THEN 1 END)::DECIMAL / COUNT(i.id)) * 100
        ELSE 0
    END AS payment_rate_pct,
    COALESCE(AVG(
        CASE WHEN i.status = 'pagada' AND i.due_date IS NOT NULL 
        THEN EXTRACT(DAY FROM (i.updated_at - i.due_date))
        END
    ), 0) AS avg_days_to_pay,
    MAX(i.issue_date) AS last_invoice_date,
    NOW() AS refreshed_at
FROM customers c
LEFT JOIN invoices i ON i.customer_id = c.id AND i.status != 'anulada'
WHERE c.is_active = true
GROUP BY c.id, c.name, c.document_number;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_payment_behavior_customer 
    ON mv_customer_payment_behavior(customer_id);

-- =====================================================
-- 5. DSO Trend — RPC para reemplazar N+1 en getDSOTrend()
-- (Dart hacía 24 queries en loop — ahora 1 sola)
-- =====================================================
CREATE OR REPLACE FUNCTION get_dso_trend(p_months INT DEFAULT 12)
RETURNS TABLE(
    month DATE,
    dso_days DECIMAL(10,2),
    total_billed DECIMAL(12,2),
    total_outstanding DECIMAL(12,2),
    invoice_count INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE_TRUNC('month', i.issue_date)::DATE AS month,
        CASE 
            WHEN SUM(i.total) > 0 
            THEN (SUM(i.total - i.paid_amount) / SUM(i.total)) * 30
            ELSE 0
        END AS dso_days,
        COALESCE(SUM(i.total), 0) AS total_billed,
        COALESCE(SUM(i.total - i.paid_amount), 0) AS total_outstanding,
        COUNT(i.id)::INT AS invoice_count
    FROM invoices i
    WHERE i.status != 'anulada'
      AND i.issue_date >= DATE_TRUNC('month', CURRENT_DATE) - (p_months || ' months')::INTERVAL
    GROUP BY DATE_TRUNC('month', i.issue_date)
    ORDER BY month DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- =====================================================
-- 6. Función de refresh para todas las vistas materializadas
-- =====================================================
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS JSONB AS $$
DECLARE
    v_start TIMESTAMP;
    v_results JSONB := '[]'::JSONB;
BEGIN
    -- Receivables KPIs
    v_start := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_receivables_kpis;
    v_results := v_results || jsonb_build_array(jsonb_build_object(
        'view', 'mv_receivables_kpis',
        'duration_ms', EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT
    ));

    -- Profit & Loss
    v_start := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_profit_loss_monthly;
    v_results := v_results || jsonb_build_array(jsonb_build_object(
        'view', 'mv_profit_loss_monthly',
        'duration_ms', EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT
    ));

    -- ABC Analysis
    v_start := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_inventory_abc_analysis;
    v_results := v_results || jsonb_build_array(jsonb_build_object(
        'view', 'mv_inventory_abc_analysis',
        'duration_ms', EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT
    ));

    -- Customer Payment Behavior
    v_start := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_payment_behavior;
    v_results := v_results || jsonb_build_array(jsonb_build_object(
        'view', 'mv_customer_payment_behavior',
        'duration_ms', EXTRACT(MILLISECONDS FROM clock_timestamp() - v_start)::INT
    ));

    RETURN jsonb_build_object(
        'success', true,
        'refreshed_at', NOW(),
        'views', v_results
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. Vistas de compatibilidad (mismos nombres originales)
-- Para que el código Dart existente siga funcionando
-- =====================================================
CREATE OR REPLACE VIEW v_receivables_kpis AS
    SELECT * FROM mv_receivables_kpis;

CREATE OR REPLACE VIEW v_profit_loss_monthly AS
    SELECT * FROM mv_profit_loss_monthly;

CREATE OR REPLACE VIEW v_inventory_abc_analysis AS
    SELECT * FROM mv_inventory_abc_analysis;

CREATE OR REPLACE VIEW v_customer_payment_behavior AS
    SELECT * FROM mv_customer_payment_behavior;

-- =====================================================
-- 8. Permisos
-- =====================================================
GRANT SELECT ON mv_receivables_kpis TO authenticated;
GRANT SELECT ON mv_profit_loss_monthly TO authenticated;
GRANT SELECT ON mv_inventory_abc_analysis TO authenticated;
GRANT SELECT ON mv_customer_payment_behavior TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_materialized_views() TO authenticated;
GRANT EXECUTE ON FUNCTION get_dso_trend(INT) TO authenticated;
