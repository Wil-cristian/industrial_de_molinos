-- ================================================================
-- 044: Agregar cuentas de gastos faltantes en chart_of_accounts
-- 
-- El trigger contable genera asientos con cuenta 621 (Sueldos y Salarios)
-- pero esa cuenta no existía en chart_of_accounts, por lo que el
-- Estado de Resultados no podía mostrar los gastos de nómina.
--
-- También se agregan otras cuentas del schema base que faltaban:
-- 60, 601, 62, 621, 63, 631, 632, 633
-- ================================================================

-- Agregar cuentas de gastos que faltan (con ON CONFLICT para no duplicar)
INSERT INTO chart_of_accounts (code, name, type, parent_code, level, accepts_entries) VALUES
    -- Costo de Ventas
    ('6', 'GASTOS', 'expense', NULL, 1, FALSE),
    ('60', 'COSTO DE VENTAS', 'expense', '6', 2, FALSE),
    ('601', 'Costo de Productos Vendidos', 'expense', '60', 3, TRUE),
    -- Gastos de Personal
    ('62', 'GASTOS DE PERSONAL', 'expense', '6', 2, FALSE),
    ('621', 'Sueldos y Salarios', 'expense', '62', 3, TRUE),
    -- Servicios
    ('63', 'SERVICIOS', 'expense', '6', 2, FALSE),
    ('631', 'Energía Eléctrica', 'expense', '63', 3, TRUE),
    ('632', 'Gas', 'expense', '63', 3, TRUE),
    ('633', 'Agua', 'expense', '63', 3, TRUE)
ON CONFLICT (code) DO NOTHING;

-- Verificación
SELECT code, name, type 
FROM chart_of_accounts 
WHERE code IN ('6', '60', '601', '62', '621', '63', '631', '632', '633')
ORDER BY code;
