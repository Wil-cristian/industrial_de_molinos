-- =====================================================
-- MÁRGENES DE GANANCIA POR PRODUCTO
-- Industrial de Molinos
-- Fecha: 2 de Enero, 2026
-- =====================================================
-- Este script implementa:
-- 1. Campo cost_price en invoice_items para registrar costo al momento de venta
-- 2. Vista de análisis de márgenes por producto
-- 3. Vista de análisis de márgenes por material
-- 4. Vista de márgenes en facturas/cotizaciones
-- 5. Función para calcular margen de ganancia real
-- =====================================================

-- =====================================================
-- 1. AGREGAR cost_price A INVOICE_ITEMS
-- =====================================================
DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS cost_price DECIMAL(12,2) DEFAULT 0;
    COMMENT ON COLUMN invoice_items.cost_price IS 'Costo de compra/fabricación al momento de la venta';
EXCEPTION WHEN others THEN null;
END $$;

-- También en quotation_items
DO $$ BEGIN
    ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS cost_price DECIMAL(12,2) DEFAULT 0;
    COMMENT ON COLUMN quotation_items.cost_price IS 'Costo de compra/fabricación al momento de cotizar';
EXCEPTION WHEN others THEN null;
END $$;

-- =====================================================
-- 2. VISTA: ANÁLISIS DE MÁRGENES POR MATERIAL
-- =====================================================
-- Muestra precio de compra, precio de venta promedio y margen por material
CREATE OR REPLACE VIEW v_material_profit_analysis AS
SELECT 
    m.id as material_id,
    m.code as material_code,
    m.name as material_name,
    m.category,
    m.unit,
    m.stock as current_stock,
    -- Precios base
    m.cost_price as purchase_price,  -- Precio de compra
    CASE 
        WHEN m.unit = 'KG' THEN m.price_per_kg 
        ELSE m.unit_price 
    END as sale_price,  -- Precio de venta configurado
    -- Margen calculado sobre precio configurado
    CASE 
        WHEN m.cost_price > 0 THEN 
            ROUND(((CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END - m.cost_price) / m.cost_price * 100)::numeric, 2)
        ELSE 0 
    END as configured_margin_percent,
    -- Ganancia por unidad
    CASE 
        WHEN m.unit = 'KG' THEN m.price_per_kg - m.cost_price
        ELSE m.unit_price - m.cost_price 
    END as profit_per_unit,
    -- Valor en stock
    m.stock * m.cost_price as stock_cost_value,
    m.stock * (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END) as stock_sale_value,
    -- Precio promedio de venta real (de facturas)
    COALESCE(sales.avg_sale_price, 0) as avg_actual_sale_price,
    COALESCE(sales.total_qty_sold, 0) as total_qty_sold,
    COALESCE(sales.total_revenue, 0) as total_revenue,
    -- Margen real basado en ventas
    CASE 
        WHEN m.cost_price > 0 AND COALESCE(sales.avg_sale_price, 0) > 0 THEN 
            ROUND(((sales.avg_sale_price - m.cost_price) / m.cost_price * 100)::numeric, 2)
        ELSE NULL 
    END as actual_margin_percent,
    m.is_active,
    m.updated_at
FROM materials m
LEFT JOIN (
    SELECT 
        ii.material_id,
        AVG(ii.unit_price) as avg_sale_price,
        SUM(ii.quantity) as total_qty_sold,
        SUM(ii.total) as total_revenue
    FROM invoice_items ii
    INNER JOIN invoices i ON i.id = ii.invoice_id
    WHERE ii.material_id IS NOT NULL 
      AND i.status::text NOT IN ('cancelled')
    GROUP BY ii.material_id
) sales ON sales.material_id = m.id
WHERE m.is_active = true
ORDER BY m.category, m.name;

