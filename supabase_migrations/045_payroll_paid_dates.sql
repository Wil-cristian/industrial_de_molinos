-- =====================================================
-- MIGRACIÓN 045: Fechas pagadas en nómina
-- =====================================================
-- Agrega columnas paid_start_date y paid_end_date a la tabla payroll
-- para registrar exactamente qué rango de fechas se pagó.
-- Esto evita cobrar dos veces los mismos días y permite calcular
-- automáticamente la fecha de inicio del pago complementario.
-- =====================================================

ALTER TABLE payroll ADD COLUMN IF NOT EXISTS paid_start_date DATE;
ALTER TABLE payroll ADD COLUMN IF NOT EXISTS paid_end_date DATE;

-- Para nóminas existentes, intentar llenar con las fechas del periodo
UPDATE payroll p
SET paid_start_date = pp.start_date,
    paid_end_date = pp.end_date
FROM payroll_periods pp
WHERE p.period_id = pp.id
  AND p.paid_start_date IS NULL;
