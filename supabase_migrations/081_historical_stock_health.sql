-- Reemplazar vista v_business_health_monthly para usar datos HISTÓRICOS
-- de stock_movements y material_movements en lugar de snapshot actual.
-- Esto hace que la línea "Salud Inventario" varíe por mes.
-- Incluye triggers automáticos para tracking futuro + backfill de datos.

-- Indices para mejorar performance de las subconsultas
CREATE INDEX IF NOT EXISTS idx_stock_movements_product_created 
    ON stock_movements(product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_material_movements_material_created 
    ON material_movements(material_id, created_at DESC);

CREATE OR REPLACE VIEW v_business_health_monthly AS
WITH months AS (
    SELECT generate_series(
        DATE_TRUNC('month', NOW()) - INTERVAL '11 months',
        DATE_TRUNC('month', NOW()),
        '1 month'::INTERVAL
    )::DATE AS month_start
),
-- Crédito pendiente acumulado hasta fin de cada mes
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
-- Ingresos y cobros por mes
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
-- Stock histórico de PRODUCTOS: último movimiento antes del fin de cada mes
product_month_stock AS (
    SELECT 
        m.month_start,
        p.id AS product_id,
        p.min_stock,
        CASE WHEN p.cost_price > 0 THEN p.cost_price ELSE p.unit_price END AS price,
        COALESCE(
            (SELECT sm.new_stock 
             FROM stock_movements sm 
             WHERE sm.product_id = p.id 
               AND sm.created_at < (m.month_start + INTERVAL '1 month')
             ORDER BY sm.created_at DESC 
             LIMIT 1),
            -- Sin movimientos registrados: usar stock actual como fallback
            p.stock
        ) AS stock_at_end
    FROM months m
    CROSS JOIN products p
    WHERE p.is_active = TRUE
),
-- Stock histórico de MATERIALES: último movimiento antes del fin de cada mes
material_month_stock AS (
    SELECT 
        m.month_start,
        mt.id AS material_id,
        mt.min_stock,
        CASE 
            WHEN mt.cost_price > 0 THEN mt.cost_price
            WHEN mt.price_per_kg > 0 THEN mt.price_per_kg
            ELSE mt.unit_price
        END AS price,
        COALESCE(
            (SELECT mm.new_stock 
             FROM material_movements mm 
             WHERE mm.material_id = mt.id 
               AND mm.created_at < (m.month_start + INTERVAL '1 month')
             ORDER BY mm.created_at DESC 
             LIMIT 1),
            -- Sin movimientos registrados: usar stock actual como fallback
            mt.stock
        ) AS stock_at_end
    FROM months m
    CROSS JOIN materials mt
    WHERE mt.is_active = TRUE
),
-- Agregar por mes: valor de inventario + salud de productos
product_agg AS (
    SELECT
        month_start,
        COALESCE(SUM(CASE WHEN stock_at_end > 0 THEN stock_at_end * price ELSE 0 END), 0) AS product_value,
        COUNT(*) AS total_products,
        COUNT(*) FILTER (WHERE stock_at_end <= 0 OR stock_at_end <= min_stock) AS critical_products,
        COUNT(*) FILTER (WHERE stock_at_end <= 0) AS out_of_stock,
        COUNT(*) FILTER (WHERE stock_at_end > 0 AND stock_at_end <= min_stock) AS low_stock
    FROM product_month_stock
    GROUP BY month_start
),
-- Agregar por mes: valor de inventario + salud de materiales
material_agg AS (
    SELECT
        month_start,
        COALESCE(SUM(CASE WHEN stock_at_end > 0 THEN stock_at_end * price ELSE 0 END), 0) AS material_value,
        COUNT(*) AS total_materials,
        COUNT(*) FILTER (WHERE stock_at_end <= 0 OR stock_at_end <= min_stock) AS critical_materials
    FROM material_month_stock
    GROUP BY month_start
)
SELECT 
    m.month_start AS month,
    EXTRACT(YEAR FROM m.month_start)::INT AS year,
    EXTRACT(MONTH FROM m.month_start)::INT AS month_num,
    ROUND(cd.credit_extended::NUMERIC, 2) AS credit_extended,
    ROUND(rd.revenue::NUMERIC, 2) AS revenue,
    ROUND(rd.collected::NUMERIC, 2) AS collected,
    ROUND((rd.revenue * 0.35)::NUMERIC, 2) AS estimated_profit,
    ROUND((COALESCE(pa.product_value, 0) + COALESCE(ma.material_value, 0))::NUMERIC, 2) AS inventory_value,
    ROUND(COALESCE(pa.product_value, 0)::NUMERIC, 2) AS product_inventory,
    ROUND(COALESCE(ma.material_value, 0)::NUMERIC, 2) AS material_inventory,
    CASE WHEN rd.revenue > 0 
         THEN ROUND((cd.credit_extended / rd.revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS credit_to_revenue_ratio,
    CASE WHEN rd.revenue > 0 
         THEN ROUND((rd.collected / rd.revenue * 100)::NUMERIC, 1)
         ELSE 0 END AS collection_ratio,
    -- Salud de inventario histórica
    COALESCE(pa.total_products, 0)::INT AS total_products,
    COALESCE(pa.critical_products, 0)::INT AS critical_products,
    COALESCE(pa.out_of_stock, 0)::INT AS out_of_stock_products,
    COALESCE(pa.low_stock, 0)::INT AS low_stock_products,
    COALESCE(ma.total_materials, 0)::INT AS total_materials,
    COALESCE(ma.critical_materials, 0)::INT AS critical_materials,
    -- Porcentaje de salud: 100% = todo saludable, 0% = todo crítico
    CASE WHEN (COALESCE(pa.total_products, 0) + COALESCE(ma.total_materials, 0)) > 0
         THEN ROUND(
            ((COALESCE(pa.total_products, 0) + COALESCE(ma.total_materials, 0) 
              - COALESCE(pa.critical_products, 0) - COALESCE(ma.critical_materials, 0))::NUMERIC 
             / (COALESCE(pa.total_products, 0) + COALESCE(ma.total_materials, 0))::NUMERIC * 100), 1
         )
         ELSE 100 END AS stock_health_pct,
    -- Score: buenos(+1) - críticos(-1) por producto y material
    (
        (COALESCE(pa.total_products, 0) - COALESCE(pa.critical_products, 0))
        - COALESCE(pa.critical_products, 0)
        + (COALESCE(ma.total_materials, 0) - COALESCE(ma.critical_materials, 0))
        - COALESCE(ma.critical_materials, 0)
    )::INT AS stock_health_score
FROM months m
JOIN credit_data cd ON m.month_start = cd.month_start
JOIN revenue_data rd ON m.month_start = rd.month_start
LEFT JOIN product_agg pa ON m.month_start = pa.month_start
LEFT JOIN material_agg ma ON m.month_start = ma.month_start
ORDER BY m.month_start;

-- ============================================================
-- TRIGGERS: Auto-registrar cambios de stock en products/materials
-- ============================================================

CREATE OR REPLACE FUNCTION fn_track_product_stock_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.stock IS DISTINCT FROM NEW.stock THEN
        INSERT INTO stock_movements (product_id, type, quantity, previous_stock, new_stock, reason)
        VALUES (
            NEW.id,
            CASE 
                WHEN NEW.stock > OLD.stock THEN 'incoming'::stock_movement_type
                WHEN NEW.stock < OLD.stock THEN 'outgoing'::stock_movement_type
                ELSE 'adjustment'::stock_movement_type
            END,
            ABS(NEW.stock - OLD.stock),
            OLD.stock,
            NEW.stock,
            'Auto-tracking'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_track_product_stock ON products;
CREATE TRIGGER trg_track_product_stock
    AFTER UPDATE OF stock ON products
    FOR EACH ROW
    EXECUTE FUNCTION fn_track_product_stock_change();

CREATE OR REPLACE FUNCTION fn_track_material_stock_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.stock IS DISTINCT FROM NEW.stock THEN
        INSERT INTO material_movements (material_id, type, quantity, previous_stock, new_stock, reason)
        VALUES (
            NEW.id,
            CASE 
                WHEN NEW.stock > OLD.stock THEN 'incoming'
                WHEN NEW.stock < OLD.stock THEN 'outgoing'
                ELSE 'adjustment'
            END,
            ABS(NEW.stock - OLD.stock),
            OLD.stock,
            NEW.stock,
            'Auto-tracking'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_track_material_stock ON materials;
CREATE TRIGGER trg_track_material_stock
    AFTER UPDATE OF stock ON materials
    FOR EACH ROW
    EXECUTE FUNCTION fn_track_material_stock_change();