-- =====================================================
-- 3. VISTA: ANÁLISIS DE MÁRGENES POR PRODUCTO/RECETA
-- =====================================================
CREATE OR REPLACE VIEW v_product_profit_analysis AS
SELECT 
    p.id as product_id,
    p.code as product_code,
    p.name as product_name,
    p.is_recipe,
    p.unit,
    p.stock as current_stock,
    -- Costos
    p.cost_price as fabrication_cost,  -- Costo de fabricación (suma de materiales)
    p.total_cost as recipe_total_cost, -- Costo total de receta (si aplica)
    p.total_weight,
    -- Precio de venta
    p.unit_price as sale_price,
    -- Margen calculado
    CASE 
        WHEN p.cost_price > 0 THEN 
            ROUND(((p.unit_price - p.cost_price) / p.cost_price * 100)::numeric, 2)
        ELSE 0 
    END as margin_percent,
    -- Ganancia por unidad
    p.unit_price - p.cost_price as profit_per_unit,
    -- Margen bruto (sobre precio venta)
    CASE 
        WHEN p.unit_price > 0 THEN 
            ROUND(((p.unit_price - p.cost_price) / p.unit_price * 100)::numeric, 2)
        ELSE 0 
    END as gross_margin_percent,
    -- Estadísticas de ventas
    COALESCE(sales.total_qty_sold, 0) as total_qty_sold,
    COALESCE(sales.total_revenue, 0) as total_revenue,
    COALESCE(sales.avg_sale_price, 0) as avg_actual_sale_price,
    -- Margen real
    CASE 
        WHEN p.cost_price > 0 AND COALESCE(sales.avg_sale_price, 0) > 0 THEN 
            ROUND(((sales.avg_sale_price - p.cost_price) / p.cost_price * 100)::numeric, 2)
        ELSE NULL 
    END as actual_margin_percent,
    -- Número de componentes (para recetas)
    COALESCE(comp.component_count, 0) as component_count,
    p.is_active,
    p.updated_at
FROM products p
LEFT JOIN (
    SELECT 
        ii.product_id,
        AVG(ii.unit_price) as avg_sale_price,
        SUM(ii.quantity) as total_qty_sold,
        SUM(ii.total) as total_revenue
    FROM invoice_items ii
    INNER JOIN invoices i ON i.id = ii.invoice_id
    WHERE ii.product_id IS NOT NULL 
      AND i.status::text NOT IN ('cancelled')
    GROUP BY ii.product_id
) sales ON sales.product_id = p.id
LEFT JOIN (
    SELECT product_id, COUNT(*) as component_count
    FROM product_components
    GROUP BY product_id
) comp ON comp.product_id = p.id
WHERE p.is_active = true
ORDER BY p.is_recipe DESC, p.name;

-- =====================================================
-- 4. VISTA: MÁRGENES POR FACTURA
-- =====================================================
CREATE OR REPLACE VIEW v_invoice_profit_analysis AS
SELECT 
    i.id as invoice_id,
    i.series || '-' || i.number as invoice_number,
    i.customer_name,
    i.issue_date,
    i.status,
    i.total as invoice_total,
    -- Costo total de items (usando cost_price de items o calculado)
    COALESCE(items.total_cost, 0) as total_cost,
    -- Ganancia bruta
    i.total - COALESCE(items.total_cost, 0) as gross_profit,
    -- Margen bruto
    CASE 
        WHEN i.total > 0 THEN 
            ROUND(((i.total - COALESCE(items.total_cost, 0)) / i.total * 100)::numeric, 2)
        ELSE 0 
    END as gross_margin_percent,
    -- Markup (sobre costo)
    CASE 
        WHEN COALESCE(items.total_cost, 0) > 0 THEN 
            ROUND(((i.total - items.total_cost) / items.total_cost * 100)::numeric, 2)
        ELSE 0 
    END as markup_percent,
    items.item_count,
    i.created_at
