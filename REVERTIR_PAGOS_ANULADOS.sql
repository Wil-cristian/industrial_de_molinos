-- =====================================================
-- SCRIPT PARA REVERTIR PAGOS DE FACTURAS ANULADAS
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- 1. Ver los movimientos actuales de caja
SELECT 
    cm.id,
    cm.description,
    cm.amount,
    cm.type,
    cm.reference,
    a.name as cuenta
FROM cash_movements cm
JOIN accounts a ON a.id = cm.account_id
ORDER BY cm.created_at DESC;

-- 2. Ver facturas anuladas que tenían pagos
SELECT 
    i.id,
    i.series || '-' || i.number as numero,
    i.total,
    i.paid_amount,
    i.status
FROM invoices i
WHERE i.status = 'cancelled';

-- 3. Crear movimientos de reversión para los pagos de facturas anuladas
-- (Esto crea un egreso para balancear el ingreso que quedó)
INSERT INTO cash_movements (account_id, type, category, amount, description, reference, person_name, date)
SELECT 
    cm.account_id,
    'expense',
    'other',
    cm.amount,
    'Reversión por anulación - ' || cm.reference,
    'ANULACION-' || cm.reference,
    cm.person_name,
    NOW()
FROM cash_movements cm
JOIN invoices i ON cm.reference = i.series || '-' || i.number
WHERE i.status = 'cancelled'
AND cm.type = 'income'
AND NOT EXISTS (
    SELECT 1 FROM cash_movements cm2 
    WHERE cm2.reference = 'ANULACION-' || cm.reference
);

-- 4. Actualizar el balance de la cuenta Caja
-- Primero obtenemos el ID de la cuenta Caja
UPDATE accounts 
SET balance = (
    SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE -amount END), 0)
    FROM cash_movements 
    WHERE account_id = accounts.id
)
WHERE name = 'Caja';

-- 5. Resetear el monto pagado de las facturas anuladas
UPDATE invoices
SET paid_amount = 0
WHERE status = 'cancelled';

-- 6. Verificar el resultado
SELECT 
    a.name,
    a.balance,
    (SELECT COUNT(*) FROM cash_movements WHERE account_id = a.id) as movimientos
FROM accounts a;
