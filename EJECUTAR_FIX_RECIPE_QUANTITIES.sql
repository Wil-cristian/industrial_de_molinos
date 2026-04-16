-- =====================================================
-- FIX v2: Cantidades de materiales en recetas
-- =====================================================
-- PROBLEMA REAL: calculated_weight guarda PESO POR UNIDAD (no total)
--   Ej: bola → quantity=1000 (piezas), calculated_weight=1.0 (kg/unidad)
--       TUBO → quantity=1 (pieza),     calculated_weight=1026.294 (kg/unidad)
--
-- FÓRMULA CORRECTA: quantity × COALESCE(NULLIF(calculated_weight, 0), 1)
--   → piezas × peso_por_pieza = peso total en KG
--   → Si calculated_weight es NULL/0, asume 1 kg/pieza (datos legacy)
--
-- FÓRMULA ANTERIOR (INCORRECTA): COALESCE(NULLIF(calculated_weight, 0), quantity)
--   → Para bola: devolvía 1.0 en vez de 1000
-- =====================================================

-- ═══════════════════════════════════════════════════════════
-- 1. FIX: check_recipe_stock - Mostrar cantidad real requerida
-- ═══════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS check_recipe_stock(UUID, INT);

CREATE OR REPLACE FUNCTION check_recipe_stock(p_product_id UUID, p_quantity INT DEFAULT 1)
RETURNS TABLE (
    component_name VARCHAR,
    material_code VARCHAR,
    required_qty DECIMAL,
    available_stock DECIMAL,
    unit VARCHAR,
    has_stock BOOLEAN,
    shortage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pc.name::VARCHAR,
        m.code::VARCHAR,
        -- quantity = piezas, calculated_weight = kg por pieza
        -- Total KG = piezas × kg/pieza × cantidad pedida
        (pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * p_quantity)::DECIMAL as required,
        COALESCE(m.stock, 0)::DECIMAL,
        pc.unit::VARCHAR,
        COALESCE(m.stock, 0) >= (pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * p_quantity),
        GREATEST(0, (pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * p_quantity) - COALESCE(m.stock, 0))::DECIMAL
    FROM product_components pc
    LEFT JOIN materials m ON m.id = pc.material_id
    WHERE pc.product_id = p_product_id
    ORDER BY pc.sort_order;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION check_recipe_stock TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 2. FIX: approve_quotation_with_materials - Descontar peso real
-- ═══════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS approve_quotation_with_materials(UUID, VARCHAR, BOOLEAN);

CREATE OR REPLACE FUNCTION approve_quotation_with_materials(
    p_quotation_id UUID,
    p_series VARCHAR DEFAULT 'FAC',
    p_deduct_materials BOOLEAN DEFAULT true
) RETURNS JSON AS $$
DECLARE
    v_quotation RECORD;
    v_invoice_id UUID;
    v_invoice_number VARCHAR;
    v_deduction_results JSONB := '[]'::JSONB;
    v_fail_name VARCHAR;
    v_fail_stock DECIMAL;
    v_fail_required DECIMAL;
    v_reference VARCHAR;
BEGIN
    SELECT * INTO v_quotation FROM quotations WHERE id = p_quotation_id;
    
    IF v_quotation IS NULL THEN
        RAISE EXCEPTION 'Cotización no encontrada: %', p_quotation_id;
    END IF;
    
    IF v_quotation.status = 'Aprobada' THEN
        RAISE EXCEPTION 'La cotización ya fue aprobada';
    END IF;
    
    v_reference := 'COT-' || v_quotation.number;
    
    -- Generar número de recibo/factura
    SELECT LPAD((COALESCE(MAX(CAST(NULLIF(number, '') AS INTEGER)), 0) + 1)::TEXT, 5, '0') 
    INTO v_invoice_number
    FROM invoices WHERE series = p_series;
    
    -- ═══════════════════════════════════════
    -- DESCUENTO BULK DE INVENTARIO
    -- ═══════════════════════════════════════
    IF p_deduct_materials THEN
        
        -- PASO 1: Validar stock de materiales directos + recetas
        WITH all_material_deductions AS (
            -- Materiales directos en quotation_items
            SELECT qi.material_id, qi.quantity
            FROM quotation_items qi
            WHERE qi.quotation_id = p_quotation_id
            AND qi.material_id IS NOT NULL
            
            UNION ALL
            
            -- Componentes de recetas: piezas × kg/pieza × cantidad pedida
            SELECT pc.material_id, 
                   pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * qi.quantity
            FROM quotation_items qi
            JOIN products p ON p.id = qi.product_id AND p.is_recipe = true
            JOIN product_components pc ON pc.product_id = qi.product_id
            WHERE qi.quotation_id = p_quotation_id
            AND qi.product_id IS NOT NULL
        ),
        aggregated AS (
            SELECT material_id, SUM(quantity) as total_qty
            FROM all_material_deductions
            GROUP BY material_id
        )
        SELECT m.name, m.stock, a.total_qty
        INTO v_fail_name, v_fail_stock, v_fail_required
        FROM aggregated a
        JOIN materials m ON m.id = a.material_id
        WHERE m.stock < a.total_qty
        LIMIT 1;
        
        IF v_fail_name IS NOT NULL THEN
            RAISE EXCEPTION 'Stock insuficiente de %: disponible=%, requerido=%',
                v_fail_name, v_fail_stock, v_fail_required;
        END IF;
        
        -- PASO 2: Validar stock de productos simples (no-receta)
        SELECT p.name, p.stock, qi.quantity
        INTO v_fail_name, v_fail_stock, v_fail_required
        FROM quotation_items qi
        JOIN products p ON p.id = qi.product_id 
            AND (p.is_recipe IS NULL OR p.is_recipe = false)
        WHERE qi.quotation_id = p_quotation_id
        AND qi.product_id IS NOT NULL
        AND p.stock < qi.quantity
        LIMIT 1;
        
        IF v_fail_name IS NOT NULL THEN
            RAISE EXCEPTION 'Stock insuficiente de %: disponible=%, requerido=%',
                v_fail_name, v_fail_stock, v_fail_required;
        END IF;
        
        -- PASO 3: Bulk INSERT movimientos de materiales
        WITH all_material_deductions AS (
            SELECT qi.material_id, qi.quantity, qi.name as item_name
            FROM quotation_items qi
            WHERE qi.quotation_id = p_quotation_id AND qi.material_id IS NOT NULL
            
            UNION ALL
            
            SELECT pc.material_id, 
                   pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * qi.quantity,
                   'Receta: ' || p.name || ' - ' || pc.name
            FROM quotation_items qi
            JOIN products p ON p.id = qi.product_id AND p.is_recipe = true
            JOIN product_components pc ON pc.product_id = qi.product_id
            WHERE qi.quotation_id = p_quotation_id AND qi.product_id IS NOT NULL
        )
        INSERT INTO material_movements (
            material_id, type, quantity, previous_stock, new_stock,
            reason, reference, quotation_id
        )
        SELECT 
            d.material_id, 'outgoing', d.quantity,
            m.stock, m.stock - d.quantity,
            d.item_name, v_reference, p_quotation_id
        FROM all_material_deductions d
        JOIN materials m ON m.id = d.material_id;
        
        -- PASO 4: Bulk UPDATE stock de materiales (agregado)
        WITH all_material_deductions AS (
            SELECT qi.material_id, qi.quantity
            FROM quotation_items qi
            WHERE qi.quotation_id = p_quotation_id AND qi.material_id IS NOT NULL
            
            UNION ALL
            
            SELECT pc.material_id, 
                   pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * qi.quantity
            FROM quotation_items qi
            JOIN products p ON p.id = qi.product_id AND p.is_recipe = true
            JOIN product_components pc ON pc.product_id = qi.product_id
            WHERE qi.quotation_id = p_quotation_id AND qi.product_id IS NOT NULL
        ),
        aggregated AS (
            SELECT material_id, SUM(quantity) as total_qty
            FROM all_material_deductions
            GROUP BY material_id
        )
        UPDATE materials 
        SET stock = materials.stock - a.total_qty, updated_at = NOW()
        FROM aggregated a
        WHERE materials.id = a.material_id;
        
        -- PASO 5: Bulk UPDATE stock de productos simples (no-receta)
        UPDATE products 
        SET stock = products.stock - qi.quantity, updated_at = NOW()
        FROM quotation_items qi
        WHERE qi.quotation_id = p_quotation_id
        AND qi.product_id IS NOT NULL
        AND products.id = qi.product_id
        AND (products.is_recipe IS NULL OR products.is_recipe = false);
        
        -- Construir JSON resumen de deducciones
        WITH all_material_deductions AS (
            SELECT qi.material_id, qi.quantity, qi.name as item_name, 'material' as dtype
            FROM quotation_items qi
            WHERE qi.quotation_id = p_quotation_id AND qi.material_id IS NOT NULL
            
            UNION ALL
            
            SELECT pc.material_id, 
                   pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * qi.quantity,
                   'Receta: ' || p.name || ' - ' || pc.name, 'recipe'
            FROM quotation_items qi
            JOIN products p ON p.id = qi.product_id AND p.is_recipe = true
            JOIN product_components pc ON pc.product_id = qi.product_id
            WHERE qi.quotation_id = p_quotation_id AND qi.product_id IS NOT NULL
        )
        SELECT COALESCE(jsonb_agg(jsonb_build_object(
            'success', true, 'type', d.dtype,
            'name', d.item_name, 'quantity', d.quantity
        )), '[]'::jsonb)
        INTO v_deduction_results
        FROM all_material_deductions d;
    END IF;
    
    -- ═══════════════════════════════════════
    -- CREAR RECIBO/FACTURA
    -- ═══════════════════════════════════════
    INSERT INTO invoices (
        type, series, number,
        customer_id, customer_name, customer_document,
        issue_date, due_date,
        subtotal, tax_rate, tax_amount, discount, total,
        paid_amount, status, quotation_id, notes
    ) VALUES (
        'invoice', p_series, v_invoice_number,
        v_quotation.customer_id, v_quotation.customer_name, v_quotation.customer_document,
        CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days',
        v_quotation.subtotal, v_quotation.profit_margin, v_quotation.profit_amount, 0, v_quotation.total,
        0, 'issued', p_quotation_id, v_quotation.notes
    ) RETURNING id INTO v_invoice_id;
    
    -- Copiar items de cotización a factura
    INSERT INTO invoice_items (
        invoice_id, product_id, product_code, product_name, description, 
        quantity, unit, unit_price, discount, subtotal, tax_amount, total, material_id
    )
    SELECT 
        v_invoice_id, product_id, material_name, name, description, 
        quantity, 'UND', unit_price, 0, unit_price * quantity, 0, unit_price * quantity, material_id
    FROM quotation_items WHERE quotation_id = p_quotation_id;
    
    -- Actualizar estado de cotización
    UPDATE quotations SET status = 'Aprobada', updated_at = NOW()
    WHERE id = p_quotation_id;
    
    RETURN json_build_object(
        'success', true,
        'invoice_id', v_invoice_id,
        'invoice_number', p_series || '-' || v_invoice_number,
        'deductions', v_deduction_results,
        'items_processed', (SELECT COUNT(*) FROM quotation_items WHERE quotation_id = p_quotation_id)
    );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION approve_quotation_with_materials TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 3. FIX: deduct_inventory_for_invoice - Facturas directas
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION deduct_inventory_for_invoice(p_invoice_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_invoice RECORD;
    v_results JSONB;
    v_fail_name VARCHAR;
    v_fail_stock DECIMAL;
    v_fail_required DECIMAL;
    v_reference VARCHAR;
BEGIN
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    
    IF v_invoice IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Factura no encontrada');
    END IF;
    
    v_reference := v_invoice.series || '-' || v_invoice.number;
    
    -- PASO 1: Validar stock de materiales (agregado)
    WITH all_material_deductions AS (
        -- Materiales directos
        SELECT ii.material_id, ii.quantity
        FROM invoice_items ii
        WHERE ii.invoice_id = p_invoice_id AND ii.material_id IS NOT NULL
        
        UNION ALL
        
        -- Componentes de recetas: piezas × kg/pieza × cantidad pedida
        SELECT pc.material_id, 
               pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * ii.quantity
        FROM invoice_items ii
        JOIN products p ON p.id = ii.product_id AND p.is_recipe = true
        JOIN product_components pc ON pc.product_id = ii.product_id
        WHERE ii.invoice_id = p_invoice_id AND ii.product_id IS NOT NULL
    ),
    aggregated AS (
        SELECT material_id, SUM(quantity) as total_qty
        FROM all_material_deductions
        GROUP BY material_id
    )
    SELECT m.name, m.stock, a.total_qty
    INTO v_fail_name, v_fail_stock, v_fail_required
    FROM aggregated a
    JOIN materials m ON m.id = a.material_id
    WHERE m.stock < a.total_qty
    LIMIT 1;
    
    IF v_fail_name IS NOT NULL THEN
        RAISE EXCEPTION 'Error descontando inventario: Stock insuficiente de %: disponible=%, requerido=%',
            v_fail_name, v_fail_stock, v_fail_required;
    END IF;
    
    -- PASO 2: Validar stock de productos simples
    SELECT p.name, p.stock, ii.quantity
    INTO v_fail_name, v_fail_stock, v_fail_required
    FROM invoice_items ii
    JOIN products p ON p.id = ii.product_id 
        AND (p.is_recipe IS NULL OR p.is_recipe = false)
    WHERE ii.invoice_id = p_invoice_id
    AND ii.product_id IS NOT NULL
    AND p.stock < ii.quantity
    LIMIT 1;
    
    IF v_fail_name IS NOT NULL THEN
        RAISE EXCEPTION 'Error descontando inventario: Stock insuficiente de %: disponible=%, requerido=%',
            v_fail_name, v_fail_stock, v_fail_required;
    END IF;
    
    -- PASO 3: Bulk INSERT movimientos para materiales
    WITH all_material_deductions AS (
        SELECT ii.material_id, ii.quantity, ii.product_name as item_name
        FROM invoice_items ii
        WHERE ii.invoice_id = p_invoice_id AND ii.material_id IS NOT NULL
        
        UNION ALL
        
        SELECT pc.material_id, 
               pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * ii.quantity,
               'Receta: ' || p.name || ' - ' || pc.name
        FROM invoice_items ii
        JOIN products p ON p.id = ii.product_id AND p.is_recipe = true
        JOIN product_components pc ON pc.product_id = ii.product_id
        WHERE ii.invoice_id = p_invoice_id AND ii.product_id IS NOT NULL
    )
    INSERT INTO material_movements (
        material_id, type, quantity, previous_stock, new_stock,
        reason, reference, invoice_id
    )
    SELECT 
        d.material_id, 'outgoing', d.quantity,
        m.stock, m.stock - d.quantity,
        d.item_name, v_reference, p_invoice_id
    FROM all_material_deductions d
    JOIN materials m ON m.id = d.material_id;
    
    -- PASO 4: Bulk UPDATE materiales (agregado)
    WITH all_material_deductions AS (
        SELECT ii.material_id, ii.quantity
        FROM invoice_items ii
        WHERE ii.invoice_id = p_invoice_id AND ii.material_id IS NOT NULL
        
        UNION ALL
        
        SELECT pc.material_id, 
               pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * ii.quantity
        FROM invoice_items ii
        JOIN products p ON p.id = ii.product_id AND p.is_recipe = true
        JOIN product_components pc ON pc.product_id = ii.product_id
        WHERE ii.invoice_id = p_invoice_id AND ii.product_id IS NOT NULL
    ),
    aggregated AS (
        SELECT material_id, SUM(quantity) as total_qty
        FROM all_material_deductions
        GROUP BY material_id
    )
    UPDATE materials 
    SET stock = materials.stock - a.total_qty, updated_at = NOW()
    FROM aggregated a
    WHERE materials.id = a.material_id;
    
    -- PASO 5: Bulk UPDATE productos simples
    UPDATE products 
    SET stock = products.stock - ii.quantity, updated_at = NOW()
    FROM invoice_items ii
    WHERE ii.invoice_id = p_invoice_id
    AND ii.product_id IS NOT NULL
    AND products.id = ii.product_id
    AND (products.is_recipe IS NULL OR products.is_recipe = false);
    
    -- Construir resultados
    WITH all_deductions AS (
        SELECT ii.material_id, ii.product_id, ii.quantity, ii.product_name, 'material' as dtype
        FROM invoice_items ii
        WHERE ii.invoice_id = p_invoice_id AND ii.material_id IS NOT NULL
        
        UNION ALL
        
        SELECT pc.material_id, ii.product_id, 
               pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) * ii.quantity,
               'Receta: ' || p.name || ' - ' || pc.name, 'recipe'
        FROM invoice_items ii
        JOIN products p ON p.id = ii.product_id AND p.is_recipe = true
        JOIN product_components pc ON pc.product_id = ii.product_id
        WHERE ii.invoice_id = p_invoice_id AND ii.product_id IS NOT NULL
        
        UNION ALL
        
        SELECT NULL::uuid, ii.product_id, ii.quantity, ii.product_name, 'product'
        FROM invoice_items ii
        JOIN products p ON p.id = ii.product_id 
            AND (p.is_recipe IS NULL OR p.is_recipe = false)
        WHERE ii.invoice_id = p_invoice_id AND ii.product_id IS NOT NULL
    )
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'success', true, 'type', d.dtype,
        'name', d.product_name, 'quantity', d.quantity
    )), '[]'::jsonb)
    INTO v_results
    FROM all_deductions d;
    
    RETURN jsonb_build_object('success', true, 'deductions', v_results);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION deduct_inventory_for_invoice TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 4. NUEVO: check_quotation_stock - Verificación consolidada
