-- =====================================================
-- LIMPIAR: Préstamos de prueba y corregir saldos
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- PASO 1: Ver estado actual
SELECT 'PRÉSTAMOS ACTIVOS' as info;
SELECT id, employee_id, total_amount, status, loan_date, cash_movement_id, account_id 
FROM employee_loans 
ORDER BY loan_date DESC;

SELECT 'SALDOS DE CUENTAS' as info;
SELECT id, name, balance FROM accounts ORDER BY name;

SELECT 'MOVIMIENTOS DE PRÉSTAMO' as info;
SELECT id, account_id, type, category, amount, description, date
FROM cash_movements 
WHERE category = 'prestamo_empleado'
ORDER BY date DESC;

-- =====================================================
-- PASO 2: Eliminar préstamos huérfanos y asientos
-- =====================================================

-- Eliminar préstamos sin movimiento de caja (huérfanos)
DELETE FROM employee_loans 
WHERE cash_movement_id NOT IN (SELECT id FROM cash_movements)
   OR cash_movement_id IS NULL;

-- Eliminar asientos contables huérfanos (reference_type, no source_type)
DELETE FROM journal_entry_lines WHERE entry_id IN (
  SELECT id FROM journal_entries 
  WHERE reference_type = 'cash_movement' 
  AND reference_id NOT IN (SELECT id FROM cash_movements)
);
DELETE FROM journal_entries 
WHERE reference_type = 'cash_movement' 
AND reference_id NOT IN (SELECT id FROM cash_movements);

-- Verificar
SELECT 'PRÉSTAMOS RESTANTES' as info, count(*) as total FROM employee_loans;
SELECT 'ASIENTOS RESTANTES' as info, count(*) as total FROM journal_entries;

