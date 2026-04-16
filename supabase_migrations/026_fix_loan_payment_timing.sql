-- =====================================================
-- FIX: préstamos solo se descuentan al pagar la nómina
-- Evita duplicados y limpia abonos de nómina inválidos
-- =====================================================

BEGIN;

-- 1) Eliminar pagos de préstamo por nómina que NO pertenezcan
--    a una nómina realmente pagada.
DELETE FROM loan_payments lp
WHERE lp.payment_method = 'nomina'
  AND (
    lp.payroll_id IS NULL
    OR NOT EXISTS (
      SELECT 1
      FROM payroll p
      WHERE p.id = lp.payroll_id
        AND p.status = 'pagado'
    )
  );

-- 2) Eliminar duplicados exactos conservando el primer registro.
WITH ranked_payments AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY loan_id, payroll_id, COALESCE(installment_number, -1), amount, payment_method
      ORDER BY created_at ASC, id ASC
    ) AS rn
  FROM loan_payments
)
DELETE FROM loan_payments lp
USING ranked_payments rp
WHERE lp.id = rp.id
  AND rp.rn > 1;

-- 3) Recalcular todos los préstamos con base en pagos válidos.
WITH loan_totals AS (
  SELECT
    l.id AS loan_id,
    COALESCE(SUM(lp.amount), 0)::DECIMAL(12,2) AS paid_amount,
    COALESCE(COUNT(lp.id), 0)::INTEGER AS paid_installments
  FROM employee_loans l
  LEFT JOIN loan_payments lp ON lp.loan_id = l.id
  GROUP BY l.id
)
UPDATE employee_loans l
SET
  paid_amount = LEAST(lt.paid_amount, l.total_amount),
  paid_installments = LEAST(lt.paid_installments, l.installments),
  remaining_amount = GREATEST(l.total_amount - LEAST(lt.paid_amount, l.total_amount), 0),
  status = CASE
    WHEN GREATEST(l.total_amount - LEAST(lt.paid_amount, l.total_amount), 0) <= 0.01 THEN 'pagado'
    ELSE 'activo'
  END,
  updated_at = NOW()
FROM loan_totals lt
WHERE l.id = lt.loan_id;

-- 4) Impedir duplicados futuros de la misma cuota en la misma nómina.
CREATE UNIQUE INDEX IF NOT EXISTS idx_loan_payments_unique_nomina
ON loan_payments (loan_id, payroll_id, installment_number)
WHERE payroll_id IS NOT NULL;

-- 5) Hacer idempotente el pago de nómina y procesar préstamos solo una vez.
CREATE OR REPLACE FUNCTION register_payroll_payment(
    p_payroll_id UUID,
    p_account_id UUID,
    p_payment_date DATE DEFAULT CURRENT_DATE
)
RETURNS UUID AS $$
DECLARE
    v_movement_id UUID;
    v_existing_movement_id UUID;
    v_employee_id UUID;
    v_employee_name TEXT;
    v_net_pay DECIMAL(12,2);
    v_period_info TEXT;
    v_loan_detail RECORD;
    v_loan_id UUID;
    v_next_installment INTEGER;
BEGIN
    -- Si la nómina ya fue pagada antes, no volver a descontar ni mover caja.
    SELECT cash_movement_id
    INTO v_existing_movement_id
    FROM payroll
    WHERE id = p_payroll_id
      AND status = 'pagado';

    IF FOUND THEN
        RETURN v_existing_movement_id;
    END IF;

    -- Obtener datos de la nómina.
    SELECT
        p.employee_id,
        e.first_name || ' ' || e.last_name,
        p.net_pay,
        pp.period_type || ' ' || pp.period_number || '/' || pp.year
    INTO v_employee_id, v_employee_name, v_net_pay, v_period_info
    FROM payroll p
    JOIN employees e ON e.id = p.employee_id
    JOIN payroll_periods pp ON pp.id = p.period_id
    WHERE p.id = p_payroll_id;

    IF v_employee_id IS NULL THEN
        RAISE EXCEPTION 'Nómina no encontrada: %', p_payroll_id;
    END IF;

    -- Crear movimiento de caja (egreso).
    INSERT INTO cash_movements (
        account_id,
        type,
        category,
        amount,
        description,
        reference,
        person_name,
        date
    ) VALUES (
        p_account_id,
        'expense',
        'nomina',
        v_net_pay,
        'Pago nómina ' || v_period_info || ' - ' || v_employee_name,
        'NOM-' || p_payroll_id::TEXT,
        v_employee_name,
        p_payment_date
    )
    RETURNING id INTO v_movement_id;

    -- Actualizar saldo de la cuenta.
    UPDATE accounts
    SET balance = balance - v_net_pay,
        updated_at = NOW()
    WHERE id = p_account_id;

    -- Marcar nómina como pagada.
    UPDATE payroll
    SET status = 'pagado',
        payment_date = p_payment_date,
        account_id = p_account_id,
        cash_movement_id = v_movement_id,
        updated_at = NOW()
    WHERE id = p_payroll_id;

    -- Procesar descuentos de préstamo SOLO al pagar la nómina.
    FOR v_loan_detail IN
        SELECT pd.amount, pd.notes
        FROM payroll_details pd
        WHERE pd.payroll_id = p_payroll_id
          AND pd.concept_code = 'DESC_PRESTAMO'
    LOOP
        SELECT
            el.id,
            el.paid_installments + 1
        INTO v_loan_id, v_next_installment
        FROM employee_loans el
        WHERE el.employee_id = v_employee_id
          AND el.status = 'activo'
          AND el.remaining_amount > 0
          AND ROUND(el.installment_amount::NUMERIC, 2) = ROUND(v_loan_detail.amount::NUMERIC, 2)
          AND NOT EXISTS (
              SELECT 1
              FROM loan_payments lp
              WHERE lp.loan_id = el.id
                AND lp.payroll_id = p_payroll_id
          )
        ORDER BY el.loan_date ASC
        LIMIT 1;

        IF v_loan_id IS NULL THEN
            CONTINUE;
        END IF;

        UPDATE employee_loans
        SET paid_amount = LEAST(paid_amount + v_loan_detail.amount, total_amount),
            paid_installments = LEAST(paid_installments + 1, installments),
            remaining_amount = GREATEST(remaining_amount - v_loan_detail.amount, 0),
            status = CASE
                WHEN GREATEST(remaining_amount - v_loan_detail.amount, 0) <= 0.01 THEN 'pagado'
                ELSE 'activo'
            END,
            updated_at = NOW()
        WHERE id = v_loan_id;

        INSERT INTO loan_payments (
            loan_id,
            payroll_id,
            payment_date,
            amount,
            installment_number,
            payment_method
        ) VALUES (
            v_loan_id,
            p_payroll_id,
            p_payment_date,
            v_loan_detail.amount,
            v_next_installment,
            'nomina'
        )
        ON CONFLICT (loan_id, payroll_id, installment_number)
        WHERE payroll_id IS NOT NULL DO NOTHING;
    END LOOP;

    RETURN v_movement_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;