--    de TODOS los materiales de una cotización (múltiples recetas)
--    Los materiales compartidos se agregan correctamente
-- ═══════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS check_quotation_stock(UUID);

CREATE OR REPLACE FUNCTION check_quotation_stock(p_quotation_id UUID)
RETURNS TABLE (
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
        (a.current_stock >= a.total_needed) ASC, -- Insuficiente primero
        a.mat_name;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION check_quotation_stock TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 5. NUEVO: get_recipe_live_pricing - Precios EN VIVO desde inventario
--    Consulta los precios ACTUALES de cada material para recalcular
--    el costo y precio de venta de una receta en tiempo real
-- ═══════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS get_recipe_live_pricing(UUID);

CREATE OR REPLACE FUNCTION get_recipe_live_pricing(p_product_id UUID)
RETURNS JSON AS $$
DECLARE
    v_product RECORD;
    v_total_weight DECIMAL := 0;
    v_total_cost DECIMAL := 0;
    v_total_sale DECIMAL := 0;
    v_components JSONB := '[]'::JSONB;
BEGIN
    -- Verificar que es una receta
    SELECT * INTO v_product FROM products WHERE id = p_product_id;
    IF v_product IS NULL OR v_product.is_recipe IS NOT TRUE THEN
        RETURN json_build_object(
            'success', false, 
            'error', 'Producto no es una receta'
        );
    END IF;
    
    -- Calcular costos EN VIVO desde materiales del inventario
    -- quantity = piezas, calculated_weight = kg/pieza
    -- weight_total = piezas × kg/pieza
    -- cost_total = weight_total × material.cost_price (precio COMPRA actual)
    -- sale_total = weight_total × material.price_per_kg (precio VENTA actual)
    SELECT 
        COALESCE(SUM(
            pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1)
        ), 0),
        COALESCE(SUM(
            pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) 
            * COALESCE(NULLIF(m.cost_price, 0), m.price_per_kg, 0)
        ), 0),
        COALESCE(SUM(
            pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) 
            * COALESCE(NULLIF(m.price_per_kg, 0), m.cost_price, 0)
        ), 0)
    INTO v_total_weight, v_total_cost, v_total_sale
    FROM product_components pc
    LEFT JOIN materials m ON m.id = pc.material_id
    WHERE pc.product_id = p_product_id;
    
    -- Construir detalle de componentes con precios actuales
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'name', pc.name,
        'material_id', pc.material_id,
        'material_name', m.name,
        'quantity', pc.quantity,
        'calculated_weight', pc.calculated_weight,
        'weight_total', pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1),
        'unit', COALESCE(pc.unit, 'KG'),
        'cost_per_kg', COALESCE(NULLIF(m.cost_price, 0), m.price_per_kg, 0),
        'sale_per_kg', COALESCE(NULLIF(m.price_per_kg, 0), m.cost_price, 0),
        'cost_total', pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1) 
                      * COALESCE(NULLIF(m.cost_price, 0), m.price_per_kg, 0),
        'sale_total', pc.quantity * COALESCE(NULLIF(pc.calculated_weight, 0), 1)
                      * COALESCE(NULLIF(m.price_per_kg, 0), m.cost_price, 0),
        'stock', COALESCE(m.stock, 0)
    ) ORDER BY pc.sort_order), '[]'::jsonb)
    INTO v_components
    FROM product_components pc
    LEFT JOIN materials m ON m.id = pc.material_id
    WHERE pc.product_id = p_product_id;
    
    -- También actualizar el producto con precios actuales
    UPDATE products 
    SET cost_price = v_total_cost,
        total_cost = v_total_cost,
        unit_price = v_total_sale,
        total_weight = v_total_weight,
        updated_at = NOW()
    WHERE id = p_product_id;
    
    RETURN json_build_object(
        'success', true,
        'product_id', p_product_id,
        'product_name', v_product.name,
        'total_weight', v_total_weight,
        'total_cost', v_total_cost,     -- Costo COMPRA total (live)
        'total_sale', v_total_sale,     -- Precio VENTA total (live)
        'profit', v_total_sale - v_total_cost,
        'profit_margin', CASE WHEN v_total_cost > 0 
            THEN ((v_total_sale - v_total_cost) / v_total_cost * 100)
            ELSE 0 END,
        'cost_per_kg', CASE WHEN v_total_weight > 0 
            THEN v_total_cost / v_total_weight ELSE 0 END,
        'sale_per_kg', CASE WHEN v_total_weight > 0 
            THEN v_total_sale / v_total_weight ELSE 0 END,
        'components', v_components,
        -- Precios anteriores (para comparar)
        'previous_cost', v_product.cost_price,
        'previous_price', v_product.unit_price
    );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION get_recipe_live_pricing TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 6. Agregar 'Anulada' al enum de cotizaciones (si no existe)
