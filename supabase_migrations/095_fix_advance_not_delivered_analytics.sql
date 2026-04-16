-- =====================================================
-- MIGRACIÓN 095: Corregir vistas analíticas para excluir
-- adelantos sin entregar (advance + delivery_date IS NULL)
-- 
-- PROBLEMA: Facturas con sale_payment_type='advance' y sin
-- delivery_date son adelantos de trabajo, NO ventas reales.
-- Incluirlas infla: revenue, profit, DSO, KPIs, etc.
--
-- REGLA: (sale_payment_type != 'advance' OR delivery_date IS NOT NULL)
-- =====================================================

-- 1. Vista: Resumen de cliente con métricas
-- Excluir adelantos sin entregar del conteo de compras y gasto total
CREATE OR REPLACE VIEW v_customer_metrics AS
SELECT 
    c.id,
    c.name,
    c.document_number,
    c.type,
    c.current_balance AS debt,
    c.credit_limit,
    c.created_at AS customer_since,
    COUNT(DISTINCT i.id) AS total_purchases,
    COALESCE(SUM(i.total), 0) AS total_spent,
    COALESCE(AVG(i.total), 0) AS average_ticket,
    MAX(i.issue_date) AS last_purchase_date,
    MIN(i.issue_date) AS first_purchase_date,
    EXTRACT(DAY FROM NOW() - MAX(i.issue_date))::INTEGER AS days_since_last_purchase
FROM customers c
LEFT JOIN invoices i ON c.id = i.customer_id 
    AND i.status != 'cancelled'
    AND (i.sale_payment_type != 'advance' OR i.delivery_date IS NOT NULL)
GROUP BY c.id, c.name, c.document_number, c.type, c.current_balance, c.credit_limit, c.created_at;

-- 2. Vista: Productos más vendidos
-- Excluir items de adelantos sin entregar del ranking
CREATE OR REPLACE VIEW v_top_selling_products AS
SELECT 
    COALESCE(ii.product_id::TEXT, ii.material_id::TEXT, ii.product_code) AS product_key,
    ii.product_name,
    ii.product_code,
    SUM(ii.quantity) AS total_quantity,
    COUNT(DISTINCT ii.invoice_id) AS times_sold,
    SUM(ii.total) AS total_revenue,
    AVG(ii.unit_price) AS avg_price
FROM invoice_items ii
JOIN invoices i ON ii.invoice_id = i.id
WHERE i.status != 'cancelled'
AND (i.sale_payment_type != 'advance' OR i.delivery_date IS NOT NULL)
GROUP BY product_key, ii.product_name, ii.product_code
ORDER BY total_revenue DESC;

-- 3. Vista: Ventas por período
-- Excluir adelantos sin entregar de las ventas
CREATE OR REPLACE VIEW v_sales_by_period AS
SELECT 
    DATE_TRUNC('day', issue_date) AS day,
    DATE_TRUNC('week', issue_date) AS week,
    DATE_TRUNC('month', issue_date) AS month,
    DATE_TRUNC('year', issue_date) AS year,
    COUNT(*) AS num_invoices,
    SUM(subtotal) AS subtotal,
    SUM(tax_amount) AS tax,
    SUM(total) AS total,
    SUM(paid_amount) AS collected,
    SUM(total - paid_amount) AS pending,
    AVG(total) AS avg_ticket
FROM invoices
WHERE status != 'cancelled'
AND (sale_payment_type != 'advance' OR delivery_date IS NOT NULL)
GROUP BY day, week, month, year
ORDER BY day DESC;

-- 4. Vista: Gastos vs Ingresos (P&L mensual)
-- Excluir adelantos sin entregar del revenue
CREATE OR REPLACE VIEW v_profit_loss_monthly AS
WITH monthly_sales AS (
    SELECT 
        EXTRACT(YEAR FROM issue_date)::INTEGER AS year,
        EXTRACT(MONTH FROM issue_date)::INTEGER AS month,
        COALESCE(SUM(total), 0) AS revenue
    FROM invoices
    WHERE status != 'cancelled'
    AND (sale_payment_type != 'advance' OR delivery_date IS NOT NULL)
    GROUP BY EXTRACT(YEAR FROM issue_date), EXTRACT(MONTH FROM issue_date)
),
monthly_expenses AS (
    SELECT
        EXTRACT(YEAR FROM date)::INTEGER AS year,
        EXTRACT(MONTH FROM date)::INTEGER AS month,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_fixed
    FROM cash_movements
    GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)
),
monthly_variable_expenses AS (
    SELECT 
        EXTRACT(YEAR FROM date)::INTEGER AS year,
        EXTRACT(MONTH FROM date)::INTEGER AS month,
        COALESCE(SUM(amount), 0) AS variable_expenses
    FROM cash_movements
    WHERE type = 'expense'
    GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)
)
SELECT 
    ms.year,
    ms.month,
    ms.revenue,
    COALESCE(me.total_fixed, 0) AS fixed_expenses,
    COALESCE(mve.variable_expenses, 0) AS variable_expenses,
    ms.revenue - COALESCE(me.total_fixed, 0) - COALESCE(mve.variable_expenses, 0) AS gross_profit
