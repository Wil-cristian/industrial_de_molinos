-- =====================================================
-- MIGRACIÓN 036: Operaciones de Inventario en Lote (Bulk)
-- =====================================================
-- Reemplaza FOR LOOPs individuales por operaciones SQL en lote.
-- Las firmas de funciones NO cambian → Dart no requiere cambios.
--
-- Optimizaciones:
--   deduct_inventory_item (recetas): FOR LOOP → 1 validación + 1 INSERT + 1 UPDATE
--   approve_quotation_with_materials: FOR LOOP + N llamadas → operaciones bulk inline
--   deduct_inventory_for_invoice: FOR LOOP + N llamadas → operaciones bulk inline
--   revert_material_deduction: FOR LOOP → 1 INSERT + 1 UPDATE
-- =====================================================

-- =====================================================
-- 1. deduct_inventory_item: Bulk para caso receta
-- =====================================================
-- Firma: (UUID, UUID, DECIMAL, VARCHAR, VARCHAR, UUID, UUID) → JSONB
-- Solo cambia la rama de recetas: FOR LOOP → 3 operaciones bulk.
-- =====================================================
CREATE OR REPLACE FUNCTION deduct_inventory_item(
    p_material_id UUID,
    p_product_id UUID,
    p_quantity DECIMAL,
    p_reference VARCHAR,
    p_reason VARCHAR,
    p_quotation_id UUID DEFAULT NULL,
    p_invoice_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_mat_stock DECIMAL;
    v_mat_name VARCHAR;
    v_mat_unit VARCHAR;
    v_prod_stock DECIMAL;
    v_is_recipe BOOLEAN;
    v_prod_name VARCHAR;
    v_components_count INT;
    v_results JSONB;
    v_fail_name VARCHAR;
    v_fail_stock DECIMAL;
    v_fail_required DECIMAL;
BEGIN
    -- Validar entrada
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cantidad debe ser mayor a 0');
    END IF;

    -- ─── CASO 1: MATERIAL DIRECTO ───
    IF p_material_id IS NOT NULL THEN
        SELECT stock, name, unit INTO v_mat_stock, v_mat_name, v_mat_unit 
        FROM materials WHERE id = p_material_id;
        
        IF v_mat_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Material no encontrado: ' || p_material_id);
        END IF;

        IF v_mat_stock < p_quantity THEN
            RETURN jsonb_build_object('success', false, 'error', 
                'Stock insuficiente de ' || v_mat_name || ': disponible=' || v_mat_stock || ', requerido=' || p_quantity);
        END IF;

        UPDATE materials 
        SET stock = stock - p_quantity, updated_at = NOW()
        WHERE id = p_material_id;
        
        INSERT INTO material_movements (
            material_id, type, quantity, previous_stock, new_stock, 
            reason, reference, quotation_id, invoice_id
        ) VALUES (
            p_material_id, 'outgoing', p_quantity, v_mat_stock, v_mat_stock - p_quantity,
            p_reason, p_reference, p_quotation_id, p_invoice_id
        );
        
        RETURN jsonb_build_object(
            'success', true, 'type', 'material', 
            'name', v_mat_name, 'unit', v_mat_unit,
            'quantity_deducted', p_quantity,
            'previous_stock', v_mat_stock,
            'new_stock', v_mat_stock - p_quantity
        );
    END IF;

    -- ─── CASO 2: PRODUCTO ───
    IF p_product_id IS NOT NULL THEN
        SELECT is_recipe, stock, name INTO v_is_recipe, v_prod_stock, v_prod_name 
        FROM products WHERE id = p_product_id;
        
        IF v_prod_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado: ' || p_product_id);
        END IF;

        IF v_is_recipe = true THEN
            -- ─── RECETA: Descuento BULK de componentes ───
            SELECT COUNT(*) INTO v_components_count 
            FROM product_components WHERE product_id = p_product_id;
            
            IF v_components_count = 0 THEN
                RETURN jsonb_build_object('success', false, 'error', 'Receta sin componentes', 'product', v_prod_name);
            END IF;
            
            -- PASO 1: Validar stock de TODOS los componentes de una vez (agregado por material)
            SELECT m.name, m.stock, agg.total_required
            INTO v_fail_name, v_fail_stock, v_fail_required
            FROM (
                SELECT pc.material_id, SUM(pc.quantity * p_quantity) as total_required
                FROM product_components pc
                WHERE pc.product_id = p_product_id
                GROUP BY pc.material_id
            ) agg
            JOIN materials m ON m.id = agg.material_id
            WHERE m.stock < agg.total_required
            LIMIT 1;
            
            IF v_fail_name IS NOT NULL THEN
                RETURN jsonb_build_object('success', false, 'error', 
                    'Stock insuficiente de componente ' || v_fail_name || 
                    ': disponible=' || v_fail_stock || ', requerido=' || v_fail_required);
            END IF;
            
            -- PASO 2: Bulk INSERT movimientos (antes del UPDATE para capturar stock actual)
            INSERT INTO material_movements (
                material_id, type, quantity, previous_stock, new_stock, 
                reason, reference, quotation_id, invoice_id
            )
            SELECT 
                pc.material_id, 'outgoing', pc.quantity * p_quantity,
                m.stock, m.stock - (pc.quantity * p_quantity),
                'Receta: ' || v_prod_name || ' - ' || pc.name, 
                p_reference, p_quotation_id, p_invoice_id
            FROM product_components pc
            JOIN materials m ON m.id = pc.material_id
            WHERE pc.product_id = p_product_id;
            
            -- PASO 3: Bulk UPDATE materiales (agregado para manejar mismo material en múltiples componentes)
            UPDATE materials 
            SET stock = materials.stock - agg.total_qty, updated_at = NOW()
            FROM (
                SELECT pc.material_id, SUM(pc.quantity * p_quantity) as total_qty
                FROM product_components pc
                WHERE pc.product_id = p_product_id
                GROUP BY pc.material_id
            ) agg
            WHERE materials.id = agg.material_id;
            
            -- Construir JSON de resultados (stock ya actualizado)
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'component', pc.name, 'material', m.name,
                'quantity', pc.quantity * p_quantity,
                'unit', m.unit
            )), '[]'::jsonb)
            INTO v_results
            FROM product_components pc
            JOIN materials m ON m.id = pc.material_id
            WHERE pc.product_id = p_product_id;
            
            RETURN jsonb_build_object(
                'success', true, 'type', 'recipe', 'name', v_prod_name, 
                'quantity_sold', p_quantity, 'components_deducted', v_components_count,
                'details', v_results
            );
        ELSE
            -- ─── PRODUCTO SIMPLE ───
            IF v_prod_stock < p_quantity THEN
                RETURN jsonb_build_object('success', false, 'error', 
                    'Stock insuficiente de ' || v_prod_name || ': disponible=' || v_prod_stock || ', requerido=' || p_quantity);
            END IF;

            UPDATE products 
            SET stock = stock - p_quantity, updated_at = NOW()
            WHERE id = p_product_id;
            
            RETURN jsonb_build_object(
                'success', true, 'type', 'product', 'name', v_prod_name, 
                'quantity_deducted', p_quantity, 'previous_stock', v_prod_stock,
                'new_stock', v_prod_stock - p_quantity
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('success', false, 'error', 'No se proporcionó material_id ni product_id');
END;
$$ LANGUAGE plpgsql;


-- =====================================================
-- 2. approve_quotation_with_materials: Descuento bulk inline
-- =====================================================
-- Antes: FOR LOOP sobre quotation_items → N llamadas a deduct_inventory_item
-- Ahora: 1 validación + 1 INSERT + 1 UPDATE para materiales
--        + 1 validación + 1 UPDATE para productos simples
-- =====================================================
CREATE OR REPLACE FUNCTION approve_quotation_with_materials(
    p_quotation_id UUID,
    p_series VARCHAR DEFAULT 'F001',
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
    
    -- Generar número de factura
    SELECT LPAD((COALESCE(MAX(CAST(NULLIF(number, '') AS INTEGER)), 0) + 1)::TEXT, 5, '0') 
    INTO v_invoice_number
    FROM invoices WHERE series = p_series;
    
    -- ─── DESCUENTO BULK DE INVENTARIO ───
    IF p_deduct_materials THEN
        
        -- Recopilar TODAS las deducciones de materiales necesarias:
        --   a) material_id directo de quotation_items
        --   b) componentes de recetas (product_components expandidos)
        -- Luego validar, insertar movimientos, y actualizar stock en lote.
        
        -- PASO 1: Validar stock de materiales (agregado por material)
        WITH all_material_deductions AS (
            -- Materiales directos
            SELECT qi.material_id, qi.quantity
            FROM quotation_items qi
            WHERE qi.quotation_id = p_quotation_id
            AND qi.material_id IS NOT NULL
            
            UNION ALL
            
            -- Componentes de recetas
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
        
        -- PASO 2: Validar stock de productos simples
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
        
        -- PASO 3: Bulk INSERT movimientos para materiales
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
        
        -- PASO 4: Bulk UPDATE materiales (agregado)
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
        
        -- PASO 5: Bulk UPDATE productos simples
        UPDATE products 
        SET stock = products.stock - qi.quantity, updated_at = NOW()
        FROM quotation_items qi
        WHERE qi.quotation_id = p_quotation_id
        AND qi.product_id IS NOT NULL
        AND products.id = qi.product_id
        AND (products.is_recipe IS NULL OR products.is_recipe = false);
        
        -- Construir JSON de resultados
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
    
    -- ─── CREAR FACTURA ───
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
    
    -- Copiar items
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
        'deductions', v_deduction_results
    );