FROM invoices i
LEFT JOIN (
    SELECT 
        invoice_id,
        SUM(
            CASE 
                WHEN cost_price > 0 THEN cost_price * quantity
                ELSE subtotal * 0.65  -- Estimación si no hay cost_price (35% margen típico)
            END
        ) as total_cost,
        COUNT(*) as item_count
    FROM invoice_items
    GROUP BY invoice_id
) items ON items.invoice_id = i.id
WHERE i.status::text NOT IN ('cancelled')
ORDER BY i.issue_date DESC;

-- =====================================================
-- 5. VISTA: MÁRGENES POR COTIZACIÓN
-- =====================================================
CREATE OR REPLACE VIEW v_quotation_profit_analysis AS
SELECT 
    q.id as quotation_id,
    q.quotation_number,
    q.customer_name,
    q.issue_date,
    q.status,
    q.total as quotation_total,
    -- Costo total de items
    COALESCE(items.total_cost, 0) as total_cost,
    -- Ganancia proyectada
    q.total - COALESCE(items.total_cost, 0) as projected_profit,
    -- Margen proyectado
    CASE 
        WHEN q.total > 0 THEN 
            ROUND(((q.total - COALESCE(items.total_cost, 0)) / q.total * 100)::numeric, 2)
        ELSE 0 
    END as projected_margin_percent,
    items.item_count,
    q.created_at
FROM quotations q
LEFT JOIN (
    SELECT 
        quotation_id,
        SUM(
            CASE 
                WHEN cost_price > 0 THEN cost_price * quantity
                ELSE total_price * 0.65  -- Estimación
            END
        ) as total_cost,
        COUNT(*) as item_count
    FROM quotation_items
    GROUP BY quotation_id
) items ON items.quotation_id = q.id
ORDER BY q.issue_date DESC;

-- =====================================================
-- 6. VISTA: RESUMEN DE MÁRGENES POR CATEGORÍA
-- =====================================================
CREATE OR REPLACE VIEW v_margin_summary_by_category AS
SELECT 
    'material' as item_type,
    m.category,
    COUNT(*) as item_count,
    -- Promedios
    ROUND(AVG(
        CASE WHEN m.cost_price > 0 THEN 
            ((CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END) - m.cost_price) / m.cost_price * 100
        ELSE 0 END
    )::numeric, 2) as avg_margin_percent,
    -- Totales de valor
    SUM(m.stock * m.cost_price) as total_stock_cost,
    SUM(m.stock * (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END)) as total_stock_value,
    -- Ganancia potencial del stock
    SUM(m.stock * (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END)) - 
    SUM(m.stock * m.cost_price) as potential_profit
FROM materials m
WHERE m.is_active = true
GROUP BY m.category

UNION ALL

SELECT 
    'product' as item_type,
    COALESCE(c.name, 'Sin categoría') as category,
    COUNT(*) as item_count,
    ROUND(AVG(
        CASE WHEN p.cost_price > 0 THEN 
            (p.unit_price - p.cost_price) / p.cost_price * 100
        ELSE 0 END
    )::numeric, 2) as avg_margin_percent,
    SUM(p.stock * p.cost_price) as total_stock_cost,
    SUM(p.stock * p.unit_price) as total_stock_value,
    SUM(p.stock * p.unit_price) - SUM(p.stock * p.cost_price) as potential_profit
FROM products p
LEFT JOIN categories c ON c.id = p.category_id::uuid
WHERE p.is_active = true
GROUP BY COALESCE(c.name, 'Sin categoría')

ORDER BY item_type, category;

