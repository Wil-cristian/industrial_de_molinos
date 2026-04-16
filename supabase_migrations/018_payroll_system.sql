-- =====================================================
-- SISTEMA DE NÓMINA PARA EMPLEADOS
-- Descuentos, Incapacidades, Horas Extras, Pagos
-- Conectado con Contabilidad (cash_movements)
-- =====================================================

-- =====================================================
-- TABLA DE CONCEPTOS DE NÓMINA
-- =====================================================
CREATE TABLE IF NOT EXISTS payroll_concepts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL, -- 'ingreso', 'descuento'
    category VARCHAR(50) NOT NULL, -- 'salario', 'hora_extra', 'bonificacion', 'descuento', 'incapacidad'
    is_percentage BOOLEAN DEFAULT FALSE,
    default_value DECIMAL(12,2) DEFAULT 0,
    affects_taxes BOOLEAN DEFAULT TRUE,
    is_active BOOLEAN DEFAULT TRUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insertar conceptos predeterminados
INSERT INTO payroll_concepts (code, name, type, category, is_percentage, default_value, description) VALUES
-- Ingresos
('SAL_BASE', 'Salario Base', 'ingreso', 'salario', FALSE, 0, 'Salario mensual del empleado'),
('HORA_EXTRA_25', 'Hora Extra 25%', 'ingreso', 'hora_extra', FALSE, 0, 'Hora extra con recargo del 25%'),
('HORA_EXTRA_35', 'Hora Extra 35%', 'ingreso', 'hora_extra', FALSE, 0, 'Hora extra nocturna con recargo del 35%'),
('HORA_EXTRA_100', 'Hora Extra 100%', 'ingreso', 'hora_extra', FALSE, 0, 'Hora extra dominical/festivo'),
('BONIF_PROD', 'Bonificación Productividad', 'ingreso', 'bonificacion', FALSE, 0, 'Bonificación por productividad'),
('BONIF_PUNT', 'Bonificación Puntualidad', 'ingreso', 'bonificacion', FALSE, 0, 'Bonificación por puntualidad'),
('COMISION', 'Comisión', 'ingreso', 'bonificacion', FALSE, 0, 'Comisión por ventas'),
-- Descuentos
('DESC_FALTAS', 'Descuento por Faltas', 'descuento', 'descuento', FALSE, 0, 'Descuento por días no trabajados'),
('DESC_TARDANZA', 'Descuento por Tardanza', 'descuento', 'descuento', FALSE, 0, 'Descuento por llegadas tarde'),
('DESC_ADELANTO', 'Adelanto de Sueldo', 'descuento', 'descuento', FALSE, 0, 'Adelanto recibido previamente'),
('DESC_PRESTAMO', 'Cuota Préstamo', 'descuento', 'descuento', FALSE, 0, 'Cuota de préstamo al empleado'),
('DESC_UNIFORME', 'Descuento Uniforme', 'descuento', 'descuento', FALSE, 0, 'Descuento por uniforme'),
('DESC_OTRO', 'Otro Descuento', 'descuento', 'descuento', FALSE, 0, 'Otros descuentos'),
-- Incapacidades
('INCAP_ENF', 'Incapacidad Enfermedad', 'descuento', 'incapacidad', TRUE, 50, 'Pago del 50% por enfermedad'),
('INCAP_ACC', 'Incapacidad Accidente', 'descuento', 'incapacidad', TRUE, 0, 'Incapacidad por accidente laboral'),
('INCAP_MAT', 'Licencia Maternidad', 'descuento', 'incapacidad', TRUE, 0, 'Licencia por maternidad')
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- TABLA DE PERIODOS DE NÓMINA
-- =====================================================
CREATE TABLE IF NOT EXISTS payroll_periods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_type VARCHAR(20) NOT NULL, -- 'mensual', 'quincenal', 'semanal'
    period_number INTEGER NOT NULL,
    year INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    payment_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'abierto', -- 'abierto', 'cerrado', 'pagado'
    total_earnings DECIMAL(12,2) DEFAULT 0,
    total_deductions DECIMAL(12,2) DEFAULT 0,
    total_net DECIMAL(12,2) DEFAULT 0,
    notes TEXT,
    closed_at TIMESTAMP WITH TIME ZONE,
    closed_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(period_type, period_number, year)
);

