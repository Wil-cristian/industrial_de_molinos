-- =====================================================
-- SETUP COMPLETO - SISTEMA DE VENTAS
-- Industrial de Molinos
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. CREAR ENUM TYPES SI NO EXISTEN
-- =====================================================
DO $$ BEGIN
    CREATE TYPE invoice_status AS ENUM ('draft', 'issued', 'paid', 'partial', 'cancelled', 'overdue');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_method AS ENUM ('cash', 'card', 'transfer', 'credit', 'check', 'yape', 'plin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- =====================================================
-- 2. TABLA DE PAGOS (payments)
-- =====================================================
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL,
    method payment_method DEFAULT 'cash',
    reference VARCHAR(100),
    notes TEXT,
    payment_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para payments
CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date);

-- =====================================================
-- 3. TABLA DE MOVIMIENTOS DE STOCK
-- =====================================================
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('incoming', 'outgoing', 'adjustment')),
    quantity DECIMAL(12,2) NOT NULL,
    previous_stock DECIMAL(12,2) DEFAULT 0,
    new_stock DECIMAL(12,2) DEFAULT 0,
    reason VARCHAR(200),
    reference VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para stock_movements
CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(created_at);

-- =====================================================
-- 4. AGREGAR COLUMNAS FALTANTES A invoices
-- =====================================================
DO $$ BEGIN
    ALTER TABLE invoices ADD COLUMN IF NOT EXISTS quotation_id UUID REFERENCES quotations(id);
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE invoices ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5,2) DEFAULT 18.00;
EXCEPTION WHEN others THEN null;
END $$;

-- =====================================================
-- 5. AGREGAR COLUMNAS FALTANTES A invoice_items
-- =====================================================
DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id);
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS product_code VARCHAR(50);
EXCEPTION WHEN others THEN null;
END $$;

-- =====================================================
-- 6. AGREGAR COLUMNAS FALTANTES A quotation_items
-- =====================================================
DO $$ BEGIN
    ALTER TABLE quotation_items ADD COLUMN IF NOT EXISTS material_id UUID REFERENCES products(id);
EXCEPTION WHEN others THEN null;
END $$;

-- =====================================================
-- 7. FUNCIÓN: APROBAR COTIZACIÓN Y CREAR FACTURA
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
    
    -- Crear la factura
    INSERT INTO invoices (
        type, series, number,
        customer_id, customer_name, customer_document,
        issue_date, due_date,
        subtotal, tax_rate, tax_amount, discount, total,
        paid_amount, status, quotation_id, notes
    ) VALUES (
        'invoice', p_series, v_invoice_number,
        v_quotation.customer_id, v_quotation.customer_name, COALESCE(v_quotation.customer_document, ''),
        CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days',
        v_quotation.subtotal, 18.00, v_quotation.total * 0.18 / 1.18, 0, v_quotation.total,
        0, 'issued', p_quotation_id, v_quotation.notes
    ) RETURNING id INTO v_invoice_id;
    
    -- Copiar items de cotización a factura
    INSERT INTO invoice_items (
        invoice_id, product_id, product_code, product_name, description,
        quantity, unit, unit_price, subtotal, tax_amount, total, sort_order
    )
    SELECT 
        v_invoice_id,
        qi.material_id,
        COALESCE(qi.material_name, 'ITEM'),
        qi.name,
        qi.description,
        qi.quantity,
        'UND',
        qi.unit_price,
        qi.total_price / 1.18,
        qi.total_price * 0.18 / 1.18,
        qi.total_price,
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
-- 8. FUNCIÓN: DESCONTAR STOCK
-- =====================================================
CREATE OR REPLACE FUNCTION deduct_stock_for_invoice(p_invoice_id UUID)
RETURNS VOID AS $$
DECLARE
    v_item RECORD;
    v_current_stock DECIMAL;
