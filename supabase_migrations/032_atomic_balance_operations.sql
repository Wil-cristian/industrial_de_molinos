-- =====================================================
-- MIGRACIÓN 032: Operaciones Atómicas de Balance
-- =====================================================
-- Problema: createTransfer() y createMovementWithBalanceUpdate() 
--           hacen read-then-write (race condition en acceso concurrente).
-- Solución: RPCs atómicas con SELECT ... FOR UPDATE.
-- =====================================================

-- =====================================================
-- 1. FUNCIÓN: Transferencia atómica entre cuentas
-- =====================================================
CREATE OR REPLACE FUNCTION atomic_transfer(
    p_from_account_id UUID,
    p_to_account_id UUID,
    p_amount DECIMAL(12,2),
    p_description TEXT,
    p_date DATE DEFAULT CURRENT_DATE,
    p_reference TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_from_balance DECIMAL(12,2);
    v_to_balance DECIMAL(12,2);
    v_transfer_id TEXT;
    v_out_id UUID;
    v_in_id UUID;
BEGIN
    -- Validaciones
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a 0';
    END IF;
    IF p_from_account_id = p_to_account_id THEN
        RAISE EXCEPTION 'No se puede transferir a la misma cuenta';
    END IF;

    -- Bloquear ambas cuentas en orden para evitar deadlocks
    SELECT balance INTO v_from_balance 
    FROM accounts WHERE id = LEAST(p_from_account_id, p_to_account_id)
    FOR UPDATE;
    
    SELECT balance INTO v_to_balance 
    FROM accounts WHERE id = GREATEST(p_from_account_id, p_to_account_id)
    FOR UPDATE;

    -- Obtener los balances correctos (LEAST/GREATEST puede haber intercambiado)
    SELECT balance INTO v_from_balance FROM accounts WHERE id = p_from_account_id;
    SELECT balance INTO v_to_balance FROM accounts WHERE id = p_to_account_id;

    -- Verificar saldo
    IF v_from_balance < p_amount THEN
        RAISE EXCEPTION 'Saldo insuficiente: disponible %, requerido %', v_from_balance, p_amount;
    END IF;

    v_transfer_id := extract(epoch from now())::TEXT;

    -- Insertar movimiento de salida
    INSERT INTO cash_movements (
        account_id, to_account_id, type, category, amount,
        description, reference, date, linked_transfer_id
    ) VALUES (
        p_from_account_id, p_to_account_id, 'transfer', 'transfer_out', p_amount,
        'Traslado: ' || p_description, p_reference, p_date, v_transfer_id
    ) RETURNING id INTO v_out_id;

    -- Insertar movimiento de entrada
    INSERT INTO cash_movements (
        account_id, to_account_id, type, category, amount,
        description, reference, date, linked_transfer_id
    ) VALUES (
        p_to_account_id, p_from_account_id, 'transfer', 'transfer_in', p_amount,
        'Traslado: ' || p_description, p_reference, p_date, v_transfer_id
    ) RETURNING id INTO v_in_id;

    -- Actualizar balances atómicamente
    UPDATE accounts SET balance = balance - p_amount, updated_at = NOW()
    WHERE id = p_from_account_id;
    
    UPDATE accounts SET balance = balance + p_amount, updated_at = NOW()
    WHERE id = p_to_account_id;

    RETURN jsonb_build_object(
        'success', true,
        'out_movement_id', v_out_id,
        'in_movement_id', v_in_id,
        'from_new_balance', v_from_balance - p_amount,
        'to_new_balance', v_to_balance + p_amount
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. FUNCIÓN: Actualización atómica de balance por movimiento
-- =====================================================
CREATE OR REPLACE FUNCTION atomic_movement_with_balance(
    p_account_id UUID,
    p_type VARCHAR(20),          -- 'income' o 'expense'
    p_category VARCHAR(50),
    p_amount DECIMAL(12,2),
    p_description TEXT,
    p_reference TEXT DEFAULT NULL,
    p_person_name TEXT DEFAULT NULL,
    p_date DATE DEFAULT CURRENT_DATE
) RETURNS JSONB AS $$
DECLARE
    v_balance DECIMAL(12,2);
    v_new_balance DECIMAL(12,2);
    v_movement_id UUID;
BEGIN
    -- Validaciones
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a 0';
    END IF;
    IF p_type NOT IN ('income', 'expense') THEN
        RAISE EXCEPTION 'Tipo inválido: %. Use income o expense', p_type;
    END IF;

    -- Bloquear cuenta
    SELECT balance INTO v_balance
    FROM accounts WHERE id = p_account_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Cuenta no encontrada: %', p_account_id;
    END IF;

    -- Calcular nuevo balance
    IF p_type = 'income' THEN
        v_new_balance := v_balance + p_amount;
    ELSE
        v_new_balance := v_balance - p_amount;
    END IF;

    -- Insertar movimiento
    INSERT INTO cash_movements (
        account_id, type, category, amount,
        description, reference, person_name, date
    ) VALUES (
        p_account_id, p_type, p_category, p_amount,
        p_description, p_reference, p_person_name, p_date
    ) RETURNING id INTO v_movement_id;

    -- Actualizar balance atómicamente
    UPDATE accounts SET balance = v_new_balance, updated_at = NOW()
    WHERE id = p_account_id;

    RETURN jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. FUNCIÓN: Reversión atómica de pagos de factura anulada
-- =====================================================
CREATE OR REPLACE FUNCTION atomic_revert_invoice_payments(p_invoice_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_movement RECORD;
    v_invoice RECORD;
    v_reversed_count INT := 0;
    v_total_reversed DECIMAL(12,2) := 0;
BEGIN
    -- Obtener factura
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    IF v_invoice IS NULL THEN
        RAISE EXCEPTION 'Factura no encontrada: %', p_invoice_id;
    END IF;

    -- Verificar que no haya reversiones previas
    IF EXISTS (
        SELECT 1 FROM cash_movements 
        WHERE reference = 'ANULACION-' || v_invoice.series || '-' || v_invoice.number
    ) THEN
        RAISE EXCEPTION 'Los pagos ya fueron revertidos anteriormente';
    END IF;

    -- Procesar cada movimiento de ingreso
    FOR v_movement IN 
        SELECT * FROM cash_movements 
        WHERE reference = v_invoice.series || '-' || v_invoice.number
        AND type = 'income'
    LOOP
        -- Bloquear cuenta
        PERFORM 1 FROM accounts WHERE id = v_movement.account_id FOR UPDATE;

        -- Crear movimiento de reversión
        INSERT INTO cash_movements (
            account_id, type, category, amount,
            description, reference, person_name, date
        ) VALUES (
            v_movement.account_id, 'expense', 'other_expense', v_movement.amount,
            'Reversión por anulación - ' || v_invoice.series || '-' || v_invoice.number,
            'ANULACION-' || v_invoice.series || '-' || v_invoice.number,
            v_invoice.customer_name, CURRENT_DATE
        );

        -- Descontar del balance
        UPDATE accounts SET balance = balance - v_movement.amount, updated_at = NOW()
        WHERE id = v_movement.account_id;

        v_reversed_count := v_reversed_count + 1;
        v_total_reversed := v_total_reversed + v_movement.amount;
    END LOOP;

    -- Resetear monto pagado
    UPDATE invoices SET paid_amount = 0 WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'reversed_count', v_reversed_count,
        'total_reversed', v_total_reversed
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. PERMISOS
-- =====================================================
GRANT EXECUTE ON FUNCTION atomic_transfer TO authenticated;
GRANT EXECUTE ON FUNCTION atomic_movement_with_balance TO authenticated;
GRANT EXECUTE ON FUNCTION atomic_revert_invoice_payments TO authenticated;

COMMENT ON FUNCTION atomic_transfer IS 'Transferencia atómica entre cuentas con SELECT FOR UPDATE';
COMMENT ON FUNCTION atomic_movement_with_balance IS 'Crear movimiento + actualizar balance atómicamente';
COMMENT ON FUNCTION atomic_revert_invoice_payments IS 'Revertir pagos de una factura anulada — todo o nada';