-- ═══════════════════════════════════════════════════════════
DO $$
BEGIN
    ALTER TYPE quotation_status ADD VALUE IF NOT EXISTS 'Anulada';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'quotation_status ya tiene Anulada o no usa enum';
END $$;

-- ═══════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════
DO $$
BEGIN
    RAISE NOTICE '════════════════════════════════════════════';
    RAISE NOTICE '  ✅ FIX v2 APLICADO CORRECTAMENTE';
    RAISE NOTICE '════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '  FÓRMULA: quantity × COALESCE(calculated_weight, 1)';
    RAISE NOTICE '    → piezas × peso_por_pieza = peso total KG';
    RAISE NOTICE '';
    RAISE NOTICE '  Ejemplo bola:';
    RAISE NOTICE '    quantity=1000, calculated_weight=1.0';
    RAISE NOTICE '    → 1000 × 1.0 = 1000 KG ✓';
    RAISE NOTICE '';
    RAISE NOTICE '  Ejemplo TUBO:';
    RAISE NOTICE '    quantity=1, calculated_weight=1026.294';
    RAISE NOTICE '    → 1 × 1026.294 = 1026.294 KG ✓';
    RAISE NOTICE '';
    RAISE NOTICE '  Funciones actualizadas:';
    RAISE NOTICE '    1. check_recipe_stock (selector de productos)';
    RAISE NOTICE '    2. approve_quotation_with_materials (cotización→factura)';
    RAISE NOTICE '    3. deduct_inventory_for_invoice (factura directa)';
    RAISE NOTICE '    4. check_quotation_stock (verificación consolidada)';
    RAISE NOTICE '    5. get_recipe_live_pricing (precios EN VIVO)';
    RAISE NOTICE '════════════════════════════════════════════';
END $$;