FROM monthly_sales ms
LEFT JOIN monthly_expenses me ON ms.year = me.year AND ms.month = me.month
LEFT JOIN monthly_variable_expenses mve ON ms.year = mve.year AND ms.month = mve.month
ORDER BY ms.year DESC, ms.month DESC;

-- 5. Vista: Análisis de productos por cliente
-- Excluir adelantos sin entregar
CREATE OR REPLACE VIEW v_customer_product_analysis AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    ii.product_name,
    ii.product_code,
    COUNT(*) AS purchase_count,
    SUM(ii.quantity) AS total_quantity,
    SUM(ii.total) AS total_spent,
    MIN(i.issue_date) AS first_purchase,
    MAX(i.issue_date) AS last_purchase,
    AVG(ii.quantity) AS avg_quantity_per_purchase
FROM customers c
JOIN invoices i ON c.id = i.customer_id
JOIN invoice_items ii ON i.id = ii.invoice_id
WHERE i.status != 'cancelled'
AND (i.sale_payment_type != 'advance' OR i.delivery_date IS NOT NULL)
GROUP BY c.id, c.name, ii.product_name, ii.product_code
ORDER BY c.name, purchase_count DESC;

-- 6. Vista: Cuentas por cobrar con antigüedad
-- Excluir adelantos sin entregar (son adelantos de trabajo, no deuda)
CREATE OR REPLACE VIEW v_accounts_receivable_aging AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.document_number,
    i.id AS invoice_id,
    i.full_number,
    i.issue_date,
    i.due_date,
    i.total,
    i.paid_amount,
    (i.total - i.paid_amount) AS pending_amount,
    CASE 
        WHEN i.due_date >= CURRENT_DATE THEN 'current'
        WHEN CURRENT_DATE - i.due_date <= 30 THEN '1-30 days'
        WHEN CURRENT_DATE - i.due_date <= 60 THEN '31-60 days'
        WHEN CURRENT_DATE - i.due_date <= 90 THEN '61-90 days'
        ELSE 'over 90 days'
    END AS aging_bucket,
    (CURRENT_DATE - i.due_date) AS days_overdue
FROM invoices i
JOIN customers c ON i.customer_id = c.id
WHERE i.status NOT IN ('paid', 'cancelled')
AND (i.total - i.paid_amount) > 0
AND (i.sale_payment_type != 'advance' OR i.delivery_date IS NOT NULL)
ORDER BY days_overdue DESC;

-- 7. Función: DSO Trend (excluir adelantos sin entregar)
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
            AND (i.sale_payment_type != 'advance' OR i.delivery_date IS NOT NULL)
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

-- 8. Vista: Salud del Negocio mensual
-- Excluir adelantos sin entregar del crédito y revenue
CREATE OR REPLACE VIEW v_business_health_monthly AS
WITH months AS (
    SELECT generate_series(
        DATE_TRUNC('month', NOW()) - INTERVAL '11 months',
        DATE_TRUNC('month', NOW()),
        '1 month'::INTERVAL
    )::DATE AS month_start
),
credit_data AS (
    SELECT 
        m.month_start,
        COALESCE(SUM(i.total - i.paid_amount), 0) AS credit_extended
    FROM months m
    LEFT JOIN invoices i ON 
        i.issue_date <= (m.month_start + INTERVAL '1 month' - INTERVAL '1 day')
        AND i.status NOT IN ('cancelled', 'paid', 'draft')
        AND (i.sale_payment_type != 'advance' OR i.delivery_date IS NOT NULL)
    GROUP BY m.month_start
),
revenue_data AS (
    SELECT 
        m.month_start,
        COALESCE(SUM(i.total), 0) AS revenue,
        COALESCE(SUM(i.paid_amount), 0) AS collected
    FROM months m
    LEFT JOIN invoices i ON 
        DATE_TRUNC('month', i.issue_date) = m.month_start
        AND i.status != 'cancelled'
        AND (i.sale_payment_type != 'advance' OR i.delivery_date IS NOT NULL)
    GROUP BY m.month_start
),
inventory_data AS (
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
            m.stock * COALESCE(NULLIF(m.cost_price, 0), NULLIF(m.price_per_kg, 0), m.unit_price)
        ), 0) AS material_value
    FROM materials m 
    WHERE m.is_active = TRUE AND m.stock > 0
)
SELECT 
    TO_CHAR(m.month_start, 'YYYY-MM') AS month,
    ROUND(COALESCE(cd.credit_extended, 0)::NUMERIC, 2) AS credit_extended,
    ROUND(COALESCE(rd.revenue, 0)::NUMERIC, 2) AS revenue,
    ROUND(COALESCE(rd.collected, 0)::NUMERIC, 2) AS collected,
    ROUND((COALESCE(id.product_value, 0) + COALESCE(mi.material_value, 0))::NUMERIC, 2) AS inventory_value,
    ROUND(COALESCE(rd.revenue, 0)::NUMERIC - COALESCE(cd.credit_extended, 0)::NUMERIC, 2) AS net_profit_estimate,
    CASE WHEN COALESCE(rd.revenue, 0) > 0
         THEN ROUND((rd.collected::NUMERIC / rd.revenue::NUMERIC * 100), 1)
         ELSE 0 END AS collection_rate