END;
$$ LANGUAGE plpgsql;


-- =====================================================
-- 3. deduct_inventory_for_invoice: Descuento bulk inline
-- =====================================================
-- Antes: FOR LOOP sobre invoice_items → N llamadas a deduct_inventory_item
-- Ahora: 1 validación + 1 INSERT + 1 UPDATE para materiales
--        + 1 validación + 1 UPDATE para productos simples
-- =====================================================
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
        
        -- Componentes de recetas
        SELECT pc.material_id, pc.quantity * ii.quantity
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
        
        SELECT pc.material_id, pc.quantity * ii.quantity,
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
        
        SELECT pc.material_id, pc.quantity * ii.quantity
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
        
        SELECT pc.material_id, ii.product_id, pc.quantity * ii.quantity,
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


-- =====================================================
-- 4. revert_material_deduction: Reversión bulk
-- =====================================================
-- Antes: FOR LOOP → N UPDATE + N INSERT
-- Ahora: 1 INSERT + 1 UPDATE
-- =====================================================
CREATE OR REPLACE FUNCTION revert_material_deduction(p_quotation_id UUID)
RETURNS VOID AS $$
BEGIN
    -- PASO 1: Bulk INSERT movimientos de reversión (antes del UPDATE para capturar stock actual)
    INSERT INTO material_movements (
        material_id, type, quantity, previous_stock, new_stock, 
        reason, reference, quotation_id
    )
    SELECT 
        mm.material_id, 'incoming', mm.quantity,
        m.stock, m.stock + mm.quantity,
        'Reversión: Cotización cancelada', mm.reference, p_quotation_id
    FROM material_movements mm
    JOIN materials m ON m.id = mm.material_id
    WHERE mm.quotation_id = p_quotation_id AND mm.type = 'outgoing';
    
    -- PASO 2: Bulk UPDATE materiales (agregado por material)
    UPDATE materials 
    SET stock = materials.stock + agg.total_qty, updated_at = NOW()
    FROM (
        SELECT material_id, SUM(quantity) as total_qty
        FROM material_movements 
        WHERE quotation_id = p_quotation_id AND type = 'outgoing'
        GROUP BY material_id
    ) agg
    WHERE materials.id = agg.material_id;
END;
$$ LANGUAGE plpgsql;


-- =====================================================
-- 5. Permisos (mantener los mismos)
-- =====================================================
GRANT EXECUTE ON FUNCTION deduct_inventory_item(UUID, UUID, DECIMAL, VARCHAR, VARCHAR, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_quotation_with_materials TO authenticated;
GRANT EXECUTE ON FUNCTION deduct_inventory_for_invoice TO authenticated;
GRANT EXECUTE ON FUNCTION revert_material_deduction TO authenticated;

-- =====================================================
-- Verificación
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Migración 036 aplicada: Operaciones de inventario en lote';
    RAISE NOTICE '   • deduct_inventory_item: receta FOR LOOP → bulk (1 validación + 1 INSERT + 1 UPDATE)';
    RAISE NOTICE '   • approve_quotation_with_materials: N llamadas → 5 operaciones bulk';
    RAISE NOTICE '   • deduct_inventory_for_invoice: N llamadas → 5 operaciones bulk';
    RAISE NOTICE '   • revert_material_deduction: FOR LOOP → 2 operaciones bulk';
END $$;