-- =====================================================
-- TABLA PRINCIPAL DE NÓMINA POR EMPLEADO
-- =====================================================
CREATE TABLE IF NOT EXISTS payroll (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    period_id UUID NOT NULL REFERENCES payroll_periods(id) ON DELETE CASCADE,
    
    -- Salario base
    base_salary DECIMAL(12,2) NOT NULL DEFAULT 0,
    
    -- Días trabajados
    days_worked INTEGER DEFAULT 0,
    days_absent INTEGER DEFAULT 0,
    days_vacation INTEGER DEFAULT 0,
    days_incapacity INTEGER DEFAULT 0,
    
    -- Horas
    regular_hours DECIMAL(6,2) DEFAULT 0,
    overtime_hours_25 DECIMAL(6,2) DEFAULT 0,
    overtime_hours_35 DECIMAL(6,2) DEFAULT 0,
    overtime_hours_100 DECIMAL(6,2) DEFAULT 0,
    
    -- Totales calculados
    total_earnings DECIMAL(12,2) DEFAULT 0,
    total_deductions DECIMAL(12,2) DEFAULT 0,
    net_pay DECIMAL(12,2) DEFAULT 0,
    
    -- Estado
    status VARCHAR(20) NOT NULL DEFAULT 'borrador', -- 'borrador', 'aprobado', 'pagado'
    
    -- Pago
    payment_date TIMESTAMP WITH TIME ZONE,
    payment_method VARCHAR(30), -- 'efectivo', 'transferencia', 'cheque'
    payment_reference VARCHAR(100),
    account_id UUID REFERENCES accounts(id), -- Cuenta de donde se paga
    cash_movement_id UUID REFERENCES cash_movements(id), -- Referencia al movimiento
    
    -- Auditoría
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_by UUID,
    approved_at TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(employee_id, period_id)
);

