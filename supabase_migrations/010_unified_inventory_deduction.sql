-- =====================================================
-- SISTEMA UNIFICADO DE DESCUENTO DE INVENTARIO
-- Industrial de Molinos
-- =====================================================

-- 1. FUNCIÓN ATÓMICA PARA DESCONTAR UN ITEM (Material o Producto/Receta)
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
    v_prod_stock DECIMAL;
    v_is_recipe BOOLEAN;
    v_mat_name VARCHAR;
    v_prod_name VARCHAR;
BEGIN
    -- 1. Si es un MATERIAL directo
    IF p_material_id IS NOT NULL THEN
        SELECT stock, name INTO v_mat_stock, v_mat_name FROM materials WHERE id = p_material_id;
        
        IF v_mat_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Material no encontrado');
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
        
        RETURN jsonb_build_object('type', 'material', 'name', v_mat_name, 'quantity', p_quantity, 'success', true);
    END IF;

    -- 2. Si es un PRODUCTO
    IF p_product_id IS NOT NULL THEN
        SELECT is_recipe, stock, name INTO v_is_recipe, v_prod_stock, v_prod_name FROM products WHERE id = p_product_id;
        
        IF v_prod_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'message', 'Producto no encontrado');
        END IF;

        IF v_is_recipe THEN
            -- Es una RECETA: Descontar componentes
            FOR v_comp IN SELECT * FROM product_components WHERE product_id = p_product_id LOOP
                -- Llamada recursiva para cada componente (que son materiales)
                PERFORM deduct_inventory_item(
                    v_comp.material_id, 
                    NULL, 
                    v_comp.quantity * p_quantity, 
                    p_reference, 
                    'Receta: ' || v_prod_name,
                    p_quotation_id,
                    p_invoice_id
                );
            END LOOP;
            RETURN jsonb_build_object('type', 'recipe', 'name', v_prod_name, 'quantity', p_quantity, 'success', true);
        ELSE
            -- Es un PRODUCTO SIMPLE: Descontar de stock de productos
            UPDATE products 
            SET stock = stock - p_quantity, updated_at = NOW()
            WHERE id = p_product_id;
            
            INSERT INTO stock_movements (
                product_id, type, quantity, previous_stock, new_stock, 
                reason, reference
            ) VALUES (
                p_product_id, 'outgoing', p_quantity, v_prod_stock, v_prod_stock - p_quantity,
                p_reason, p_reference
            );
            RETURN jsonb_build_object('type', 'product', 'name', v_prod_name, 'quantity', p_quantity, 'success', true);
        END IF;
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'No se proporcionó ID de material ni de producto');
END;
$$ LANGUAGE plpgsql;

-- 2. ACTUALIZAR FUNCIÓN DE APROBACIÓN DE COTIZACIÓN
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
BEGIN
    -- Obtener datos de la cotización
    SELECT * INTO v_quotation FROM quotations WHERE id = p_quotation_id;
    
    IF v_quotation IS NULL THEN
        RAISE EXCEPTION 'Cotización no encontrada';
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
            v_res := deduct_inventory_item(
                v_item.material_id,
                v_item.product_id, -- Asegurarse de que quotation_items tenga product_id
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
        quantity, 'UND', unit_price, 0, total_price, material_id
    FROM quotation_items WHERE quotation_id = p_quotation_id;
    
    -- Actualizar estado de la cotización
    UPDATE quotations SET status = 'Aprobada', updated_at = NOW()
    WHERE id = p_quotation_id;
    
    RETURN json_build_object(
        'invoice_id', v_invoice_id,
        'invoice_number', p_series || '-' || v_invoice_number,
        'deductions', v_deduction_results
    );
END;
$$ LANGUAGE plpgsql;

-- 3. FUNCIÓN PARA DESCONTAR DESDE FACTURA DIRECTA (Nueva Venta)
CREATE OR REPLACE FUNCTION deduct_inventory_for_invoice(p_invoice_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_item RECORD;
    v_invoice RECORD;
    v_deduction_results JSONB := '[]'::JSONB;
    v_res JSONB;
BEGIN
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    
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
        v_deduction_results := v_deduction_results || v_res;
    END LOOP;
    
    RETURN v_deduction_results;
END;
$$ LANGUAGE plpgsql;

-- 4. ASEGURAR COLUMNAS EN TABLAS
DO $$ BEGIN
    ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id);
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id);
EXCEPTION WHEN others THEN null;
END $$;

-- 5. PERMISOS
GRANT EXECUTE ON FUNCTION deduct_inventory_item TO anon, authenticated;
GRANT EXECUTE ON FUNCTION approve_quotation_with_materials TO anon, authenticated;
GRANT EXECUTE ON FUNCTION deduct_inventory_for_invoice TO anon, authenticated;
