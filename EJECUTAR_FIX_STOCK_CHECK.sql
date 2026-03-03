-- =====================================================
-- FIX: check_quotation_stock - Agregar material_id al resultado
-- =====================================================
-- PROBLEMA: La función no retornaba el material_id, necesario
-- para crear órdenes de compra de materiales faltantes.
--
-- SOLUCIÓN: Agregar material_id UUID al RETURNS TABLE
-- =====================================================

DROP FUNCTION IF EXISTS check_quotation_stock(UUID);

CREATE OR REPLACE FUNCTION check_quotation_stock(p_quotation_id UUID)
RETURNS TABLE (
    material_id UUID,
    material_name VARCHAR,
    material_code VARCHAR,
    required_qty DECIMAL,
    available_stock DECIMAL,
    unit VARCHAR,
    has_stock BOOLEAN,
    shortage DECIMAL,
    source_items TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH all_materials AS (
        -- Materiales directos en la cotización
        SELECT 
            m.id as mat_id,
            m.name::VARCHAR as mat_name,
            m.code::VARCHAR as mat_code,
            qi.quantity as qty_needed,
            m.stock as current_stock,
            COALESCE(m.unit, 'KG')::VARCHAR as mat_unit,
            qi.name as source
        FROM quotation_items qi
        JOIN materials m ON m.id = qi.material_id
        WHERE qi.quotation_id = p_quotation_id
        AND qi.material_id IS NOT NULL
        
        UNION ALL
        
        -- Componentes de recetas: piezas × kg/pieza × cantidad pedida
        SELECT 
            m.id,
            m.name::VARCHAR,
            m.code::VARCHAR,
            pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * qi.quantity,
            m.stock,
            COALESCE(m.unit, pc.unit, 'KG')::VARCHAR,
            p.name || ' (' || pc.name || ')'
        FROM quotation_items qi
        JOIN products p ON p.id = qi.product_id AND p.is_recipe = true
        JOIN product_components pc ON pc.product_id = qi.product_id
        JOIN materials m ON m.id = pc.material_id
        WHERE qi.quotation_id = p_quotation_id
        AND qi.product_id IS NOT NULL
    ),
    aggregated AS (
        SELECT 
            mat_id,
            MAX(mat_name)::VARCHAR as mat_name,
            MAX(mat_code)::VARCHAR as mat_code,
            SUM(qty_needed) as total_needed,
            MAX(current_stock) as current_stock,
            MAX(mat_unit)::VARCHAR as mat_unit,
            STRING_AGG(DISTINCT source, ', ') as sources
        FROM all_materials
        GROUP BY mat_id
    )
    SELECT 
        a.mat_id,
        a.mat_name,
        a.mat_code,
        a.total_needed::DECIMAL,
        a.current_stock::DECIMAL,
        a.mat_unit,
        (a.current_stock >= a.total_needed) as has_stock,
        GREATEST(0, a.total_needed - a.current_stock)::DECIMAL as shortage,
        a.sources::TEXT
    FROM aggregated a
    ORDER BY 
        (a.current_stock >= a.total_needed) ASC,
        a.mat_name;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION check_quotation_stock TO anon, authenticated;

-- Verificar
DO $$
BEGIN
    RAISE NOTICE '✅ check_quotation_stock ahora retorna material_id';
    RAISE NOTICE '   → Se puede usar para crear órdenes de compra de faltantes';
END $$;