-- =====================================================
-- TABLA DE DETALLES DE NÓMINA (CONCEPTOS APLICADOS)
-- =====================================================
CREATE TABLE IF NOT EXISTS payroll_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payroll_id UUID NOT NULL REFERENCES payroll(id) ON DELETE CASCADE,
    concept_id UUID NOT NULL REFERENCES payroll_concepts(id),
    concept_code VARCHAR(20) NOT NULL,
    concept_name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL, -- 'ingreso', 'descuento'
    
    quantity DECIMAL(10,2) DEFAULT 1, -- Cantidad (horas, días, etc.)
    unit_value DECIMAL(12,2) DEFAULT 0, -- Valor unitario
    amount DECIMAL(12,2) NOT NULL, -- Monto total
    
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- TABLA DE INCAPACIDADES
-- =====================================================
CREATE TABLE IF NOT EXISTS employee_incapacities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    type VARCHAR(30) NOT NULL, -- 'enfermedad', 'accidente_laboral', 'accidente_comun', 'maternidad'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    days_total INTEGER NOT NULL,
    
    -- Documento de soporte
    certificate_number VARCHAR(50),
    medical_entity VARCHAR(100),
    diagnosis TEXT,
    
    -- Pago
    payment_percentage DECIMAL(5,2) DEFAULT 100, -- % del salario a pagar
    employer_days INTEGER DEFAULT 0, -- Días pagados por empleador
    
    -- Estado
    status VARCHAR(20) DEFAULT 'activa', -- 'activa', 'terminada', 'cancelada'
    
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- TABLA DE PRÉSTAMOS A EMPLEADOS
-- =====================================================
CREATE TABLE IF NOT EXISTS employee_loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    loan_date DATE NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    installments INTEGER NOT NULL DEFAULT 1, -- Número de cuotas
    installment_amount DECIMAL(12,2) NOT NULL, -- Monto por cuota
    
    paid_amount DECIMAL(12,2) DEFAULT 0,
    paid_installments INTEGER DEFAULT 0,
    remaining_amount DECIMAL(12,2) NOT NULL,
    
    reason TEXT,
    status VARCHAR(20) DEFAULT 'activo', -- 'activo', 'pagado', 'cancelado'
    
    -- Registro contable del préstamo
    cash_movement_id UUID REFERENCES cash_movements(id),
    account_id UUID REFERENCES accounts(id),
    
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- TABLA DE PAGOS DE CUOTAS DE PRÉSTAMOS
-- =====================================================
CREATE TABLE IF NOT EXISTS loan_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID NOT NULL REFERENCES employee_loans(id) ON DELETE CASCADE,
    payroll_id UUID REFERENCES payroll(id), -- Si se descuenta de nómina
    
    payment_date DATE NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    installment_number INTEGER NOT NULL,
    
    payment_method VARCHAR(30) DEFAULT 'nomina', -- 'nomina', 'efectivo', 'transferencia'
    
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- ÍNDICES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_payroll_employee ON payroll(employee_id);
CREATE INDEX IF NOT EXISTS idx_payroll_period ON payroll(period_id);
CREATE INDEX IF NOT EXISTS idx_payroll_status ON payroll(status);
CREATE INDEX IF NOT EXISTS idx_payroll_details_payroll ON payroll_details(payroll_id);
CREATE INDEX IF NOT EXISTS idx_incapacities_employee ON employee_incapacities(employee_id);
CREATE INDEX IF NOT EXISTS idx_incapacities_dates ON employee_incapacities(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_loans_employee ON employee_loans(employee_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON employee_loans(status);

-- =====================================================
-- FUNCIÓN PARA CALCULAR NÓMINA
-- =====================================================
CREATE OR REPLACE FUNCTION calculate_payroll_totals(p_payroll_id UUID)
RETURNS void AS $$
DECLARE
    v_total_earnings DECIMAL(12,2);
    v_total_deductions DECIMAL(12,2);
BEGIN
    -- Calcular total de ingresos
    SELECT COALESCE(SUM(amount), 0) INTO v_total_earnings
    FROM payroll_details
    WHERE payroll_id = p_payroll_id AND type = 'ingreso';
    
    -- Calcular total de descuentos
    SELECT COALESCE(SUM(amount), 0) INTO v_total_deductions
    FROM payroll_details
    WHERE payroll_id = p_payroll_id AND type = 'descuento';
    
    -- Actualizar nómina
    UPDATE payroll
    SET total_earnings = v_total_earnings,
        total_deductions = v_total_deductions,
        net_pay = v_total_earnings - v_total_deductions,
        updated_at = NOW()
    WHERE id = p_payroll_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCIÓN PARA REGISTRAR PAGO DE NÓMINA EN CONTABILIDAD
-- =====================================================
CREATE OR REPLACE FUNCTION register_payroll_payment(
    p_payroll_id UUID,
    p_account_id UUID,
    p_payment_method VARCHAR(30)
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
        'Pago nómina ' || v_period_info,
        'NOM-' || p_payroll_id::TEXT,
        v_employee_name,
        NOW()
    )
    RETURNING id INTO v_movement_id;
    
    -- Actualizar saldo de la cuenta
    UPDATE accounts
    SET balance = balance - v_net_pay
    WHERE id = p_account_id;
    
    -- Actualizar la nómina con referencia al movimiento
    UPDATE payroll
    SET status = 'pagado',
        payment_date = NOW(),
        payment_method = p_payment_method,
        account_id = p_account_id,
        cash_movement_id = v_movement_id,
        updated_at = NOW()
    WHERE id = p_payroll_id;
    
    RETURN v_movement_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FUNCIÓN PARA REGISTRAR PRÉSTAMO EN CONTABILIDAD
-- =====================================================
CREATE OR REPLACE FUNCTION register_employee_loan(
    p_employee_id UUID,
    p_amount DECIMAL(12,2),
    p_installments INTEGER,
    p_account_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_loan_id UUID;
    v_movement_id UUID;
    v_employee_name TEXT;
    v_installment_amount DECIMAL(12,2);
BEGIN
    -- Obtener nombre del empleado
    SELECT first_name || ' ' || last_name INTO v_employee_name
    FROM employees WHERE id = p_employee_id;
    
    -- Calcular cuota
    v_installment_amount := ROUND(p_amount / p_installments, 2);
    
    -- Crear movimiento de caja (egreso por préstamo)
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
        'prestamo_empleado',
        p_amount,
        'Préstamo a empleado: ' || v_employee_name,
        'PREST-EMP-' || gen_random_uuid()::TEXT,
        v_employee_name,
        NOW()
    )
    RETURNING id INTO v_movement_id;
    
    -- Actualizar saldo de la cuenta
    UPDATE accounts
    SET balance = balance - p_amount
    WHERE id = p_account_id;
    
    -- Crear registro del préstamo
    INSERT INTO employee_loans (
        employee_id,
        loan_date,
        total_amount,
        installments,
        installment_amount,
        remaining_amount,
        reason,
        cash_movement_id,
        account_id
    ) VALUES (
        p_employee_id,
        CURRENT_DATE,
        p_amount,
        p_installments,
        v_installment_amount,
        p_amount,
        p_reason,
        v_movement_id,
        p_account_id
    )
    RETURNING id INTO v_loan_id;
    
    RETURN v_loan_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- RLS POLICIES
-- =====================================================
ALTER TABLE payroll_concepts ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_incapacities ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_payments ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes
DROP POLICY IF EXISTS "allow_all_payroll_concepts" ON payroll_concepts;
DROP POLICY IF EXISTS "allow_all_payroll_periods" ON payroll_periods;
DROP POLICY IF EXISTS "allow_all_payroll" ON payroll;
DROP POLICY IF EXISTS "allow_all_payroll_details" ON payroll_details;
DROP POLICY IF EXISTS "allow_all_incapacities" ON employee_incapacities;
DROP POLICY IF EXISTS "allow_all_loans" ON employee_loans;
DROP POLICY IF EXISTS "allow_all_loan_payments" ON loan_payments;

-- Políticas permisivas
CREATE POLICY "allow_all_payroll_concepts" ON payroll_concepts FOR ALL USING (true);
CREATE POLICY "allow_all_payroll_periods" ON payroll_periods FOR ALL USING (true);
CREATE POLICY "allow_all_payroll" ON payroll FOR ALL USING (true);
CREATE POLICY "allow_all_payroll_details" ON payroll_details FOR ALL USING (true);
CREATE POLICY "allow_all_incapacities" ON employee_incapacities FOR ALL USING (true);
CREATE POLICY "allow_all_loans" ON employee_loans FOR ALL USING (true);
CREATE POLICY "allow_all_loan_payments" ON loan_payments FOR ALL USING (true);

-- =====================================================
-- GRANTS
-- =====================================================
GRANT ALL ON payroll_concepts TO anon, authenticated;
GRANT ALL ON payroll_periods TO anon, authenticated;
GRANT ALL ON payroll TO anon, authenticated;
GRANT ALL ON payroll_details TO anon, authenticated;
GRANT ALL ON employee_incapacities TO anon, authenticated;
GRANT ALL ON employee_loans TO anon, authenticated;
GRANT ALL ON loan_payments TO anon, authenticated;

-- =====================================================
-- COMENTARIOS
-- =====================================================
COMMENT ON TABLE payroll_concepts IS 'Catálogo de conceptos de nómina (ingresos y descuentos)';
COMMENT ON TABLE payroll_periods IS 'Periodos de nómina (mensual, quincenal, semanal)';
COMMENT ON TABLE payroll IS 'Nómina principal por empleado y periodo';
COMMENT ON TABLE payroll_details IS 'Detalle de conceptos aplicados en cada nómina';
COMMENT ON TABLE employee_incapacities IS 'Registro de incapacidades de empleados';
COMMENT ON TABLE employee_loans IS 'Préstamos otorgados a empleados';
COMMENT ON TABLE loan_payments IS 'Pagos de cuotas de préstamos';

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================
SELECT 'Sistema de Nómina creado exitosamente' AS resultado;
SELECT 'Tablas creadas: payroll_concepts, payroll_periods, payroll, payroll_details, employee_incapacities, employee_loans, loan_payments' AS tablas;
