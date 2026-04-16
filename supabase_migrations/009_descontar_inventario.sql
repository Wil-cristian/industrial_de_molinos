-- =====================================================
-- DESCONTAR MATERIALES DEL INVENTARIO AL APROBAR COTIZACIÓN
-- Industrial de Molinos
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. CREAR TABLA DE MOVIMIENTOS DE MATERIALES (si no existe)
-- =====================================================
CREATE TABLE IF NOT EXISTS material_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    material_id UUID NOT NULL REFERENCES materials(id),
    type VARCHAR(20) NOT NULL, -- 'incoming', 'outgoing', 'adjustment'
    quantity DECIMAL(12,4) NOT NULL,
    previous_stock DECIMAL(12,4),
    new_stock DECIMAL(12,4),
    reason VARCHAR(200),
    reference VARCHAR(100), -- Número de cotización/factura
    quotation_id UUID REFERENCES quotations(id),
    invoice_id UUID REFERENCES invoices(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_material_movements_material ON material_movements(material_id);
CREATE INDEX IF NOT EXISTS idx_material_movements_date ON material_movements(created_at);

-- =====================================================
-- 2. AGREGAR material_id A quotation_items (para rastrear material real)
-- =====================================================
DO $$ BEGIN
    ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS material_id UUID REFERENCES materials(id);
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS material_name VARCHAR(100);
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS material_id UUID REFERENCES materials(id);
EXCEPTION WHEN others THEN null;
END $$;

-- =====================================================
-- 3. FUNCIÓN: DESCONTAR MATERIALES DEL INVENTARIO
-- =====================================================
CREATE OR REPLACE FUNCTION deduct_materials_for_quotation(p_quotation_id UUID)
RETURNS TABLE (
    material_name VARCHAR,
    material_code VARCHAR,
    quantity_used DECIMAL,
    previous_stock DECIMAL,
    new_stock DECIMAL,
    unit VARCHAR,
    success BOOLEAN,
    message VARCHAR
) AS $$
DECLARE
    v_item RECORD;
    v_current_stock DECIMAL;
    v_quotation_number VARCHAR;
BEGIN
    -- Obtener número de cotización
    SELECT 'COT-' || series || '-' || number INTO v_quotation_number 
    FROM quotations WHERE id = p_quotation_id;
    
    -- Procesar cada item de la cotización que tenga material_id
    FOR v_item IN 
        SELECT 
            qi.id,
            qi.material_id,
            qi.quantity,
            qi.name as item_name,
            m.code as mat_code,
            m.name as mat_name,
            m.stock as mat_stock,
            m.unit as mat_unit
        FROM quotation_items qi
        LEFT JOIN materials m ON m.id = qi.material_id
        WHERE qi.quotation_id = p_quotation_id 
        AND qi.material_id IS NOT NULL
    LOOP
        v_current_stock := COALESCE(v_item.mat_stock, 0);
        
        -- Verificar stock suficiente
        IF v_current_stock >= v_item.quantity THEN
            -- Registrar movimiento
            INSERT INTO material_movements (
                material_id, type, quantity, 
                previous_stock, new_stock, 
                reason, reference, quotation_id
            ) VALUES (
                v_item.material_id, 'outgoing', v_item.quantity,
                v_current_stock, v_current_stock - v_item.quantity,
                'Producción: ' || v_item.item_name, v_quotation_number, p_quotation_id
            );
            
            -- Actualizar stock del material
            UPDATE materials 
            SET stock = stock - v_item.quantity, updated_at = NOW()
            WHERE id = v_item.material_id;
            
            material_name := v_item.mat_name;
            material_code := v_item.mat_code;
            quantity_used := v_item.quantity;
            previous_stock := v_current_stock;
            new_stock := v_current_stock - v_item.quantity;
            unit := v_item.mat_unit;
            success := true;
            message := 'Descontado correctamente';
            RETURN NEXT;
        ELSE
            -- Stock insuficiente - reportar pero no fallar
            material_name := v_item.mat_name;
            material_code := v_item.mat_code;
            quantity_used := v_item.quantity;
            previous_stock := v_current_stock;
            new_stock := v_current_stock; -- No cambia
            unit := v_item.mat_unit;
            success := false;
            message := 'STOCK INSUFICIENTE: Necesita ' || v_item.quantity || ', disponible ' || v_current_stock;
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. FUNCIÓN: APROBAR COTIZACIÓN CON DESCUENTO DE MATERIALES
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
    v_deduction_results JSON;
BEGIN
    -- Obtener datos de la cotización
    SELECT * INTO v_quotation FROM quotations WHERE id = p_quotation_id;
    
    IF v_quotation IS NULL THEN
        RAISE EXCEPTION 'Cotización no encontrada';
    END IF;
    
    IF v_quotation.status = 'Aprobada' THEN
        RAISE EXCEPTION 'La cotización ya fue aprobada';
    END IF;
    
    -- Descontar materiales si se solicita
    IF p_deduct_materials THEN
        SELECT json_agg(row_to_json(t)) INTO v_deduction_results
        FROM deduct_materials_for_quotation(p_quotation_id) t;
    END IF;
    
    -- Generar número de factura
    SELECT LPAD((COALESCE(MAX(CAST(NULLIF(number, '') AS INTEGER)), 0) + 1)::TEXT, 5, '0') 
    INTO v_invoice_number
    FROM invoices WHERE series = p_series;
    
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
        v_quotation.subtotal, v_quotation.tax_rate, v_quotation.tax_amount, v_quotation.discount, v_quotation.total,
        0, 'pendiente', p_quotation_id, v_quotation.notes
    ) RETURNING id INTO v_invoice_id;
    
    -- Copiar items de la cotización a la factura
    INSERT INTO invoice_items (invoice_id, name, description, quantity, unit_price, unit_weight, price_per_kg, discount, total_price, material_id)
    SELECT v_invoice_id, name, description, quantity, unit_price, unit_weight, price_per_kg, discount, total_price, material_id
    FROM quotation_items WHERE quotation_id = p_quotation_id;
    
    -- Actualizar estado de la cotización
    UPDATE quotations SET status = 'Aprobada', updated_at = NOW()
    WHERE id = p_quotation_id;
    
    RETURN json_build_object(
        'invoice_id', v_invoice_id,
        'invoice_number', p_series || '-' || v_invoice_number,
        'materials_deducted', v_deduction_results
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. FUNCIÓN: VERIFICAR STOCK ANTES DE APROBAR
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
-- 6. FUNCIÓN: REVERTIR DESCUENTO (si se cancela cotización)
-- =====================================================
CREATE OR REPLACE FUNCTION revert_material_deduction(p_quotation_id UUID)
RETURNS VOID AS $$
DECLARE
    v_movement RECORD;
BEGIN
    -- Buscar movimientos de esta cotización
    FOR v_movement IN 
        SELECT * FROM material_movements 
        WHERE quotation_id = p_quotation_id AND type = 'outgoing'
    LOOP
        -- Devolver stock
        UPDATE materials 
        SET stock = stock + v_movement.quantity, updated_at = NOW()
        WHERE id = v_movement.material_id;
        
        -- Registrar movimiento de devolución
        INSERT INTO material_movements (
            material_id, type, quantity, 
            previous_stock, new_stock, 
            reason, reference, quotation_id
        ) VALUES (
            v_movement.material_id, 'incoming', v_movement.quantity,
            (SELECT stock - v_movement.quantity FROM materials WHERE id = v_movement.material_id),
            (SELECT stock FROM materials WHERE id = v_movement.material_id),
            'Reversión: Cotización cancelada', v_movement.reference, p_quotation_id
        );
    END LOOP;
    
    -- Marcar movimientos originales como revertidos (opcional)
    UPDATE material_movements 
    SET reason = reason || ' [REVERTIDO]'
    WHERE quotation_id = p_quotation_id AND type = 'outgoing';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. PERMISOS
-- =====================================================
GRANT ALL ON material_movements TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION deduct_materials_for_quotation TO anon, authenticated;
GRANT EXECUTE ON FUNCTION approve_quotation_with_materials TO anon, authenticated;
GRANT EXECUTE ON FUNCTION check_quotation_stock TO anon, authenticated;
GRANT EXECUTE ON FUNCTION revert_material_deduction TO anon, authenticated;

-- Reload schema
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- 8. VERIFICACIÓN
-- =====================================================
SELECT '✅ Sistema de descuento de materiales configurado!' as resultado;
SELECT 'Funciones creadas:' as info;
SELECT '  - deduct_materials_for_quotation(quotation_id)' as funcion1;
SELECT '  - approve_quotation_with_materials(quotation_id, series, deduct_materials)' as funcion2;
SELECT '  - check_quotation_stock(quotation_id)' as funcion3;
SELECT '  - revert_material_deduction(quotation_id)' as funcion4;
