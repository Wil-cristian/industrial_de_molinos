-- =====================================================
-- FIX COMPLETO: Sistema de Descuento de Inventario
-- Industrial de Molinos
-- EJECUTAR EN SUPABASE SQL EDITOR
-- =====================================================

-- =====================================================
-- PASO 1: AGREGAR COLUMNAS FALTANTES
-- =====================================================

-- 1.1 Agregar product_id a quotation_items
DO $$ BEGIN
    ALTER TABLE quotation_items ADD COLUMN product_id UUID REFERENCES products(id);
    RAISE NOTICE '✅ Columna product_id agregada a quotation_items';
EXCEPTION 
    WHEN duplicate_column THEN 
        RAISE NOTICE 'ℹ️ Columna product_id ya existe en quotation_items';
END $$;

-- 1.2 Agregar inv_material_id a quotation_items (referencia a materials para inventario)
DO $$ BEGIN
    ALTER TABLE quotation_items ADD COLUMN inv_material_id UUID REFERENCES materials(id);
    RAISE NOTICE '✅ Columna inv_material_id agregada a quotation_items';
EXCEPTION 
    WHEN duplicate_column THEN 
        RAISE NOTICE 'ℹ️ Columna inv_material_id ya existe en quotation_items';
END $$;

-- 1.3 Agregar product_id a invoice_items
DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN product_id UUID REFERENCES products(id);
    RAISE NOTICE '✅ Columna product_id agregada a invoice_items';
EXCEPTION 
    WHEN duplicate_column THEN 
        RAISE NOTICE 'ℹ️ Columna product_id ya existe en invoice_items';
END $$;

-- 1.4 Agregar material_id a invoice_items (referencia a materials)
DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN material_id UUID REFERENCES materials(id);
    RAISE NOTICE '✅ Columna material_id agregada a invoice_items';
EXCEPTION 
    WHEN duplicate_column THEN 
        RAISE NOTICE 'ℹ️ Columna material_id ya existe en invoice_items';
END $$;

-- =====================================================
-- PASO 2: FUNCIÓN PRINCIPAL DE DESCUENTO
-- =====================================================

