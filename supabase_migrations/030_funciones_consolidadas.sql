-- =====================================================
-- MIGRACIÓN 030: Funciones SQL Consolidadas (Versiones Finales)
-- =====================================================
-- Este archivo contiene la versión DEFINITIVA de cada función.
-- Elimina funciones duplicadas/obsoletas y deja una sola versión canónica.
-- =====================================================

-- =====================================================
-- 1. ELIMINAR FUNCIONES DUPLICADAS/OBSOLETAS
-- =====================================================

-- approve_quotation_and_create_invoice (vieja, sin inventario) → reemplazada por approve_quotation_with_materials
DROP FUNCTION IF EXISTS approve_quotation_and_create_invoice(UUID, VARCHAR);

-- check_stock_availability (vieja, usaba material_prices) → reemplazada por check_quotation_stock
DROP FUNCTION IF EXISTS check_stock_availability(UUID);

-- Versiones viejas que podrían existir con firmas diferentes
DROP FUNCTION IF EXISTS deduct_inventory_item(UUID, UUID, DECIMAL, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS deduct_inventory_for_invoice(UUID);
DROP FUNCTION IF EXISTS register_payroll_payment(UUID, UUID, VARCHAR); -- firma vieja con payment_method

-- =====================================================
-- 2. FUNCIÓN: deduct_inventory_item (VERSIÓN DEFINITIVA)
--    Descontar material directo, receta o producto simple.
--    Fuente: 013_fix_material_movements.sql (mejorada)
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
    -- Validaciones de entrada
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cantidad debe ser mayor a 0');
    END IF;

    -- CASO 1: MATERIAL DIRECTO (de tabla materials)
    IF p_material_id IS NOT NULL THEN
        SELECT stock, name, unit INTO v_mat_stock, v_mat_name, v_mat_unit 
        FROM materials WHERE id = p_material_id;
        
        IF v_mat_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Material no encontrado: ' || p_material_id);
        END IF;

        IF v_mat_stock < p_quantity THEN
            RETURN jsonb_build_object('success', false, 'error', 'Stock insuficiente de ' || v_mat_name || ': disponible=' || v_mat_stock || ', requerido=' || p_quantity);
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

    -- CASO 2: PRODUCTO (receta o simple)
    IF p_product_id IS NOT NULL THEN
        SELECT is_recipe, stock, name INTO v_is_recipe, v_prod_stock, v_prod_name 
        FROM products WHERE id = p_product_id;
        
        IF v_prod_name IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado: ' || p_product_id);
        END IF;

        IF v_is_recipe = true THEN
            -- RECETA: Descontar cada componente de materials
            SELECT COUNT(*) INTO v_components_count 
            FROM product_components WHERE product_id = p_product_id;
            
            IF v_components_count = 0 THEN
                RETURN jsonb_build_object('success', false, 'error', 'Receta sin componentes', 'product', v_prod_name);
            END IF;
            
            FOR v_comp IN 
                SELECT pc.*, m.name as mat_name, m.stock as mat_stock, m.unit as mat_unit
                FROM product_components pc
                JOIN materials m ON m.id = pc.material_id
                WHERE pc.product_id = p_product_id 
            LOOP
                DECLARE
                    v_qty_to_deduct DECIMAL := v_comp.quantity * p_quantity;
                BEGIN
                    IF v_comp.mat_stock < v_qty_to_deduct THEN
                        RETURN jsonb_build_object('success', false, 'error', 
                            'Stock insuficiente de componente ' || v_comp.mat_name || 
                            ': disponible=' || v_comp.mat_stock || ', requerido=' || v_qty_to_deduct);
                    END IF;

                    UPDATE materials 
                    SET stock = stock - v_qty_to_deduct, updated_at = NOW()
                    WHERE id = v_comp.material_id;
                    
                    INSERT INTO material_movements (
                        material_id, type, quantity, previous_stock, new_stock, 
                        reason, reference, quotation_id, invoice_id
                    ) VALUES (
                        v_comp.material_id, 'outgoing', v_qty_to_deduct, 
                        v_comp.mat_stock, v_comp.mat_stock - v_qty_to_deduct,
                        'Receta: ' || v_prod_name || ' - ' || v_comp.name, 
                        p_reference, p_quotation_id, p_invoice_id
                    );
                    
                    v_results := v_results || jsonb_build_object(
                        'component', v_comp.mat_name, 'quantity', v_qty_to_deduct,
                        'unit', v_comp.mat_unit, 'previous', v_comp.mat_stock,
                        'new', v_comp.mat_stock - v_qty_to_deduct
                    );
                END;
            END LOOP;
            
            RETURN jsonb_build_object(
                'success', true, 'type', 'recipe', 'name', v_prod_name, 
                'quantity_sold', p_quantity, 'components_deducted', v_components_count,
                'details', v_results
            );
        ELSE
            -- PRODUCTO SIMPLE
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
-- 3. FUNCIÓN: approve_quotation_with_materials (VERSIÓN DEFINITIVA)
--    Aprueba cotización, crea factura y opcionalmente descuenta inventario.
--    Fuente: 013_fix_material_movements.sql (mejorada)
--    NOTA: Después de migración 028, usa material_id unificado (ya no inv_material_id)
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
    v_item RECORD;
    v_deduction_results JSONB := '[]'::JSONB;
    v_res JSONB;
BEGIN
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
    
    -- Descontar inventario si se solicita
    IF p_deduct_materials THEN
        FOR v_item IN SELECT * FROM quotation_items WHERE quotation_id = p_quotation_id LOOP
            IF v_item.product_id IS NOT NULL OR v_item.material_id IS NOT NULL THEN
                v_res := deduct_inventory_item(
                    v_item.material_id,
                    v_item.product_id,
                    v_item.quantity,
                    'COT-' || v_quotation.number,
                    v_item.name,
                    p_quotation_id,
                    NULL
                );
                v_deduction_results := v_deduction_results || v_res;
                
                -- Si alguna deducción falla, abortar
                IF NOT (v_res->>'success')::BOOLEAN THEN
                    RAISE EXCEPTION 'Error descontando inventario: %', v_res->>'error';
                END IF;
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
        quantity, 'UND', unit_price, 0, unit_price * quantity, 0, unit_price * quantity, material_id
    FROM quotation_items WHERE quotation_id = p_quotation_id;
    
    -- Actualizar estado
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
-- 4. FUNCIÓN: deduct_inventory_for_invoice (VERSIÓN DEFINITIVA)
--    Descuenta inventario para venta directa (sin cotización previa).
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
            v_item.material_id, v_item.product_id, v_item.quantity,
            v_invoice.series || '-' || v_invoice.number,
            v_item.product_name, NULL, p_invoice_id
        );
        v_results := v_results || v_res;
        
        IF NOT (v_res->>'success')::BOOLEAN THEN
            RAISE EXCEPTION 'Error descontando inventario: %', v_res->>'error';
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object('success', true, 'deductions', v_results);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. FUNCIÓN: check_quotation_stock (VERSIÓN DEFINITIVA)
--    Verificar disponibilidad de stock antes de aprobar cotización.
--    Usa tabla materials (unificada).
-- =====================================================
CREATE OR REPLACE FUNCTION check_quotation_stock(p_quotation_id UUID)
RETURNS TABLE (
    material_name VARCHAR,
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
        m.name::VARCHAR,
        m.code::VARCHAR,
        qi.quantity,
        COALESCE(m.stock, 0),
        m.unit::VARCHAR,
        COALESCE(m.stock, 0) >= qi.quantity,
        GREATEST(0, qi.quantity - COALESCE(m.stock, 0))
    FROM quotation_items qi
    JOIN materials m ON m.id = qi.material_id
    WHERE qi.quotation_id = p_quotation_id
    AND qi.material_id IS NOT NULL
    ORDER BY m.name;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. FUNCIÓN: revert_material_deduction (VERSIÓN DEFINITIVA)
--    Revertir descuentos de inventario al cancelar cotización.
-- =====================================================
CREATE OR REPLACE FUNCTION revert_material_deduction(p_quotation_id UUID)
RETURNS VOID AS $$
DECLARE
    v_movement RECORD;
BEGIN
    FOR v_movement IN 
        SELECT * FROM material_movements 
        WHERE quotation_id = p_quotation_id AND type = 'outgoing'
    LOOP
        UPDATE materials 
        SET stock = stock + v_movement.quantity, updated_at = NOW()
        WHERE id = v_movement.material_id;
        
        INSERT INTO material_movements (
            material_id, type, quantity, previous_stock, new_stock, 
            reason, reference, quotation_id
        ) VALUES (
            v_movement.material_id, 'incoming', v_movement.quantity,
            (SELECT stock - v_movement.quantity FROM materials WHERE id = v_movement.material_id),
            (SELECT stock FROM materials WHERE id = v_movement.material_id),
            'Reversión: Cotización cancelada', v_movement.reference, p_quotation_id
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. FUNCIÓN: calculate_payroll_totals (VERSIÓN DEFINITIVA)
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_payroll_totals(p_payroll_id UUID)
RETURNS void AS $$
DECLARE
    v_base_salary DECIMAL(12,2);
    v_extra_earnings DECIMAL(12,2);
    v_total_deductions DECIMAL(12,2);
BEGIN
    SELECT COALESCE(base_salary, 0) INTO v_base_salary
    FROM payroll WHERE id = p_payroll_id;
    
    SELECT COALESCE(SUM(amount), 0) INTO v_extra_earnings
    FROM payroll_details
    WHERE payroll_id = p_payroll_id AND type = 'ingreso';
    
    SELECT COALESCE(SUM(amount), 0) INTO v_total_deductions
    FROM payroll_details
    WHERE payroll_id = p_payroll_id AND type = 'descuento';
    
    UPDATE payroll
    SET total_earnings = v_base_salary + v_extra_earnings,
        total_deductions = v_total_deductions,
        net_pay = (v_base_salary + v_extra_earnings) - v_total_deductions,
        updated_at = NOW()
    WHERE id = p_payroll_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. PERMISOS
-- =====================================================
GRANT EXECUTE ON FUNCTION deduct_inventory_item TO authenticated;
GRANT EXECUTE ON FUNCTION approve_quotation_with_materials TO authenticated;
GRANT EXECUTE ON FUNCTION deduct_inventory_for_invoice TO authenticated;
GRANT EXECUTE ON FUNCTION check_quotation_stock TO authenticated;
GRANT EXECUTE ON FUNCTION revert_material_deduction TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_payroll_totals TO authenticated;
-- register_payroll_payment y register_employee_loan mantienen sus permisos existentes

COMMENT ON FUNCTION deduct_inventory_item IS 'Descontar material/producto del inventario. Soporta materiales directos, recetas y productos simples.';
COMMENT ON FUNCTION approve_quotation_with_materials IS 'Aprobar cotización → crear factura y opcionalmente descontar inventario.';
COMMENT ON FUNCTION deduct_inventory_for_invoice IS 'Descontar inventario para venta directa (sin cotización).';
COMMENT ON FUNCTION check_quotation_stock IS 'Verificar disponibilidad de stock antes de aprobar cotización.';
COMMENT ON FUNCTION calculate_payroll_totals IS 'Recalcular totales de nómina: base_salary + ingresos - descuentos.';
