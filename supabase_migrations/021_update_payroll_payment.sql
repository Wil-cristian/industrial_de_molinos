-- =====================================================
-- ACTUALIZAR FUNCIÓN DE PAGO DE NÓMINA
-- Cambiar p_payment_method por p_payment_date
-- =====================================================

-- Primero agregar concepto de hora extra normal si no existe
INSERT INTO payroll_concepts (code, name, type, category, is_percentage, default_value, description) 
VALUES ('HORA_EXTRA', 'Hora Extra', 'ingreso', 'hora_extra', FALSE, 0, 'Hora extra sin recargo')
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- CORREGIR FUNCIÓN DE CÁLCULO DE TOTALES
-- Debe incluir el salario base + detalles de ingresos - descuentos
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_payroll_totals(p_payroll_id UUID)
RETURNS void AS $$
DECLARE
    v_base_salary DECIMAL(12,2);
    v_extra_earnings DECIMAL(12,2);
    v_total_deductions DECIMAL(12,2);
BEGIN
    -- Obtener salario base
    SELECT COALESCE(base_salary, 0) INTO v_base_salary
    FROM payroll WHERE id = p_payroll_id;
    
    -- Calcular ingresos adicionales (horas extra, bonos, etc.)
    SELECT COALESCE(SUM(amount), 0) INTO v_extra_earnings
    FROM payroll_details
    WHERE payroll_id = p_payroll_id AND type = 'ingreso';
    
    -- Calcular total de descuentos (faltas, préstamos, etc.)
    SELECT COALESCE(SUM(amount), 0) INTO v_total_deductions
    FROM payroll_details
    WHERE payroll_id = p_payroll_id AND type = 'descuento';
    
    -- Actualizar nómina: 
    -- total_earnings = salario base + extras
    -- net_pay = total_earnings - descuentos
    UPDATE payroll
    SET total_earnings = v_base_salary + v_extra_earnings,
        total_deductions = v_total_deductions,
        net_pay = (v_base_salary + v_extra_earnings) - v_total_deductions,
        updated_at = NOW()
    WHERE id = p_payroll_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ACTUALIZAR FUNCIÓN DE PAGO DE NÓMINA
-- =====================================================
CREATE OR REPLACE FUNCTION register_payroll_payment(
    p_payroll_id UUID,
    p_account_id UUID,
    p_payment_date DATE DEFAULT CURRENT_DATE
)
RETURNS UUID AS $$
DECLARE
    v_movement_id UUID;
    v_employee_name TEXT;
    v_net_pay DECIMAL(12,2);
    v_period_info TEXT;
BEGIN
    -- Obtener datos de la nómina
    SELECT 
        e.first_name || ' ' || e.last_name,
        p.net_pay,
        pp.period_type || ' ' || pp.period_number || '/' || pp.year
    INTO v_employee_name, v_net_pay, v_period_info
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
    SET balance = balance - v_net_pay
    WHERE id = p_account_id;
    
    -- Actualizar la nómina con referencia al movimiento
    UPDATE payroll
    SET status = 'pagado',
        payment_date = p_payment_date,
        account_id = p_account_id,
        cash_movement_id = v_movement_id,
        updated_at = NOW()
    WHERE id = p_payroll_id;
    
    RETURN v_movement_id;
END;
$$ LANGUAGE plpgsql;

-- Si existe columna payment_method, hacer opcional (puede tener datos antiguos)
-- ALTER TABLE payroll ALTER COLUMN payment_method DROP NOT NULL;

-- =====================================================
-- RECALCULAR TODAS LAS NÓMINAS PENDIENTES
-- Para corregir los totales con la nueva lógica
-- =====================================================
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT id FROM payroll WHERE status = 'borrador'
    LOOP
        PERFORM calculate_payroll_totals(rec.id);
    END LOOP;
END;
$$;
