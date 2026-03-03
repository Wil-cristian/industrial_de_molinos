-- =====================================================
-- EJECUTAR EN SUPABASE SQL EDITOR
-- Función: approve_quotation_with_materials
-- Propósito: Aprobar cotización → crear recibo + descontar inventario
-- =====================================================

-- Eliminar función vieja si existe (para recrear limpia)
DROP FUNCTION IF EXISTS approve_quotation_with_materials(UUID, VARCHAR, BOOLEAN);

-- =====================================================
-- FUNCIÓN PRINCIPAL: Aprobar cotización con descuento de inventario
-- =====================================================
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
    -- Obtener cotización
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
        
        -- PASO 1: Validar stock de materiales directos + recetas (agregado por material)
        WITH all_material_deductions AS (
            -- Materiales directos en quotation_items
            SELECT qi.material_id, qi.quantity
            FROM quotation_items qi
            WHERE qi.quotation_id = p_quotation_id
            AND qi.material_id IS NOT NULL
            
            UNION ALL
            
            -- Componentes de recetas (expandir product_components)
            SELECT pc.material_id, pc.quantity * qi.quantity
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
            
            SELECT pc.material_id, pc.quantity * qi.quantity,
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
            
            SELECT pc.material_id, pc.quantity * qi.quantity
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
            
            SELECT pc.material_id, pc.quantity * qi.quantity,
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
    
    -- Retornar resultado completo
    RETURN json_build_object(
        'success', true,
        'invoice_id', v_invoice_id,
        'invoice_number', p_series || '-' || v_invoice_number,
        'deductions', v_deduction_results,
        'items_processed', (SELECT COUNT(*) FROM quotation_items WHERE quotation_id = p_quotation_id)
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PERMISOS
-- =====================================================
GRANT EXECUTE ON FUNCTION approve_quotation_with_materials TO anon, authenticated;

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'approve_quotation_with_materials') THEN
        RAISE NOTICE '✅ Función approve_quotation_with_materials creada exitosamente';
        RAISE NOTICE '   → Descuenta materiales directos (quotation_items.material_id)';
        RAISE NOTICE '   → Descuenta componentes de recetas (product_components)';
        RAISE NOTICE '   → Descuenta stock de productos simples';
        RAISE NOTICE '   → Registra movimientos en material_movements';
        RAISE NOTICE '   → Crea factura/recibo con items copiados';
    ELSE
        RAISE NOTICE '❌ ERROR: La función NO fue creada';
    END IF;
END $$;
