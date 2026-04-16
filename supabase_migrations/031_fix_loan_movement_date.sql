-- =====================================================
-- FIX: register_employee_loan - recibir fecha desde Dart
-- para que el movimiento de caja use la hora local del cliente
-- y aparezca correctamente en Caja Diaria
-- =====================================================

CREATE OR REPLACE FUNCTION register_employee_loan(
    p_employee_id UUID,
    p_amount DECIMAL(12,2),
    p_installments INTEGER,
    p_account_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_date TIMESTAMP DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_loan_id UUID;
    v_movement_id UUID;
    v_employee_name TEXT;
    v_installment_amount DECIMAL(12,2);
    v_date TIMESTAMP;
BEGIN
    v_date := COALESCE(p_date, NOW());

    -- Obtener nombre del empleado
    SELECT first_name || ' ' || last_name INTO v_employee_name
    FROM employees WHERE id = p_employee_id;
    
    -- Calcular cuota
    v_installment_amount := ROUND(p_amount / p_installments, 2);
    
    -- Crear movimiento de caja (egreso por préstamo)
    INSERT INTO cash_movements (
        account_id, type, category, amount,
        description, reference, person_name, date
    ) VALUES (
        p_account_id,
        'expense',
        'prestamo_empleado',
        p_amount,
        'Préstamo a empleado: ' || v_employee_name || COALESCE(' - ' || p_reason, ''),
        'PREST-EMP-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 8),
        v_employee_name,
        v_date
    )
    RETURNING id INTO v_movement_id;
    
    -- Actualizar saldo de la cuenta (egreso = resta)
    UPDATE accounts
    SET balance = balance - p_amount,
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Crear registro del préstamo
    INSERT INTO employee_loans (
        employee_id, loan_date, total_amount, installments,
        installment_amount, remaining_amount, paid_amount,
        paid_installments, reason, cash_movement_id, account_id, status
    ) VALUES (
        p_employee_id,
        v_date::date,
        p_amount,
        p_installments,
        v_installment_amount,
        p_amount,
        0,
        0,
        p_reason,
        v_movement_id,
        p_account_id,
        'activo'
    )
    RETURNING id INTO v_loan_id;
    
    RETURN v_loan_id;
END;
$$ LANGUAGE plpgsql;