BEGIN
    FOR v_item IN 
        SELECT ii.product_id, ii.quantity, i.series || '-' || i.number as inv_number
        FROM invoice_items ii 
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE ii.invoice_id = p_invoice_id AND ii.product_id IS NOT NULL
    LOOP
        -- Obtener stock actual
        SELECT stock INTO v_current_stock FROM products WHERE id = v_item.product_id;
        
        IF v_current_stock IS NOT NULL THEN
            -- Registrar movimiento de stock
            INSERT INTO stock_movements (product_id, type, quantity, previous_stock, new_stock, reason, reference)
            VALUES (v_item.product_id, 'outgoing', v_item.quantity, v_current_stock, v_current_stock - v_item.quantity, 'Venta', v_item.inv_number);
            
            -- Actualizar stock del producto
            UPDATE products SET stock = stock - v_item.quantity, updated_at = NOW()
            WHERE id = v_item.product_id;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 9. FUNCIÓN: REGISTRAR PAGO
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
    
    IF v_invoice.status::TEXT = 'paid' THEN
        RAISE EXCEPTION 'La factura ya está pagada';
    END IF;
    
    IF v_invoice.status::TEXT = 'cancelled' THEN
        RAISE EXCEPTION 'La factura está cancelada';
    END IF;
    
    -- Crear pago
    INSERT INTO payments (invoice_id, amount, method, reference, notes, payment_date)
    VALUES (p_invoice_id, p_amount, p_method::payment_method, p_reference, p_notes, CURRENT_DATE)
    RETURNING id INTO v_payment_id;
    
    -- Calcular nuevo monto pagado
    v_new_paid_amount := COALESCE(v_invoice.paid_amount, 0) + p_amount;
    
    -- Determinar nuevo estado
    IF v_new_paid_amount >= v_invoice.total THEN
        v_new_status := 'paid';
    ELSE
        v_new_status := 'partial';
    END IF;
    
    -- Actualizar factura
    UPDATE invoices 
    SET paid_amount = v_new_paid_amount, 
        status = v_new_status::invoice_status, 
        payment_method = p_method::payment_method,
        updated_at = NOW()
    WHERE id = p_invoice_id;
    
    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 10. FUNCIÓN: VERIFICAR STOCK
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
-- 11. FUNCIÓN: RECHAZAR COTIZACIÓN
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
-- 12. FUNCIÓN: RESUMEN DE VENTAS
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
        COALESCE(SUM(i.total), 0)::DECIMAL,
        COALESCE(SUM(i.paid_amount), 0)::DECIMAL,
        COALESCE(SUM(i.total - i.paid_amount), 0)::DECIMAL,
        COUNT(*)::BIGINT,
        COUNT(*) FILTER (WHERE i.status::TEXT = 'paid')::BIGINT,
        COUNT(*) FILTER (WHERE i.status::TEXT IN ('issued', 'partial'))::BIGINT,
        COUNT(*) FILTER (WHERE i.due_date < CURRENT_DATE AND i.status::TEXT NOT IN ('paid', 'cancelled'))::BIGINT
    FROM invoices i
    WHERE i.status::TEXT != 'cancelled'
    AND (p_start_date IS NULL OR i.issue_date >= p_start_date)
    AND (p_end_date IS NULL OR i.issue_date <= p_end_date);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 13. PERMISOS
-- =====================================================
GRANT ALL ON payments TO anon, authenticated, service_role;
GRANT ALL ON stock_movements TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION approve_quotation_and_create_invoice TO anon, authenticated;
GRANT EXECUTE ON FUNCTION deduct_stock_for_invoice TO anon, authenticated;
GRANT EXECUTE ON FUNCTION register_payment TO anon, authenticated;
GRANT EXECUTE ON FUNCTION check_stock_availability TO anon, authenticated;
GRANT EXECUTE ON FUNCTION reject_quotation TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_sales_summary TO anon, authenticated;

-- Reload schema para que PostgREST reconozca las funciones
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- 14. VERIFICACIÓN
-- =====================================================
SELECT '✅ Setup completo ejecutado!' as resultado;
SELECT 'Tablas:' as info;
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('payments', 'stock_movements', 'invoices', 'quotations');
SELECT 'Funciones:' as info;
SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE '%quotation%' OR routine_name LIKE '%payment%' OR routine_name LIKE '%stock%' OR routine_name LIKE '%sales%';
