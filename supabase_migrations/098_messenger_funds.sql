-- ============================================
-- MIGRACIÓN 098: Fondos de Mensajería
-- Sistema de anticipos para mensajeros (Fondo Fijo)
-- NO afecta contabilidad como gasto, es un activo en tránsito
-- ============================================

-- 1. Cuenta contable para Fondos de Mensajería (Activo)
INSERT INTO chart_of_accounts (code, name, type, parent_code, level, accepts_entries, is_active)
VALUES ('142', 'Fondos de Mensajería', 'asset', '14', 3, TRUE, TRUE)
ON CONFLICT (code) DO NOTHING;

-- 2. Tabla principal: messenger_funds (cada entrega de dinero)
CREATE TABLE IF NOT EXISTS messenger_funds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Quién recibe el fondo
    employee_id UUID NOT NULL REFERENCES employees(id),
    employee_name VARCHAR(200) NOT NULL,
    
    -- Montos
    amount_given DECIMAL(12,2) NOT NULL CHECK (amount_given > 0),
    amount_spent DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (amount_spent >= 0),
    amount_returned DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (amount_returned >= 0),
    
    -- De dónde salió el dinero
    account_id UUID NOT NULL REFERENCES accounts(id),
    cash_movement_id UUID REFERENCES cash_movements(id),
    
    -- Estado
    status VARCHAR(20) NOT NULL DEFAULT 'abierto' 
        CHECK (status IN ('abierto', 'parcial', 'legalizado', 'cancelado')),
    
    -- Fechas
    date_given DATE NOT NULL DEFAULT CURRENT_DATE,
    date_legalized DATE,
    
    -- Notas
    notes TEXT,
    
    -- Auditoría
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Tabla detalle: messenger_fund_items (cada recibo/comprobante)
CREATE TABLE IF NOT EXISTS messenger_fund_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id UUID NOT NULL REFERENCES messenger_funds(id) ON DELETE CASCADE,
    
    -- Tipo de gasto/legalización
    item_type VARCHAR(30) NOT NULL 
        CHECK (item_type IN ('compra', 'pago_factura', 'gasto', 'devolucion')),
    
    -- Monto
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    
    -- Descripción y referencia
    description VARCHAR(500) NOT NULL,
    reference VARCHAR(100),  -- Número de factura, recibo, etc.
    
    -- Categoría de gasto (para contabilidad)
    category VARCHAR(30) DEFAULT 'consumibles',
    
    -- Links opcionales a otros módulos
    purchase_order_id UUID REFERENCES purchase_orders(id),
    invoice_id UUID,  -- No FK porque puede ser factura proveedor
    
    -- Adjuntos (foto del recibo)
    attachment_url TEXT,
    attachment_name VARCHAR(255),
    
    -- Auditoría
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Índices
CREATE INDEX IF NOT EXISTS idx_messenger_funds_employee ON messenger_funds(employee_id);
CREATE INDEX IF NOT EXISTS idx_messenger_funds_status ON messenger_funds(status);
CREATE INDEX IF NOT EXISTS idx_messenger_funds_date ON messenger_funds(date_given);
CREATE INDEX IF NOT EXISTS idx_messenger_fund_items_fund ON messenger_fund_items(fund_id);

-- 5. RLS Policies
ALTER TABLE messenger_funds ENABLE ROW LEVEL SECURITY;
ALTER TABLE messenger_fund_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messenger_funds_all" ON messenger_funds FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "messenger_fund_items_all" ON messenger_fund_items FOR ALL USING (true) WITH CHECK (true);