FROM months m
LEFT JOIN credit_data cd ON cd.month_start = m.month_start
LEFT JOIN revenue_data rd ON rd.month_start = m.month_start
CROSS JOIN inventory_data id
CROSS JOIN material_inventory mi
ORDER BY m.month_start;

-- 9. Vista: Snapshot de Salud del Negocio
-- Excluir adelantos sin entregar de totales y score
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
    FROM invoices 
    WHERE status != 'cancelled'
    AND (sale_payment_type != 'advance' OR delivery_date IS NOT NULL)
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
    AND (sale_payment_type != 'advance' OR delivery_date IS NOT NULL)
),
advance_summary AS (
    SELECT 
        COUNT(*) AS advance_count,
        COALESCE(SUM(total), 0) AS advance_total,
        COALESCE(SUM(paid_amount), 0) AS advance_paid
    FROM invoices
    WHERE status != 'cancelled'
    AND sale_payment_type = 'advance'
    AND delivery_date IS NULL
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
    
    -- Adelantos sin entregar (informativo)
    adv.advance_count AS pending_advances_count,
    ROUND(COALESCE(adv.advance_total, 0)::NUMERIC, 2) AS pending_advances_total,
    ROUND(COALESCE(adv.advance_paid, 0)::NUMERIC, 2) AS pending_advances_paid,
    
    -- Ratios de salud
    CASE WHEN COALESCE(ai.total_revenue, 0) > 0
         THEN ROUND((ai.total_receivables / ai.total_revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS receivables_to_revenue_pct,
    CASE WHEN COALESCE(ai.total_revenue, 0) > 0
         THEN ROUND(((pi.product_inventory_value + mi.material_inventory_value) / ai.total_revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS inventory_to_revenue_pct,
    
    -- Score de salud (0-100)
    GREATEST(0, LEAST(100, (
        CASE WHEN ai.total_invoices > 0 THEN 50 ELSE 0 END
        + CASE WHEN ai.total_revenue > 0 AND (ai.total_collected / ai.total_revenue) >= 0.8 THEN 20
               WHEN ai.total_revenue > 0 AND (ai.total_collected / ai.total_revenue) >= 0.5 THEN 10
               ELSE 0 END
        + CASE WHEN pi.out_of_stock_products = 0 AND mi.out_of_stock_materials = 0 THEN 15
               WHEN (COALESCE(pi.out_of_stock_products, 0) + COALESCE(mi.out_of_stock_materials, 0)) <= 2 THEN 8
               ELSE 0 END
        + CASE WHEN ai.total_revenue > 0 AND (ai.overdue_amount / ai.total_revenue) < 0.1 THEN 15
               WHEN ai.total_revenue > 0 AND (ai.overdue_amount / ai.total_revenue) < 0.3 THEN 8
               ELSE 0 END
    ))) AS health_score

FROM active_invoices ai
CROSS JOIN product_inv pi
CROSS JOIN material_inv mi
CROSS JOIN credit_info ci
CROSS JOIN last_30d l30
CROSS JOIN advance_summary adv;

-- 10. Vista: Rotación de inventario (excluir adelantos sin entregar de ventas)
CREATE OR REPLACE VIEW v_inventory_turnover AS
SELECT 
    p.id AS product_id,
    p.code AS product_code,
    p.name AS product_name,
    c.name AS category_name,
    p.stock AS current_stock,
    p.min_stock,
    COALESCE(NULLIF(p.cost_price, 0), p.unit_price) AS unit_cost,
    p.stock * COALESCE(NULLIF(p.cost_price, 0), p.unit_price) AS stock_value,
    COALESCE(sales.qty_sold_90d, 0) AS qty_sold_90_days,
    COALESCE(sales.revenue_90d, 0) AS revenue_90_days,
    -- Rotación anualizada = (Ventas 90d / 90 * 365) / Stock
    CASE WHEN p.stock > 0 AND COALESCE(sales.qty_sold_90d, 0) > 0
         THEN ROUND(((sales.qty_sold_90d / 90.0 * 365) / p.stock)::NUMERIC, 2)
         ELSE 0 END AS annual_turnover_rate,
    -- Días de inventario
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
    AND (i.sale_payment_type != 'advance' OR i.delivery_date IS NOT NULL)
    AND i.issue_date >= NOW() - INTERVAL '90 days'
) sales ON TRUE
WHERE p.is_active = TRUE;
