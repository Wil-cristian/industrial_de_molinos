-- =====================================================
-- FIX CRÍTICO: Corregir tabla de movimientos
-- Industrial de Molinos
-- EJECUTAR EN SUPABASE SQL EDITOR
-- =====================================================

-- =====================================================
-- 1. CREAR TABLA material_movements si no existe
-- =====================================================
CREATE TABLE IF NOT EXISTS material_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL, -- 'incoming', 'outgoing', 'adjustment'
    quantity DECIMAL(12,4) NOT NULL,
    previous_stock DECIMAL(12,4),
    new_stock DECIMAL(12,4),
    reason TEXT,
    reference VARCHAR(100),
    quotation_id UUID REFERENCES quotations(id),
    invoice_id UUID REFERENCES invoices(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_material_movements_material ON material_movements(material_id);
CREATE INDEX IF NOT EXISTS idx_material_movements_quotation ON material_movements(quotation_id);
CREATE INDEX IF NOT EXISTS idx_material_movements_invoice ON material_movements(invoice_id);

-- =====================================================
-- 1.5 AGREGAR COLUMNAS FALTANTES A invoice_items
-- =====================================================
DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN product_id UUID REFERENCES products(id);
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN material_id UUID REFERENCES materials(id);
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

-- =====================================================
-- 2. FUNCIÓN PRINCIPAL: Descontar del inventario
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
    v_comp RECORD;
    v_mat_stock DECIMAL;
    v_mat_name VARCHAR;
    v_mat_unit VARCHAR;
    v_prod_stock DECIMAL;
    v_is_recipe BOOLEAN;
    v_prod_name VARCHAR;
    v_components_count INT;
    v_results JSONB := '[]'::JSONB;
BEGIN
    -- CASO 1: MATERIAL DIRECTO (de tabla materials)
    IF p_material_id IS NOT NULL THEN
        SELECT stock, name, unit INTO v_mat_stock, v_mat_name, v_mat_unit 
        FROM materials WHERE id = p_material_id;
        
        IF v_mat_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Material no encontrado: ' || p_material_id);
        END IF;

        -- Descontar del inventario
        UPDATE materials 
        SET stock = stock - p_quantity, updated_at = NOW()
        WHERE id = p_material_id;
        
        -- Registrar movimiento
        BEGIN
            INSERT INTO material_movements (
                material_id, type, quantity, previous_stock, new_stock, 
                reason, reference, quotation_id, invoice_id
            ) VALUES (
                p_material_id, 'outgoing', p_quantity, v_mat_stock, v_mat_stock - p_quantity,
                p_reason, p_reference, p_quotation_id, p_invoice_id
            );
        EXCEPTION WHEN OTHERS THEN
            -- Si material_movements no existe, continuar sin error
            NULL;
        END;
        
        RETURN jsonb_build_object(
            'success', true,
            'type', 'material', 
            'name', v_mat_name, 
            'unit', v_mat_unit,
            'quantity_deducted', p_quantity,
            'previous_stock', v_mat_stock,
            'new_stock', v_mat_stock - p_quantity
        );
    END IF;

    -- CASO 2: PRODUCTO (puede ser receta o producto simple)
    IF p_product_id IS NOT NULL THEN
        SELECT is_recipe, stock, name INTO v_is_recipe, v_prod_stock, v_prod_name 
        FROM products WHERE id = p_product_id;
        
        IF v_prod_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado: ' || p_product_id);
        END IF;

        -- Si es RECETA: Descontar cada componente de materials
        IF v_is_recipe = true THEN
            SELECT COUNT(*) INTO v_components_count 
            FROM product_components WHERE product_id = p_product_id;
            
            IF v_components_count = 0 THEN
                RETURN jsonb_build_object(
                    'success', false, 
                    'error', 'Receta sin componentes',
                    'product', v_prod_name
                );
            END IF;
            
            -- Descontar cada componente
            FOR v_comp IN 
                SELECT pc.*, m.name as mat_name, m.stock as mat_stock, m.unit as mat_unit
                FROM product_components pc
                JOIN materials m ON m.id = pc.material_id
                WHERE pc.product_id = p_product_id 
            LOOP
                DECLARE
                    v_qty_to_deduct DECIMAL := v_comp.quantity * p_quantity;
                BEGIN
                    UPDATE materials 
                    SET stock = stock - v_qty_to_deduct, updated_at = NOW()
                    WHERE id = v_comp.material_id;
                    
                    BEGIN
                        INSERT INTO material_movements (
                            material_id, type, quantity, previous_stock, new_stock, 
                            reason, reference, quotation_id, invoice_id
                        ) VALUES (
                            v_comp.material_id, 'outgoing', v_qty_to_deduct, 
                            v_comp.mat_stock, v_comp.mat_stock - v_qty_to_deduct,
                            'Receta: ' || v_prod_name || ' - ' || v_comp.name, 
                            p_reference, p_quotation_id, p_invoice_id
                        );
                    EXCEPTION WHEN OTHERS THEN
                        NULL;
                    END;
                    
                    v_results := v_results || jsonb_build_object(
                        'component', v_comp.mat_name,
                        'quantity', v_qty_to_deduct,
                        'unit', v_comp.mat_unit,
                        'previous', v_comp.mat_stock,
                        'new', v_comp.mat_stock - v_qty_to_deduct
                    );
                END;
            END LOOP;
            
            RETURN jsonb_build_object(
                'success', true,
                'type', 'recipe', 
                'name', v_prod_name, 
                'quantity_sold', p_quantity,
                'components_deducted', v_components_count,
                'details', v_results
            );
        ELSE
            -- PRODUCTO SIMPLE: Descontar del stock del producto
            UPDATE products 
            SET stock = stock - p_quantity, updated_at = NOW()
            WHERE id = p_product_id;
            
            RETURN jsonb_build_object(
                'success', true,
                'type', 'product', 
                'name', v_prod_name, 
                'quantity_deducted', p_quantity,
                'previous_stock', v_prod_stock,
                'new_stock', v_prod_stock - p_quantity
            );
        END IF;
    END IF;

    RETURN jsonb_build_object('success', false, 'error', 'No se proporcionó ID válido');
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. FUNCIÓN: Aprobar cotización
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
    v_items_debug JSONB := '[]'::JSONB;
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
    
    -- Procesar cada item
    IF p_deduct_materials THEN
        FOR v_item IN SELECT * FROM quotation_items WHERE quotation_id = p_quotation_id LOOP
            v_items_debug := v_items_debug || jsonb_build_object(
                'name', v_item.name,
                'product_id', v_item.product_id,
                'inv_material_id', v_item.inv_material_id,
                'quantity', v_item.quantity
            );
            
            IF v_item.product_id IS NOT NULL OR v_item.inv_material_id IS NOT NULL THEN
                v_res := deduct_inventory_item(
                    v_item.inv_material_id,
                    v_item.product_id,
                    v_item.quantity,
                    'COT-' || v_quotation.number,
                    v_item.name,
                    p_quotation_id,
                    NULL
                );
                v_deduction_results := v_deduction_results || v_res;
            END IF;
        END LOOP;
    END IF;
    
    -- Crear factura
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
        quantity, 'UND', unit_price, 0, unit_price * quantity, 0, unit_price * quantity, inv_material_id
    FROM quotation_items WHERE quotation_id = p_quotation_id;
    
    -- Actualizar estado
    UPDATE quotations SET status = 'Aprobada', updated_at = NOW()
    WHERE id = p_quotation_id;
    
    RETURN json_build_object(
        'success', true,
        'invoice_id', v_invoice_id,
        'invoice_number', p_series || '-' || v_invoice_number,
        'items_processed', v_items_debug,
        'deductions', v_deduction_results
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. FUNCIÓN: Descuento en venta directa
-- =====================================================
CREATE OR REPLACE FUNCTION deduct_inventory_for_invoice(p_invoice_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_item RECORD;
    v_invoice RECORD;
    v_results JSONB := '[]'::JSONB;
    v_res JSONB;
BEGIN
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    
    IF v_invoice IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Factura no encontrada');
    END IF;
    
    FOR v_item IN SELECT * FROM invoice_items WHERE invoice_id = p_invoice_id LOOP
        v_res := deduct_inventory_item(
            v_item.material_id,
            v_item.product_id,
            v_item.quantity,
            v_invoice.series || '-' || v_invoice.number,
            v_item.product_name,
            NULL,
            p_invoice_id
        );
        v_results := v_results || v_res;
    END LOOP;
    
    RETURN jsonb_build_object('success', true, 'deductions', v_results);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. PERMISOS
-- =====================================================
GRANT EXECUTE ON FUNCTION deduct_inventory_item TO anon, authenticated;
GRANT EXECUTE ON FUNCTION approve_quotation_with_materials TO anon, authenticated;
GRANT EXECUTE ON FUNCTION deduct_inventory_for_invoice TO anon, authenticated;

-- =====================================================
-- 6. VERIFICACIÓN
-- =====================================================
SELECT '✅ Script completado exitosamente' as resultado;

-- Ver estructura de quotation_items
SELECT '--- quotation_items ---' as tabla;
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'quotation_items' ORDER BY ordinal_position;

-- Ver estructura de invoice_items
SELECT '--- invoice_items ---' as tabla;
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'invoice_items' ORDER BY ordinal_position;

-- Ver tabla material_movements
SELECT '--- material_movements ---' as tabla;
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'material_movements' ORDER BY ordinal_position;

-- Ver recetas
SELECT '=== PRODUCTOS TIPO RECETA ===' as info;
SELECT p.name, COUNT(pc.id) as componentes, p.total_weight
FROM products p
LEFT JOIN product_components pc ON pc.product_id = p.id
WHERE p.is_recipe = true
GROUP BY p.id;