-- 6. Función RPC: Crear fondo (atómica: crea fondo + movimiento + actualiza balance)
CREATE OR REPLACE FUNCTION create_messenger_fund(
    p_employee_id UUID,
    p_employee_name TEXT,
    p_amount DECIMAL,
    p_account_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_fund_id UUID;
    v_movement_id UUID;
    v_account_balance DECIMAL;
    v_account_name TEXT;
BEGIN
    -- Obtener saldo actual y nombre de cuenta
    SELECT balance, name INTO v_account_balance, v_account_name
    FROM accounts WHERE id = p_account_id FOR UPDATE;
    
    IF v_account_balance < p_amount THEN
        RAISE EXCEPTION 'Saldo insuficiente en la cuenta. Disponible: %', v_account_balance;
    END IF;
    
    -- Crear movimiento de caja (tipo expense pero categoría especial fondo_mensajero)
    v_movement_id := gen_random_uuid();
    INSERT INTO cash_movements (id, account_id, type, category, amount, description, reference, person_name, date, created_at)
    VALUES (
        v_movement_id,
        p_account_id,
        'expense',
        'fondo_mensajero',
        p_amount,
        'Fondo mensajería - ' || p_employee_name,
        NULL,
        p_employee_name,
        CURRENT_DATE,
        NOW()
    );
    
    -- Actualizar saldo de cuenta
    UPDATE accounts SET balance = balance - p_amount, updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Crear registro de fondo
    v_fund_id := gen_random_uuid();
    INSERT INTO messenger_funds (id, employee_id, employee_name, amount_given, account_id, cash_movement_id, notes)
    VALUES (v_fund_id, p_employee_id, p_employee_name, p_amount, p_account_id, v_movement_id, p_notes);
    
    RETURN v_fund_id;
END;
$$ LANGUAGE plpgsql;

-- 7. Función RPC: Legalizar item (registra un gasto del fondo)
CREATE OR REPLACE FUNCTION legalize_fund_item(
    p_fund_id UUID,
    p_item_type VARCHAR,
    p_amount DECIMAL,
    p_description TEXT,
    p_reference TEXT DEFAULT NULL,
    p_category VARCHAR DEFAULT 'consumibles',
    p_purchase_order_id UUID DEFAULT NULL,
    p_invoice_id UUID DEFAULT NULL,
    p_attachment_url TEXT DEFAULT NULL,
    p_attachment_name TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_item_id UUID;
    v_fund RECORD;
    v_remaining DECIMAL;
    v_debit_code VARCHAR(20);
    v_debit_name VARCHAR(255);
    v_lines JSONB;
    v_total DECIMAL;
    v_paid DECIMAL;
    v_new_paid DECIMAL;
    v_new_status VARCHAR(20);
BEGIN
    -- Obtener fondo con lock
    SELECT * INTO v_fund FROM messenger_funds WHERE id = p_fund_id FOR UPDATE;
    
    IF v_fund IS NULL THEN
        RAISE EXCEPTION 'Fondo no encontrado';
    END IF;
    
    IF v_fund.status IN ('legalizado', 'cancelado') THEN
        RAISE EXCEPTION 'El fondo ya está % y no acepta más items', v_fund.status;
    END IF;
    
    -- Verificar que no se exceda el monto dado
    v_remaining := v_fund.amount_given - v_fund.amount_spent - v_fund.amount_returned;
    IF p_amount > v_remaining THEN
        RAISE EXCEPTION 'Monto excede el saldo disponible del fondo. Disponible: %', v_remaining;
    END IF;
    
    -- Crear item
    v_item_id := gen_random_uuid();
    INSERT INTO messenger_fund_items (id, fund_id, item_type, amount, description, reference, category, purchase_order_id, invoice_id, attachment_url, attachment_name)
    VALUES (v_item_id, p_fund_id, p_item_type, p_amount, p_description, p_reference, p_category, p_purchase_order_id, p_invoice_id, p_attachment_url, p_attachment_name);
    
    -- Actualizar totales del fondo
    IF p_item_type = 'devolucion' THEN
        UPDATE messenger_funds SET 
            amount_returned = amount_returned + p_amount,
            status = CASE 
                WHEN (amount_spent + p_amount + amount_returned) >= amount_given THEN 'legalizado'
                ELSE 'parcial'
            END,
            date_legalized = CASE 
                WHEN (amount_spent + p_amount + amount_returned) >= amount_given THEN CURRENT_DATE
                ELSE date_legalized
            END,
            updated_at = NOW()
        WHERE id = p_fund_id;
        
        -- Devolver dinero a la cuenta original
        UPDATE accounts SET balance = balance + p_amount, updated_at = NOW()
        WHERE id = v_fund.account_id;
        
        -- Crear movimiento de ingreso por la devolución
        INSERT INTO cash_movements (id, account_id, type, category, amount, description, person_name, date, created_at)
        VALUES (
            gen_random_uuid(),
            v_fund.account_id,
            'income',
            'devolucion_fondo',
            p_amount,
            'Devolución fondo mensajería - ' || v_fund.employee_name,
            v_fund.employee_name,
            CURRENT_DATE,
            NOW()
        );
    ELSE
        UPDATE messenger_funds SET 
            amount_spent = amount_spent + p_amount,
            status = CASE 
                WHEN (amount_spent + p_amount + amount_returned) >= amount_given THEN 'legalizado'
                ELSE 'parcial'
            END,
            date_legalized = CASE 
                WHEN (amount_spent + p_amount + amount_returned) >= amount_given THEN CURRENT_DATE
                ELSE date_legalized
            END,
            updated_at = NOW()
        WHERE id = p_fund_id;

        -- Si se vinculó a una factura del sistema, registrar pago SIN tocar caja otra vez.
        IF p_invoice_id IS NOT NULL THEN
            SELECT total, COALESCE(paid_amount, 0)
              INTO v_total, v_paid
            FROM invoices
            WHERE id = p_invoice_id
            FOR UPDATE;

            IF v_total IS NOT NULL THEN
                v_new_paid := COALESCE(v_paid, 0) + p_amount;
                v_new_status := CASE
                    WHEN v_new_paid >= v_total THEN 'paid'
                    WHEN v_new_paid > 0 THEN 'partial'
                    ELSE 'issued'
                END;

                INSERT INTO payments (invoice_id, amount, method, reference, notes, payment_date)
                VALUES (
                    p_invoice_id,
                    p_amount,
                    'messenger_fund',
                    p_reference,
                    'Pago aplicado desde fondo de mensajería',
                    CURRENT_DATE
                );

                UPDATE invoices
                SET paid_amount = v_new_paid,
                    status = v_new_status,
                    payment_method = 'messenger_fund',
                    updated_at = NOW()
                WHERE id = p_invoice_id;
            END IF;
        END IF;

        -- Si se vinculó a una orden de compra, actualizar su estado de pago.
        IF p_purchase_order_id IS NOT NULL THEN
            SELECT total, COALESCE(amount_paid, 0)
              INTO v_total, v_paid
            FROM purchase_orders
            WHERE id = p_purchase_order_id
            FOR UPDATE;

            IF v_total IS NOT NULL THEN
                v_new_paid := COALESCE(v_paid, 0) + p_amount;
                v_new_status := CASE
                    WHEN v_new_paid >= v_total THEN 'pagada'
                    WHEN v_new_paid > 0 THEN 'parcial'
                    ELSE 'pendiente'
                END;

                UPDATE purchase_orders
                SET amount_paid = v_new_paid,
                    payment_status = v_new_status,
                    payment_method = 'messenger_fund',
                    updated_at = NOW()
                WHERE id = p_purchase_order_id;
            END IF;
        END IF;

        -- Crear asiento contable de legalización SIN volver a tocar caja.
        -- Se descarga el activo 142 y se lleva al gasto/pasivo correcto.
        IF p_item_type = 'pago_factura' THEN
            v_debit_code := '421';
            v_debit_name := 'Proveedores';
        ELSIF p_category = 'consumibles' THEN
            v_debit_code := '601';
            v_debit_name := 'Compra de Materiales';
        ELSIF p_category = 'servicios_publicos' THEN
            v_debit_code := '631';
            v_debit_name := 'Energía Eléctrica';
        ELSE
            v_debit_code := '642';
            v_debit_name := 'Otros Gastos';
        END IF;

        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', p_amount, 'credit', 0),
            jsonb_build_object('account_code', '142', 'account_name', 'Fondos de Mensajería', 'debit', 0, 'credit', p_amount)
        );

        PERFORM create_journal_entry(
            CURRENT_DATE,
            p_description,
            'messenger_fund',
            p_fund_id,
            v_lines
        );
    END IF;
    
    RETURN v_item_id;
END;
$$ LANGUAGE plpgsql;

-- 8. Función RPC: Cancelar fondo (devuelve todo el dinero)
CREATE OR REPLACE FUNCTION cancel_messenger_fund(p_fund_id UUID)
RETURNS VOID AS $$
DECLARE
    v_fund RECORD;
    v_refund DECIMAL;
BEGIN
    SELECT * INTO v_fund FROM messenger_funds WHERE id = p_fund_id FOR UPDATE;
    
    IF v_fund IS NULL THEN
        RAISE EXCEPTION 'Fondo no encontrado';
    END IF;
    
    IF v_fund.status IN ('legalizado', 'cancelado') THEN
        RAISE EXCEPTION 'El fondo ya está %', v_fund.status;
    END IF;
    
    -- Solo devolver lo que no se ha gastado ni devuelto
    v_refund := v_fund.amount_given - v_fund.amount_spent - v_fund.amount_returned;
    
    IF v_refund > 0 THEN
        -- Devolver a la cuenta
        UPDATE accounts SET balance = balance + v_refund, updated_at = NOW()
        WHERE id = v_fund.account_id;
        
        -- Crear movimiento de ingreso por cancelación
        INSERT INTO cash_movements (id, account_id, type, category, amount, description, person_name, date, created_at)
        VALUES (
            gen_random_uuid(),
            v_fund.account_id,
            'income',
            'devolucion_fondo',
            v_refund,
            'Cancelación fondo mensajería - ' || v_fund.employee_name,
            v_fund.employee_name,
            CURRENT_DATE,
            NOW()
        );
    END IF;
    
    -- Marcar como cancelado
    UPDATE messenger_funds SET status = 'cancelado', updated_at = NOW()
    WHERE id = p_fund_id;
END;
$$ LANGUAGE plpgsql;

-- 9. Actualizar trigger contable para manejar fondo_mensajero y devolucion_fondo
-- Estas categorías NO generan asientos de gasto real
-- Solo mueven dinero entre Caja (101) y Fondos de Mensajería (142)
CREATE OR REPLACE FUNCTION trg_journal_from_cash_movement()
RETURNS TRIGGER AS $$
DECLARE
    v_account_name TEXT;
    v_debit_code VARCHAR(20);
    v_debit_name VARCHAR(255);
    v_credit_code VARCHAR(20);
    v_credit_name VARCHAR(255);
    v_lines JSONB;
BEGIN
    SELECT name INTO v_account_name FROM accounts WHERE id = NEW.account_id;

    IF v_account_name ILIKE '%caja%' THEN
        v_debit_code := '101'; v_debit_name := 'Caja';
    ELSIF v_account_name ILIKE '%jhoan%' THEN
        v_debit_code := '105'; v_debit_name := 'Caja Jhoan';
    ELSIF v_account_name ILIKE '%industrial%' THEN
        v_debit_code := '103'; v_debit_name := 'Cuenta Industrial de Molinos';
    ELSIF v_account_name ILIKE '%davivienda%' OR v_account_name ILIKE '%daniela%' THEN
        v_debit_code := '104'; v_debit_name := 'Davivienda';
    ELSE
        v_debit_code := '102'; v_debit_name := 'Bancos';
    END IF;

    IF NEW.type = 'income' THEN
        -- ── INGRESOS ──
        CASE NEW.category
            WHEN 'sale' THEN v_credit_code := '701'; v_credit_name := 'Ventas de Productos';
            WHEN 'collection' THEN v_credit_code := '121'; v_credit_name := 'Clientes (Cobro)';
            WHEN 'service' THEN v_credit_code := '702'; v_credit_name := 'Ventas de Servicios';
            WHEN 'pago_prestamo' THEN v_credit_code := '122'; v_credit_name := 'Préstamos a Empleados';
            -- Devolución de fondo mensajero: Activo → Activo (no afecta P&L)
            WHEN 'devolucion_fondo' THEN v_credit_code := '142'; v_credit_name := 'Fondos de Mensajería';
            ELSE v_credit_code := '703'; v_credit_name := 'Otros Ingresos';
        END CASE;

        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', NEW.amount, 'credit', 0),
            jsonb_build_object('account_code', v_credit_code, 'account_name', v_credit_name, 'debit', 0, 'credit', NEW.amount)
        );

    ELSIF NEW.type = 'expense' THEN
        -- ── GASTOS ──
        CASE NEW.category
            WHEN 'purchase' THEN v_credit_code := '601'; v_credit_name := 'Compra de Materiales';
            WHEN 'salary' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'payroll' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'nomina' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'services' THEN v_credit_code := '631'; v_credit_name := 'Energía Eléctrica';
            WHEN 'rent' THEN v_credit_code := '641'; v_credit_name := 'Alquiler';
            WHEN 'prestamo_empleado' THEN v_credit_code := '122'; v_credit_name := 'Préstamos a Empleados';
            WHEN 'adelanto_sueldo' THEN v_credit_code := '141'; v_credit_name := 'Anticipos a Empleados';
            WHEN 'transfer_out' THEN v_credit_code := NULL;
            -- Fondo mensajero: Caja → Fondos Mensajería (Activo → Activo, NO es gasto)
            WHEN 'fondo_mensajero' THEN v_credit_code := '142'; v_credit_name := 'Fondos de Mensajería';
            ELSE v_credit_code := '642'; v_credit_name := 'Otros Gastos';
        END CASE;

        IF v_credit_code IS NULL THEN
            RETURN NEW;
        END IF;

        -- Para fondo_mensajero: Debit 142 (Fondos) / Credit Caja
        -- Es un movimiento Activo → Activo, así que invertimos el asiento
        IF NEW.category = 'fondo_mensajero' THEN
            v_lines := jsonb_build_array(
                jsonb_build_object('account_code', '142', 'account_name', 'Fondos de Mensajería', 'debit', NEW.amount, 'credit', 0),
                jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', 0, 'credit', NEW.amount)
            );
        ELSE
            v_lines := jsonb_build_array(
                jsonb_build_object('account_code', v_credit_code, 'account_name', v_credit_name, 'debit', NEW.amount, 'credit', 0),
                jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', 0, 'credit', NEW.amount)
            );
        END IF;

    ELSIF NEW.type = 'transfer' THEN
        IF NEW.category = 'transfer_in' AND NEW.to_account_id IS NOT NULL THEN
            DECLARE
                v_from_name TEXT;
                v_from_code VARCHAR(20);
                v_from_acct_name VARCHAR(255);
            BEGIN
                SELECT name INTO v_from_name FROM accounts WHERE id = NEW.to_account_id;
                IF v_from_name ILIKE '%caja%' THEN
                    v_from_code := '101'; v_from_acct_name := 'Caja';
                ELSIF v_from_name ILIKE '%jhoan%' THEN
                    v_from_code := '105'; v_from_acct_name := 'Caja Jhoan';
                ELSIF v_from_name ILIKE '%industrial%' THEN
                    v_from_code := '103'; v_from_acct_name := 'Cuenta Industrial de Molinos';
                ELSIF v_from_name ILIKE '%davivienda%' OR v_from_name ILIKE '%daniela%' THEN
                    v_from_code := '104'; v_from_acct_name := 'Davivienda';
                ELSE
                    v_from_code := '102'; v_from_acct_name := 'Bancos';
                END IF;

                v_lines := jsonb_build_array(
                    jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', NEW.amount, 'credit', 0),
                    jsonb_build_object('account_code', v_from_code, 'account_name', v_from_acct_name, 'debit', 0, 'credit', NEW.amount)
                );
            END;
        ELSE
            RETURN NEW;
        END IF;
    END IF;

    IF v_lines IS NOT NULL THEN
        PERFORM create_journal_entry(
            NEW.date::DATE,
            COALESCE(NEW.description, NEW.type || ' - ' || NEW.category),
            'cash_movement',
            NEW.id,
            v_lines
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
