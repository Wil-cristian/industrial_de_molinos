-- =====================================================
-- MIGRACIÓN: Función atómica para cancelar préstamos
-- Todo en una transacción: si algo falla, nada se aplica
-- =====================================================

CREATE OR REPLACE FUNCTION cancel_employee_loan(p_loan_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_loan RECORD;
    v_account_balance DECIMAL(12,2);
BEGIN
    -- Obtener datos del préstamo con bloqueo
    SELECT * INTO v_loan
    FROM employee_loans 
    WHERE id = p_loan_id
    FOR UPDATE;

    IF v_loan IS NULL THEN
        RAISE EXCEPTION 'Préstamo no encontrado: %', p_loan_id;
    END IF;

    IF v_loan.status != 'activo' THEN
        RAISE EXCEPTION 'Solo se pueden anular préstamos activos (estado actual: %)', v_loan.status;
    END IF;

    IF COALESCE(v_loan.paid_installments, 0) > 0 THEN
        RAISE EXCEPTION 'No se puede anular un préstamo con cuotas pagadas (pagos: %)', v_loan.paid_installments;
    END IF;

    -- Bloquear la cuenta para evitar race conditions
    IF v_loan.account_id IS NOT NULL THEN
        SELECT balance INTO v_account_balance
        FROM accounts 
        WHERE id = v_loan.account_id
        FOR UPDATE;
    END IF;

    -- 1. Eliminar asientos contables asociados al movimiento de caja
    IF v_loan.cash_movement_id IS NOT NULL THEN
        DELETE FROM journal_entry_lines 
        WHERE entry_id IN (
            SELECT id FROM journal_entries 
            WHERE reference_type = 'cash_movement' 
            AND reference_id = v_loan.cash_movement_id
        );

        DELETE FROM journal_entries 
        WHERE reference_type = 'cash_movement' 
        AND reference_id = v_loan.cash_movement_id;
    END IF;

    -- 2. Eliminar el préstamo (tiene FK hacia cash_movements)
    DELETE FROM employee_loans WHERE id = p_loan_id;

    -- 3. Eliminar el movimiento de caja
    IF v_loan.cash_movement_id IS NOT NULL THEN
        DELETE FROM cash_movements WHERE id = v_loan.cash_movement_id;
    END IF;

    -- 4. Restaurar saldo de la cuenta
    IF v_loan.account_id IS NOT NULL THEN
        UPDATE accounts 
        SET balance = balance + v_loan.total_amount,
            updated_at = NOW()
        WHERE id = v_loan.account_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'loan_id', p_loan_id,
        'amount_restored', v_loan.total_amount,
        'account_id', v_loan.account_id,
        'new_balance', v_account_balance + v_loan.total_amount
    );
END;
$$ LANGUAGE plpgsql;

-- Permisos
GRANT EXECUTE ON FUNCTION cancel_employee_loan(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cancel_employee_loan(UUID) TO anon;
