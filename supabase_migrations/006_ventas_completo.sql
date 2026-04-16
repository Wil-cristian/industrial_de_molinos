-- =====================================================
-- SISTEMA DE VENTAS COMPLETO
-- Industrial de Molinos
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. FUNCIÓN PARA APROBAR COTIZACIÓN Y CREAR FACTURA
-- =====================================================
CREATE OR REPLACE FUNCTION approve_quotation_and_create_invoice(
    p_quotation_id UUID,
    p_series VARCHAR DEFAULT 'F001'
)
RETURNS UUID AS $$
DECLARE
    v_quotation RECORD;
    v_invoice_id UUID;
    v_invoice_number VARCHAR;
    v_item RECORD;
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
    SELECT COALESCE(MAX(CAST(number AS INTEGER)), 0) + 1 INTO v_invoice_number
    FROM invoices WHERE series = p_series;
    v_invoice_number := LPAD(v_invoice_number::TEXT, 5, '0');
    
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
        v_quotation.subtotal, 18.00, v_quotation.total * 0.18, 0, v_quotation.total,
        0, 'issued', p_quotation_id, v_quotation.notes
    ) RETURNING id INTO v_invoice_id;
    
    -- Copiar items de cotización a factura
    INSERT INTO invoice_items (
        invoice_id, product_code, product_name, description,
        quantity, unit, unit_price, subtotal, tax_amount, total, sort_order
    )
    SELECT 
        v_invoice_id,
        COALESCE(qi.material_name, 'ITEM'),
        qi.name,
        qi.description,
        qi.quantity,
        'UND',
        qi.unit_price,
        qi.total_price,
        qi.total_price * 0.18,
        qi.total_price * 1.18,
        qi.sort_order
    FROM quotation_items qi
    WHERE qi.quotation_id = p_quotation_id;
    
    -- Actualizar estado de cotización
    UPDATE quotations SET status = 'Aprobada', updated_at = NOW()
    WHERE id = p_quotation_id;
    
    RETURN v_invoice_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. FUNCIÓN PARA DESCONTAR STOCK
-- =====================================================
CREATE OR REPLACE FUNCTION deduct_stock_for_invoice(p_invoice_id UUID)
RETURNS VOID AS $$
DECLARE
    v_item RECORD;
BEGIN
    FOR v_item IN 
        SELECT ii.*, ii.product_id 
        FROM invoice_items ii 
        WHERE ii.invoice_id = p_invoice_id AND ii.product_id IS NOT NULL
    LOOP
        -- Registrar movimiento de stock
        INSERT INTO stock_movements (
            product_id, type, quantity, 
            previous_stock, new_stock, 
            reason, reference
        )
        SELECT 
            v_item.product_id,
            'outgoing',
            v_item.quantity,
            p.stock,
            p.stock - v_item.quantity,
            'Venta - Factura',
            (SELECT full_number FROM invoices WHERE id = p_invoice_id)
        FROM products p WHERE p.id = v_item.product_id;
        
        -- Actualizar stock del producto
        UPDATE products 
        SET stock = stock - v_item.quantity, updated_at = NOW()
        WHERE id = v_item.product_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. FUNCIÓN PARA REGISTRAR PAGO
