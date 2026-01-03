-- =====================================================
-- ACTUALIZAR PAGO DE NÓMINA PARA PROCESAR PRÉSTAMOS
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. ACTUALIZAR FUNCIÓN DE PAGO DE NÓMINA
-- Ahora también actualiza los préstamos descontados
-- =====================================================
CREATE OR REPLACE FUNCTION register_payroll_payment(
    p_payroll_id UUID,
    p_account_id UUID,
    p_payment_date DATE DEFAULT CURRENT_DATE
)
RETURNS UUID AS $$
DECLARE
    v_movement_id UUID;
    v_employee_id UUID;
    v_employee_name TEXT;
    v_net_pay DECIMAL(12,2);
    v_period_info TEXT;
    v_loan_detail RECORD;
BEGIN
    -- Obtener datos de la nómina
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
    
    -- Crear movimiento de caja (egreso)
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
    
    -- Actualizar saldo de la cuenta
    UPDATE accounts
    SET balance = balance - v_net_pay,
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Actualizar la nómina con referencia al movimiento
    UPDATE payroll
    SET status = 'pagado',
        payment_date = p_payment_date,
        account_id = p_account_id,
        cash_movement_id = v_movement_id,
        updated_at = NOW()
    WHERE id = p_payroll_id;
    
    -- =====================================================
    -- PROCESAR PRÉSTAMOS DESCONTADOS EN LA NÓMINA
    -- =====================================================
    -- Buscar detalles de préstamos en esta nómina (código DESC_PRESTAMO)
    FOR v_loan_detail IN 
        SELECT pd.id, pd.amount, pd.notes
        FROM payroll_details pd
        WHERE pd.payroll_id = p_payroll_id 
        AND pd.concept_code = 'DESC_PRESTAMO'
    LOOP
        -- Buscar préstamos activos del empleado y actualizar
        UPDATE employee_loans el
        SET 
            paid_amount = paid_amount + v_loan_detail.amount,
            paid_installments = paid_installments + 1,
            remaining_amount = remaining_amount - v_loan_detail.amount,
            status = CASE 
                WHEN (remaining_amount - v_loan_detail.amount) <= 0 THEN 'pagado'
                ELSE 'activo'
            END,
            updated_at = NOW()
        WHERE el.employee_id = v_employee_id
        AND el.status = 'activo'
        AND el.installment_amount = v_loan_detail.amount
        -- Limitar a 1 préstamo por cuota
        AND el.id = (
            SELECT id FROM employee_loans 
            WHERE employee_id = v_employee_id 
            AND status = 'activo'
            AND installment_amount = v_loan_detail.amount
            ORDER BY loan_date ASC
            LIMIT 1
        );
        
        -- Registrar el pago en loan_payments si la tabla existe
        BEGIN
            INSERT INTO loan_payments (
                loan_id,
                payroll_id,
                payment_date,
                amount,
                installment_number,
                payment_method
            )
            SELECT 
                el.id,
                p_payroll_id,
                p_payment_date,
                v_loan_detail.amount,
                el.paid_installments,
                'nomina'
            FROM employee_loans el
            WHERE el.employee_id = v_employee_id
            AND el.installment_amount = v_loan_detail.amount
            ORDER BY el.loan_date ASC
            LIMIT 1;
        EXCEPTION WHEN undefined_table THEN
            -- La tabla loan_payments no existe, ignorar
            NULL;
        END;
    END LOOP;
    
    RETURN v_movement_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. CREAR TABLA loan_payments SI NO EXISTE
-- Para historial de pagos de préstamos
-- =====================================================
CREATE TABLE IF NOT EXISTS loan_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES employee_loans(id) ON DELETE CASCADE,
    payroll_id UUID REFERENCES payroll(id),
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount DECIMAL(12,2) NOT NULL,
    installment_number INTEGER,
    payment_method VARCHAR(20) DEFAULT 'nomina', -- 'nomina', 'efectivo', 'transferencia'
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_loan_payments_loan ON loan_payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_payments_payroll ON loan_payments(payroll_id);

-- =====================================================
-- 3. VERIFICAR
-- =====================================================
SELECT 'Función register_payroll_payment actualizada correctamente' as resultado;
