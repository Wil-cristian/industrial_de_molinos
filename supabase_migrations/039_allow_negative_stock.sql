-- =====================================================
-- MIGRACIÓN 039: Permitir Stock Negativo
-- =====================================================
-- Cambio: Las ventas SIEMPRE descuentan inventario, incluso si
-- el stock queda en valores negativos. Esto permite vender sin
-- restricción y luego reponer el inventario.
-- =====================================================

-- ─────────────────────────────────────────────────────────
-- PASO 1: Eliminar CHECK constraints que impiden stock < 0
-- ─────────────────────────────────────────────────────────
ALTER TABLE products DROP CONSTRAINT IF EXISTS chk_products_stock_non_negative;
ALTER TABLE materials DROP CONSTRAINT IF EXISTS chk_materials_stock_non_negative;

-- ─────────────────────────────────────────────────────────
-- PASO 2: Eliminar triggers de validación de stock
-- ─────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_validate_product_stock ON products;
DROP TRIGGER IF EXISTS trg_validate_material_stock ON materials;
DROP FUNCTION IF EXISTS validate_stock_before_update();

-- ─────────────────────────────────────────────────────────
-- PASO 3A: Actualizar deduct_inventory_item (versión 2-param de 033)
--          Quitar validación de stock insuficiente
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION deduct_inventory_item(
    p_product_id UUID,
    p_quantity DECIMAL(10,2)
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_stock DECIMAL(10,2);
    v_product_name TEXT;
BEGIN
    SELECT stock, name INTO v_current_stock, v_product_name
    FROM products WHERE id = p_product_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto no encontrado: %', p_product_id;
    END IF;
    
    -- Descontar sin importar si queda negativo
    UPDATE products 
    SET stock = stock - p_quantity, updated_at = NOW()
    WHERE id = p_product_id;
    
    INSERT INTO material_movements (
        material_id, product_id, movement_type, quantity,
        notes, created_at
    ) VALUES (
        NULL, p_product_id, 'salida', p_quantity,
        'Descuento automático por venta', NOW()
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────
-- PASO 3B: Actualizar deduct_inventory_item (versión bulk de 036)
--          Quitar todas las validaciones de stock insuficiente
-- ─────────────────────────────────────────────────────────
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

        -- Descontar sin importar si queda negativo
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
            
            -- Bulk INSERT movimientos (antes del UPDATE para capturar stock actual)
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
            
            -- Bulk UPDATE materiales (agregado para manejar mismo material múltiple)
            UPDATE materials 
            SET stock = materials.stock - agg.total_qty, updated_at = NOW()
            FROM (
                SELECT pc.material_id, SUM(pc.quantity * p_quantity) as total_qty
                FROM product_components pc
                WHERE pc.product_id = p_product_id
                GROUP BY pc.material_id
            ) agg
            WHERE materials.id = agg.material_id;
            
            -- Construir JSON de resultados
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
            -- ─── PRODUCTO SIMPLE: descontar sin restricción ───
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


-- ─────────────────────────────────────────────────────────
-- PASO 4: Actualizar deduct_inventory_for_invoice (bulk)
--         Quitar validaciones de stock insuficiente
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION deduct_inventory_for_invoice(p_invoice_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_invoice RECORD;
    v_results JSONB;
    v_reference VARCHAR;
BEGIN
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    
    IF v_invoice IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Factura no encontrada');
    END IF;
    
    v_reference := v_invoice.series || '-' || v_invoice.number;
    
    -- SIN validación de stock → se permite stock negativo
    
    -- PASO 1: Bulk INSERT movimientos para materiales
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
    
    -- PASO 2: Bulk UPDATE materiales (agregado)
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
    
    -- PASO 3: Bulk UPDATE productos simples
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


-- ─────────────────────────────────────────────────────────
-- PASO 5: Actualizar approve_quotation_with_materials (bulk)
--         Quitar validaciones de stock insuficiente
-- ─────────────────────────────────────────────────────────
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
    
    -- ─── DESCUENTO BULK DE INVENTARIO (sin validación de stock) ───
    IF p_deduct_materials THEN
        
        -- PASO 1: Bulk INSERT movimientos para materiales
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
        
        -- PASO 2: Bulk UPDATE materiales (agregado)
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
        
        -- PASO 3: Bulk UPDATE productos simples
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


-- ─────────────────────────────────────────────────────────
-- VERIFICACIÓN
-- ─────────────────────────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '✅ Migración 039: Stock negativo permitido';
    RAISE NOTICE '   • CHECK constraints eliminados de products y materials';
    RAISE NOTICE '   • Triggers de validación eliminados';
    RAISE NOTICE '   • deduct_inventory_item: sin restricción de stock';
    RAISE NOTICE '   • deduct_inventory_for_invoice: sin restricción de stock';
    RAISE NOTICE '   • approve_quotation_with_materials: sin restricción de stock';
END $$;
