-- Agregar datos de salud de inventario (productos críticos) a la vista mensual
-- Reemplaza la línea plana de "valor inventario" con métricas de stock crítico

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
            CASE 
                WHEN mt.cost_price > 0 THEN mt.stock * mt.cost_price
                WHEN mt.price_per_kg > 0 THEN mt.stock * mt.price_per_kg
                ELSE mt.stock * mt.unit_price
            END
        ), 0) AS material_value
    FROM materials mt 
    WHERE mt.is_active = TRUE AND mt.stock > 0
),
-- Productos en estado crítico (stock bajo + sin stock)
stock_health AS (
    SELECT
        COUNT(*) FILTER (WHERE p.is_active = TRUE) AS total_products,
        COUNT(*) FILTER (WHERE p.is_active = TRUE AND p.stock <= 0) AS out_of_stock,
        COUNT(*) FILTER (WHERE p.is_active = TRUE AND p.stock > 0 AND p.stock <= p.min_stock) AS low_stock,
        COUNT(*) FILTER (WHERE p.is_active = TRUE AND (p.stock <= 0 OR p.stock <= p.min_stock)) AS critical_products
    FROM products p
),
material_health AS (
    SELECT
        COUNT(*) FILTER (WHERE mt.is_active = TRUE) AS total_materials,
        COUNT(*) FILTER (WHERE mt.is_active = TRUE AND (mt.stock <= 0 OR mt.stock <= mt.min_stock)) AS critical_materials
    FROM materials mt
)
SELECT 
    m.month_start AS month,
    EXTRACT(YEAR FROM m.month_start)::INT AS year,
    EXTRACT(MONTH FROM m.month_start)::INT AS month_num,
    ROUND(cd.credit_extended::NUMERIC, 2) AS credit_extended,
    ROUND(rd.revenue::NUMERIC, 2) AS revenue,
    ROUND(rd.collected::NUMERIC, 2) AS collected,
    ROUND((rd.revenue * 0.35)::NUMERIC, 2) AS estimated_profit,
    ROUND((iv.product_value + mi.material_value)::NUMERIC, 2) AS inventory_value,
    ROUND(iv.product_value::NUMERIC, 2) AS product_inventory,
    ROUND(mi.material_value::NUMERIC, 2) AS material_inventory,
    CASE WHEN rd.revenue > 0 
         THEN ROUND((cd.credit_extended / rd.revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS credit_to_revenue_ratio,
    CASE WHEN rd.revenue > 0 
         THEN ROUND((rd.collected / rd.revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS collection_ratio,
    -- Nuevos campos de salud de inventario
    sh.total_products::INT AS total_products,
    sh.critical_products::INT AS critical_products,
    sh.out_of_stock::INT AS out_of_stock_products,
    sh.low_stock::INT AS low_stock_products,
    mh.total_materials::INT AS total_materials,
    mh.critical_materials::INT AS critical_materials,
    -- Porcentaje de salud: 100% = todo bien, 0% = todo crítico
    CASE WHEN (sh.total_products + mh.total_materials) > 0
         THEN ROUND(
            ((sh.total_products + mh.total_materials - sh.critical_products - mh.critical_materials)::NUMERIC 
             / (sh.total_products + mh.total_materials)::NUMERIC * 100), 1
         )
         ELSE 100 END AS stock_health_pct
FROM months m
JOIN credit_data cd ON m.month_start = cd.month_start
JOIN revenue_data rd ON m.month_start = rd.month_start
CROSS JOIN inventory_data iv
CROSS JOIN material_inventory mi
CROSS JOIN stock_health sh
CROSS JOIN material_health mh
ORDER BY m.month_start;
