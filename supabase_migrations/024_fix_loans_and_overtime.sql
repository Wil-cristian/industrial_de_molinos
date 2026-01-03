-- =====================================================
-- CORRECCIONES PARA PRÉSTAMOS Y HORAS EXTRAS
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. AGREGAR COLUMNAS A employee_loans SI NO EXISTEN
-- =====================================================
ALTER TABLE employee_loans 
ADD COLUMN IF NOT EXISTS cash_movement_id UUID REFERENCES cash_movements(id);

ALTER TABLE employee_loans 
ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES accounts(id);

-- =====================================================
-- 2. AGREGAR CONCEPTOS DE HORAS EXTRAS FALTANTES
-- =====================================================
INSERT INTO payroll_concepts (code, name, type, category, is_percentage, default_value, description) VALUES
('HORA_EXTRA', 'Hora Extra Normal', 'ingreso', 'hora_extra', FALSE, 0, 'Hora extra sin recargo adicional'),
('HORA_EXTRA_75', 'Hora Extra Nocturna 75%', 'ingreso', 'hora_extra', FALSE, 0, 'Hora extra nocturna (9pm-6am) con recargo del 75%'),
('HORA_EXTRA_150', 'Hora Extra Dom/Fest Nocturna 150%', 'ingreso', 'hora_extra', FALSE, 0, 'Hora extra dominical/festivo nocturna con recargo del 150%')
ON CONFLICT (code) DO NOTHING;

-- Actualizar descripción de hora extra 100%
UPDATE payroll_concepts 
SET name = 'Hora Extra Dom/Fest Diurna 100%',
    description = 'Hora extra dominical/festivo diurna con recargo del 100%'
WHERE code = 'HORA_EXTRA_100';

-- =====================================================
-- 3. ACTUALIZAR FUNCIÓN DE REGISTRO DE PRÉSTAMO
-- Para asegurar que crea el movimiento de caja correctamente
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
        'Préstamo a empleado: ' || v_employee_name || COALESCE(' - ' || p_reason, ''),
        'PREST-EMP-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 8),
        v_employee_name,
        CURRENT_DATE
    )
    RETURNING id INTO v_movement_id;
    
    -- Actualizar saldo de la cuenta (egreso = resta)
    UPDATE accounts
    SET balance = balance - p_amount,
        updated_at = NOW()
    WHERE id = p_account_id;
    
    -- Crear registro del préstamo
    INSERT INTO employee_loans (
        employee_id,
        loan_date,
        total_amount,
        installments,
        installment_amount,
        remaining_amount,
        paid_amount,
        paid_installments,
        reason,
        cash_movement_id,
        account_id,
        status
    ) VALUES (
        p_employee_id,
        CURRENT_DATE,
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

-- =====================================================
-- 4. VERIFICAR QUE LA TABLA employee_loans EXISTE
-- =====================================================
CREATE TABLE IF NOT EXISTS employee_loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    loan_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount DECIMAL(12,2) NOT NULL,
    installments INTEGER NOT NULL DEFAULT 1,
    installment_amount DECIMAL(12,2) NOT NULL,
    remaining_amount DECIMAL(12,2) NOT NULL,
    paid_amount DECIMAL(12,2) DEFAULT 0,
    paid_installments INTEGER DEFAULT 0,
    reason TEXT,
    status VARCHAR(20) DEFAULT 'activo', -- 'activo', 'pagado', 'cancelado'
    cash_movement_id UUID REFERENCES cash_movements(id),
    account_id UUID REFERENCES accounts(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para búsqueda por empleado
CREATE INDEX IF NOT EXISTS idx_loans_employee ON employee_loans(employee_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON employee_loans(status);

-- =====================================================
-- 5. VERIFICAR DATOS
-- =====================================================
SELECT 'Conceptos de horas extra:' as info;
SELECT code, name, description FROM payroll_concepts WHERE code LIKE 'HORA_EXTRA%' ORDER BY code;

SELECT 'Columnas de employee_loans:' as info;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'employee_loans' 
ORDER BY ordinal_position;