-- =====================================================
-- 7. FUNCIÓN: CALCULAR MARGEN DE GANANCIA
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_profit_margin(
    p_cost DECIMAL,
    p_sale_price DECIMAL
)
RETURNS TABLE (
    margin_percent DECIMAL,
    gross_margin_percent DECIMAL,
    profit_amount DECIMAL,
    markup_percent DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        -- Margen sobre costo (markup)
        CASE WHEN p_cost > 0 THEN 
            ROUND(((p_sale_price - p_cost) / p_cost * 100)::numeric, 2)
        ELSE 0::numeric END,
        -- Margen bruto sobre precio de venta
        CASE WHEN p_sale_price > 0 THEN 
            ROUND(((p_sale_price - p_cost) / p_sale_price * 100)::numeric, 2)
        ELSE 0::numeric END,
        -- Ganancia absoluta
        (p_sale_price - p_cost)::numeric,
        -- Markup (sinónimo del margen sobre costo)
        CASE WHEN p_cost > 0 THEN 
            ROUND(((p_sale_price - p_cost) / p_cost * 100)::numeric, 2)
        ELSE 0::numeric END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. FUNCIÓN: OBTENER ANÁLISIS DE INVENTARIO CON MÁRGENES
-- =====================================================
CREATE OR REPLACE FUNCTION get_inventory_with_margins(
    p_category VARCHAR DEFAULT NULL,
    p_low_stock_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    id UUID,
    code VARCHAR,
    name VARCHAR,
    item_type VARCHAR,
    category VARCHAR,
    unit VARCHAR,
    current_stock DECIMAL,
    min_stock DECIMAL,
    cost_price DECIMAL,
    sale_price DECIMAL,
    margin_percent DECIMAL,
    profit_per_unit DECIMAL,
    stock_cost_value DECIMAL,
    stock_sale_value DECIMAL,
    potential_profit DECIMAL,
    is_low_stock BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    -- Materiales
    SELECT 
        m.id,
        m.code::VARCHAR,
        m.name::VARCHAR,
        'material'::VARCHAR as item_type,
        m.category::VARCHAR,
        m.unit::VARCHAR,
        m.stock,
        m.min_stock,
        m.cost_price,
        CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END as sale_price,
        CASE WHEN m.cost_price > 0 THEN 
            ROUND(((CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END - m.cost_price) / m.cost_price * 100)::numeric, 2)
        ELSE 0::numeric END as margin_percent,
        (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END - m.cost_price) as profit_per_unit,
        m.stock * m.cost_price as stock_cost_value,
        m.stock * (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END) as stock_sale_value,
        m.stock * (CASE WHEN m.unit = 'KG' THEN m.price_per_kg ELSE m.unit_price END - m.cost_price) as potential_profit,
        m.stock <= m.min_stock as is_low_stock
    FROM materials m
    WHERE m.is_active = true
      AND (p_category IS NULL OR m.category = p_category)
      AND (NOT p_low_stock_only OR m.stock <= m.min_stock)
    
    UNION ALL
    
    -- Productos
    SELECT 
        p.id,
        p.code::VARCHAR,
        p.name::VARCHAR,
        CASE WHEN p.is_recipe THEN 'recipe' ELSE 'product' END::VARCHAR as item_type,
        COALESCE(c.name, 'general')::VARCHAR as category,
        p.unit::VARCHAR,
        p.stock,
        p.min_stock,
        p.cost_price,
        p.unit_price as sale_price,
        CASE WHEN p.cost_price > 0 THEN 
            ROUND(((p.unit_price - p.cost_price) / p.cost_price * 100)::numeric, 2)
        ELSE 0::numeric END as margin_percent,
        (p.unit_price - p.cost_price) as profit_per_unit,
        p.stock * p.cost_price as stock_cost_value,
        p.stock * p.unit_price as stock_sale_value,
        p.stock * (p.unit_price - p.cost_price) as potential_profit,
        p.stock <= p.min_stock as is_low_stock
    FROM products p
    LEFT JOIN categories c ON c.id = p.category_id::uuid
    WHERE p.is_active = true
      AND (p_category IS NULL OR COALESCE(c.name, 'general') = p_category)
      AND (NOT p_low_stock_only OR p.stock <= p.min_stock)
    
    ORDER BY item_type, category, name;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 9. TRIGGER: AUTO-RELLENAR cost_price EN invoice_items
-- =====================================================
CREATE OR REPLACE FUNCTION auto_fill_item_cost_price()
RETURNS TRIGGER AS $$
BEGIN
    -- Si no se proporcionó cost_price, buscarlo del material o producto
    IF NEW.cost_price IS NULL OR NEW.cost_price = 0 THEN
        IF NEW.material_id IS NOT NULL THEN
            SELECT cost_price INTO NEW.cost_price
            FROM materials
            WHERE id = NEW.material_id;
        ELSIF NEW.product_id IS NOT NULL THEN
            SELECT cost_price INTO NEW.cost_price
            FROM products
            WHERE id = NEW.product_id;
        END IF;
    END IF;
    
    -- Si aún es NULL, poner 0
    NEW.cost_price := COALESCE(NEW.cost_price, 0);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para invoice_items
DROP TRIGGER IF EXISTS trg_auto_fill_invoice_item_cost ON invoice_items;
CREATE TRIGGER trg_auto_fill_invoice_item_cost
    BEFORE INSERT ON invoice_items
    FOR EACH ROW
    EXECUTE FUNCTION auto_fill_item_cost_price();

-- Trigger para quotation_items
DROP TRIGGER IF EXISTS trg_auto_fill_quotation_item_cost ON quotation_items;
CREATE TRIGGER trg_auto_fill_quotation_item_cost
    BEFORE INSERT ON quotation_items
    FOR EACH ROW
    EXECUTE FUNCTION auto_fill_item_cost_price();

-- =====================================================
-- 10. ACTUALIZAR ITEMS EXISTENTES CON cost_price
-- =====================================================
-- Actualizar invoice_items existentes
UPDATE invoice_items ii
SET cost_price = COALESCE(m.cost_price, p.cost_price, 0)
FROM (SELECT id, material_id, product_id FROM invoice_items WHERE cost_price IS NULL OR cost_price = 0) items
LEFT JOIN materials m ON m.id = items.material_id
LEFT JOIN products p ON p.id = items.product_id
WHERE ii.id = items.id;

-- Actualizar quotation_items existentes
UPDATE quotation_items qi
SET cost_price = COALESCE(m.cost_price, p.cost_price, 0)
FROM (SELECT id, material_id, product_id FROM quotation_items WHERE cost_price IS NULL OR cost_price = 0) items
LEFT JOIN materials m ON m.id = items.material_id
LEFT JOIN products p ON p.id = items.product_id
WHERE qi.id = items.id;

-- =====================================================
-- 11. ÍNDICES PARA MEJOR RENDIMIENTO
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_materials_cost_price ON materials(cost_price);
CREATE INDEX IF NOT EXISTS idx_products_cost_price ON products(cost_price);
CREATE INDEX IF NOT EXISTS idx_invoice_items_cost_price ON invoice_items(cost_price);
CREATE INDEX IF NOT EXISTS idx_quotation_items_cost_price ON quotation_items(cost_price);

-- =====================================================
-- COMENTARIOS
-- =====================================================
COMMENT ON VIEW v_material_profit_analysis IS 'Análisis de márgenes de ganancia por material con estadísticas de ventas';
COMMENT ON VIEW v_product_profit_analysis IS 'Análisis de márgenes de ganancia por producto/receta';
COMMENT ON VIEW v_invoice_profit_analysis IS 'Análisis de rentabilidad por factura';
COMMENT ON VIEW v_quotation_profit_analysis IS 'Análisis de rentabilidad proyectada por cotización';
COMMENT ON VIEW v_margin_summary_by_category IS 'Resumen de márgenes agrupado por categoría';
COMMENT ON FUNCTION calculate_profit_margin IS 'Calcula métricas de margen de ganancia';
COMMENT ON FUNCTION get_inventory_with_margins IS 'Obtiene inventario con análisis de márgenes';

-- Mensaje de éxito (ejecutar como DO block)
DO $$ BEGIN
    RAISE NOTICE '✅ Migración 023_profit_margins completada exitosamente';
END $$;
