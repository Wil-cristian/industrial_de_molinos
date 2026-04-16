-- =====================================================
-- DIAGNÓSTICO: Ver todas las tablas y su contenido
-- Ejecuta ESTO en Supabase SQL Editor
-- =====================================================

-- Primero, ver lista basica de tablas
SELECT 
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns 
     WHERE table_name = t.table_name AND table_schema = 'public') as num_columnas
FROM information_schema.tables t
WHERE table_schema = 'public'
ORDER BY table_name;

-- =====================================================
-- LUEGO EJECUTA ESTAS CONSULTAS UNA POR UNA
-- Para ver cuántos registros tiene cada tabla importante:
-- =====================================================

SELECT 'accounts' as tabla, COUNT(*) as registros FROM accounts;
SELECT 'cash_movements' as tabla, COUNT(*) as registros FROM cash_movements;
SELECT 'customers' as tabla, COUNT(*) as registros FROM customers;
SELECT 'quotations' as tabla, COUNT(*) as registros FROM quotations;
SELECT 'invoices' as tabla, COUNT(*) as registros FROM invoices;
SELECT 'materials' as tabla, COUNT(*) as registros FROM materials;
SELECT 'products' as tabla, COUNT(*) as registros FROM products;
SELECT 'employees' as tabla, COUNT(*) as registros FROM employees;
SELECT 'suppliers' as tabla, COUNT(*) as registros FROM suppliers;
SELECT 'purchases' as tabla, COUNT(*) as registros FROM purchases;
