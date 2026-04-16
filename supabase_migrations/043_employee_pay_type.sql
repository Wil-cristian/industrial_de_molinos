-- =====================================================
-- MIGRACIÓN 043: Tipo de pago por empleado (diario vs hora)
-- =====================================================
-- Agrega campos para empleados con pago por día (ej: Chirry).
-- pay_type: 'hourly' (por horas, default) o 'daily' (por día)
-- daily_rate: tarifa diaria (ej: 145000)
-- attendance_bonus: bono por asistencia semanal completa (ej: 80000)
-- attendance_bonus_days: días mínimos por semana para ganar bono (ej: 6)
-- =====================================================

-- Agregar columnas a la tabla employees
ALTER TABLE employees ADD COLUMN IF NOT EXISTS pay_type VARCHAR(20) DEFAULT 'hourly';
ALTER TABLE employees ADD COLUMN IF NOT EXISTS daily_rate DECIMAL(12,2) DEFAULT 0;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS attendance_bonus DECIMAL(12,2) DEFAULT 0;
ALTER TABLE employees ADD COLUMN IF NOT EXISTS attendance_bonus_days INTEGER DEFAULT 6;

-- Configurar a Chirry martines como empleado de pago diario
UPDATE employees
SET pay_type = 'daily',
    daily_rate = 145000,
    attendance_bonus = 80000,
    attendance_bonus_days = 6
WHERE LOWER(first_name) LIKE '%chirry%'
   OR LOWER(last_name) LIKE '%chirry%';

-- Verificar
DO $$
DECLARE
    v_count INTEGER;
    v_name TEXT;
BEGIN
    SELECT COUNT(*), MIN(first_name || ' ' || last_name)
    INTO v_count, v_name
    FROM employees
    WHERE pay_type = 'daily';
    
    RAISE NOTICE '✅ Empleados con pago diario: % (%)', v_count, COALESCE(v_name, 'ninguno');
END $$;
