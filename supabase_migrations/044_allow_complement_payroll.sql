-- =====================================================
-- MIGRACIÓN 044: Permitir pagos complementarios de nómina
-- =====================================================
-- Elimina el constraint UNIQUE(employee_id, period_id) de la tabla payroll
-- para permitir pagos complementarios cuando la nómina se adelanta
-- y quedan días pendientes por pagar en la misma quincena.
-- =====================================================

-- Eliminar el constraint único que impide crear 2 nóminas del mismo empleado en el mismo periodo
ALTER TABLE payroll DROP CONSTRAINT IF EXISTS payroll_employee_id_period_id_key;

-- Verificar
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'payroll_employee_id_period_id_key'
        AND table_name = 'payroll'
    ) THEN
        RAISE NOTICE '✅ Constraint eliminado: ahora se permiten pagos complementarios';
    ELSE
        RAISE NOTICE '⚠️ El constraint aún existe';
    END IF;
END $$;