CREATE OR REPLACE FUNCTION deduct_inventory_item(
    p_material_id UUID,        -- ID de material directo (de tabla materials)
    p_product_id UUID,         -- ID de producto (puede ser receta)
    p_quantity DECIMAL,        -- Cantidad vendida
    p_reference VARCHAR,       -- Referencia (número de cotización/factura)
    p_reason VARCHAR,          -- Motivo del descuento
    p_quotation_id UUID DEFAULT NULL,
    p_invoice_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_comp RECORD;
    v_mat_stock DECIMAL;
    v_mat_name VARCHAR;
    v_prod_stock DECIMAL;
    v_is_recipe BOOLEAN;
    v_prod_name VARCHAR;
    v_components_count INT;
BEGIN
    -- CASO 1: Si es un MATERIAL directo
    IF p_material_id IS NOT NULL THEN
        SELECT stock, name INTO v_mat_stock, v_mat_name FROM materials WHERE id = p_material_id;
        
        IF v_mat_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Material no encontrado: ' || p_material_id);
        END IF;

        -- Descontar del inventario
        UPDATE materials 
        SET stock = stock - p_quantity, updated_at = NOW()
        WHERE id = p_material_id;
        
        -- Registrar movimiento
        INSERT INTO material_movements (
            material_id, type, quantity, previous_stock, new_stock, 
            reason, reference, quotation_id, invoice_id
        ) VALUES (
            p_material_id, 'outgoing', p_quantity, v_mat_stock, v_mat_stock - p_quantity,
            p_reason, p_reference, p_quotation_id, p_invoice_id
        );
        
        RETURN jsonb_build_object(
            'type', 'material', 
            'name', v_mat_name, 
            'quantity', p_quantity,
            'previous_stock', v_mat_stock,
            'new_stock', v_mat_stock - p_quantity,
            'success', true
        );
    END IF;

    -- CASO 2: Si es un PRODUCTO
    IF p_product_id IS NOT NULL THEN
        SELECT is_recipe, stock, name INTO v_is_recipe, v_prod_stock, v_prod_name 
        FROM products WHERE id = p_product_id;
        
        IF v_prod_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Producto no encontrado: ' || p_product_id);
        END IF;

        IF v_is_recipe = true THEN
            -- Es una RECETA: Descontar cada componente de materials
            SELECT COUNT(*) INTO v_components_count FROM product_components WHERE product_id = p_product_id;
            
            IF v_components_count = 0 THEN
                RETURN jsonb_build_object(
                    'success', false, 
                    'message', 'Receta sin componentes: ' || v_prod_name
                );
            END IF;
            
            FOR v_comp IN SELECT * FROM product_components WHERE product_id = p_product_id LOOP
                IF v_comp.material_id IS NOT NULL THEN
                    -- Llamada recursiva para descontar cada material del componente
                    PERFORM deduct_inventory_item(
                        v_comp.material_id,    -- material_id del componente
                        NULL,                  -- No es producto
                        v_comp.quantity * p_quantity,  -- Cantidad necesaria × unidades vendidas
                        p_reference,
                        'Componente de receta: ' || v_prod_name,
                        p_quotation_id,
                        p_invoice_id
                    );
                END IF;
            END LOOP;
            
            RETURN jsonb_build_object(
                'type', 'recipe', 
                'name', v_prod_name, 
                'quantity', p_quantity,
                'components_processed', v_components_count,
                'success', true
            );
        ELSE
            -- Es un PRODUCTO SIMPLE (no receta): Descontar del stock del producto
            UPDATE products 
            SET stock = stock - p_quantity, updated_at = NOW()
            WHERE id = p_product_id;
            
            -- Registrar en stock_movements (si existe la tabla)
            BEGIN
                INSERT INTO stock_movements (
                    product_id, type, quantity, previous_stock, new_stock, 
                    reason, reference
                ) VALUES (
                    p_product_id, 'outgoing', p_quantity, v_prod_stock, v_prod_stock - p_quantity,
                    p_reason, p_reference
                );
            EXCEPTION WHEN undefined_table THEN
                -- Si no existe stock_movements, ignorar
                NULL;
            END;
            
            RETURN jsonb_build_object(
                'type', 'product', 
                'name', v_prod_name, 
                'quantity', p_quantity,
                'previous_stock', v_prod_stock,
                'new_stock', v_prod_stock - p_quantity,
                'success', true
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'No se proporcionó ID de material ni de producto');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 3: FUNCIÓN DE APROBACIÓN CON DEBUG
-- =====================================================

CREATE OR REPLACE FUNCTION approve_quotation_with_materials(
    p_quotation_id UUID,
    p_series VARCHAR DEFAULT 'F001',
    p_deduct_materials BOOLEAN DEFAULT true
)
RETURNS JSON AS $$
DECLARE
    v_quotation RECORD;
    v_invoice_id UUID;
    v_invoice_number VARCHAR;
    v_item RECORD;
    v_deduction_results JSONB := '[]'::JSONB;
    v_res JSONB;
    v_debug_items JSONB := '[]'::JSONB;
BEGIN
    -- Obtener datos de la cotización
    SELECT * INTO v_quotation FROM quotations WHERE id = p_quotation_id;
    
    IF v_quotation IS NULL THEN
        RAISE EXCEPTION 'Cotización no encontrada: %', p_quotation_id;
    END IF;
    
    IF v_quotation.status = 'Aprobada' THEN
        RAISE EXCEPTION 'La cotización ya fue aprobada';
    END IF;
    
    -- Generar número de factura
    SELECT LPAD((COALESCE(MAX(CAST(NULLIF(number, '') AS INTEGER)), 0) + 1)::TEXT, 5, '0') 
    INTO v_invoice_number
    FROM invoices WHERE series = p_series;
    
    -- Descontar materiales si se solicita
    IF p_deduct_materials THEN
        FOR v_item IN SELECT * FROM quotation_items WHERE quotation_id = p_quotation_id LOOP
            -- Guardar info de debug del item
            v_debug_items := v_debug_items || jsonb_build_object(
                'item_name', v_item.name,
                'product_id', v_item.product_id,
                'inv_material_id', v_item.inv_material_id,
                'quantity', v_item.quantity
            );
            
            -- Determinar qué ID usar: inv_material_id para materiales, product_id para productos
            v_res := deduct_inventory_item(
                v_item.inv_material_id,   -- Material ID (puede ser NULL)
                v_item.product_id,         -- Product ID (puede ser NULL)
                v_item.quantity,
                'COT-' || v_quotation.number,
                v_item.name,
                p_quotation_id,
                NULL
            );
            v_deduction_results := v_deduction_results || v_res;
        END LOOP;
    END IF;
    
    -- Crear la factura
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
    
    -- Copiar items de la cotización a la factura
    INSERT INTO invoice_items (
        invoice_id, product_id, product_code, product_name, description, 
        quantity, unit, unit_price, discount, total_price, material_id
    )
    SELECT 
        v_invoice_id, product_id, material_name, name, description, 
        quantity, 'UND', unit_price, 0, total_price, inv_material_id
    FROM quotation_items WHERE quotation_id = p_quotation_id;
    
    -- Actualizar estado de la cotización
    UPDATE quotations SET status = 'Aprobada', updated_at = NOW()
    WHERE id = p_quotation_id;
    
    RETURN json_build_object(
        'invoice_id', v_invoice_id,
        'invoice_number', p_series || '-' || v_invoice_number,
        'deductions', v_deduction_results,
        'debug_items', v_debug_items,
        'success', true
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 4: FUNCIÓN PARA DESCUENTO EN VENTA DIRECTA
-- =====================================================

CREATE OR REPLACE FUNCTION deduct_inventory_for_invoice(p_invoice_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_item RECORD;
    v_invoice RECORD;
    v_deduction_results JSONB := '[]'::JSONB;
    v_res JSONB;
BEGIN
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    
    IF v_invoice IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Factura no encontrada');
    END IF;
    
    FOR v_item IN SELECT * FROM invoice_items WHERE invoice_id = p_invoice_id LOOP
        v_res := deduct_inventory_item(
            v_item.material_id,     -- Material ID
            v_item.product_id,      -- Product ID
            v_item.quantity,
            v_invoice.series || '-' || v_invoice.number,
            v_item.product_name,
            NULL,
            p_invoice_id
        );
        v_deduction_results := v_deduction_results || v_res;
    END LOOP;
    
    RETURN v_deduction_results;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PASO 5: PERMISOS
-- =====================================================

GRANT EXECUTE ON FUNCTION deduct_inventory_item TO anon, authenticated;
GRANT EXECUTE ON FUNCTION approve_quotation_with_materials TO anon, authenticated;
GRANT EXECUTE ON FUNCTION deduct_inventory_for_invoice TO anon, authenticated;

-- =====================================================
-- PASO 6: VERIFICACIÓN
-- =====================================================

-- Ver estructura de quotation_items
SELECT 'Estructura de quotation_items:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'quotation_items'
ORDER BY ordinal_position;

-- Ver estructura de invoice_items
SELECT 'Estructura de invoice_items:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'invoice_items'
ORDER BY ordinal_position;

-- Ver productos tipo receta con sus componentes
SELECT 'Productos tipo receta y sus componentes:' as info;
SELECT 
    p.id as product_id,
    p.name as product_name,
    p.is_recipe,
    pc.material_id,
    pc.name as component_name,
    pc.quantity as component_qty,
    m.name as material_name,
    m.stock as material_stock
FROM products p
LEFT JOIN product_components pc ON pc.product_id = p.id
LEFT JOIN materials m ON pc.material_id = m.id
WHERE p.is_recipe = true
ORDER BY p.name, pc.sort_order;

SELECT '✅ SCRIPT COMPLETADO - Ahora ejecuta en Flutter para probar' as resultado;