-- =====================================================
CREATE OR REPLACE FUNCTION register_payment(
    p_invoice_id UUID,
    p_amount DECIMAL,
    p_method VARCHAR DEFAULT 'cash',
    p_reference VARCHAR DEFAULT NULL,
    p_notes VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_payment_id UUID;
    v_invoice RECORD;
    v_new_paid_amount DECIMAL;
    v_new_status VARCHAR;
BEGIN
    -- Obtener factura
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    
    IF v_invoice IS NULL THEN
        RAISE EXCEPTION 'Factura no encontrada';
    END IF;
    
    IF v_invoice.status = 'paid' THEN
        RAISE EXCEPTION 'La factura ya está pagada';
    END IF;
    
    IF v_invoice.status = 'cancelled' THEN
        RAISE EXCEPTION 'La factura está cancelada';
    END IF;
    
    -- Crear pago
    INSERT INTO payments (invoice_id, amount, method, reference, notes, payment_date)
    VALUES (p_invoice_id, p_amount, p_method::payment_method, p_reference, p_notes, CURRENT_DATE)
    RETURNING id INTO v_payment_id;
    
    -- Calcular nuevo monto pagado
    v_new_paid_amount := v_invoice.paid_amount + p_amount;
    
    -- Determinar nuevo estado
    IF v_new_paid_amount >= v_invoice.total THEN
        v_new_status := 'paid';
    ELSE
        v_new_status := 'partial';
    END IF;
    
    -- Actualizar factura
    UPDATE invoices 
    SET paid_amount = v_new_paid_amount, status = v_new_status::invoice_status, updated_at = NOW()
    WHERE id = p_invoice_id;
    
    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. FUNCIÓN PARA VERIFICAR STOCK DISPONIBLE
-- =====================================================
CREATE OR REPLACE FUNCTION check_stock_availability(p_quotation_id UUID)
RETURNS TABLE (
    item_name VARCHAR,
    product_id UUID,
    required_qty DECIMAL,
    available_stock DECIMAL,
    has_stock BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        qi.name::VARCHAR,
        qi.material_id,
        qi.quantity::DECIMAL,
        COALESCE(p.stock, 0)::DECIMAL,
        COALESCE(p.stock, 0) >= qi.quantity
    FROM quotation_items qi
    LEFT JOIN products p ON p.id = qi.material_id
    WHERE qi.quotation_id = p_quotation_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. FUNCIÓN PARA RECHAZAR COTIZACIÓN
-- =====================================================
CREATE OR REPLACE FUNCTION reject_quotation(
    p_quotation_id UUID,
    p_reason VARCHAR DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE quotations 
    SET status = 'Rechazada', 
        notes = CASE WHEN p_reason IS NOT NULL 
                     THEN COALESCE(notes, '') || E'\n[RECHAZADA] ' || p_reason 
                     ELSE notes END,
        updated_at = NOW()
    WHERE id = p_quotation_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. FUNCIÓN PARA OBTENER RESUMEN DE VENTAS
-- =====================================================
CREATE OR REPLACE FUNCTION get_sales_summary(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    total_sales DECIMAL,
    total_paid DECIMAL,
    total_pending DECIMAL,
    total_count BIGINT,
    paid_count BIGINT,
    pending_count BIGINT,
    overdue_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(total), 0)::DECIMAL,
        COALESCE(SUM(paid_amount), 0)::DECIMAL,
        COALESCE(SUM(total - paid_amount), 0)::DECIMAL,
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE status = 'paid')::BIGINT,
        COUNT(*) FILTER (WHERE status IN ('issued', 'partial'))::BIGINT,
        COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND status NOT IN ('paid', 'cancelled'))::BIGINT
    FROM invoices
    WHERE status != 'cancelled'
    AND (p_start_date IS NULL OR issue_date >= p_start_date)
    AND (p_end_date IS NULL OR issue_date <= p_end_date);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. VISTA PARA COTIZACIONES CON ESTADO DE STOCK
-- =====================================================
CREATE OR REPLACE VIEW quotations_with_stock AS
SELECT 
    q.*,
    (SELECT COUNT(*) FROM quotation_items qi 
     LEFT JOIN products p ON p.id = qi.material_id 
     WHERE qi.quotation_id = q.id AND (p.stock IS NULL OR p.stock < qi.quantity)) as items_without_stock,
    (SELECT COUNT(*) FROM quotation_items WHERE quotation_id = q.id) as total_items
FROM quotations q;

-- =====================================================
-- 8. AGREGAR COLUMNA product_id A invoice_items SI NO EXISTE
-- =====================================================
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoice_items' AND column_name = 'product_id') THEN
        ALTER TABLE invoice_items ADD COLUMN product_id UUID REFERENCES products(id);
    END IF;
END $$;

-- =====================================================
-- 9. PERMISOS
-- =====================================================
GRANT EXECUTE ON FUNCTION approve_quotation_and_create_invoice TO anon, authenticated;
GRANT EXECUTE ON FUNCTION deduct_stock_for_invoice TO anon, authenticated;
GRANT EXECUTE ON FUNCTION register_payment TO anon, authenticated;
GRANT EXECUTE ON FUNCTION check_stock_availability TO anon, authenticated;
GRANT EXECUTE ON FUNCTION reject_quotation TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_sales_summary TO anon, authenticated;

-- Reload schema
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
SELECT 'Funciones creadas:' as info;
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
    'approve_quotation_and_create_invoice',
    'deduct_stock_for_invoice', 
    'register_payment',
    'check_stock_availability',
    'reject_quotation',
    'get_sales_summary'
);

SELECT '✅ Sistema de ventas listo!' as resultado;
