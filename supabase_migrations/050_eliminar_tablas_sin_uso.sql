-- =====================================================
-- MIGRACIÓN 050: Eliminar tablas sin uso en el código
-- =====================================================
-- Tablas identificadas como NO referenciadas en el código Dart
-- y con 0 filas (excepto material_price_history con 4 filas):
--
--   1. purchase_items     (0 filas) — FK a purchases
--   2. purchases          (0 filas) — FK a proveedores, tiene trigger
--   3. monthly_expenses   (0 filas) — usada por view v_profit_loss_monthly
--   4. material_price_history (4 filas) — trigger la llena automáticamente
--
-- Tablas ya eliminadas previamente (migración 029):
--   - employee_payments, product_templates
-- Vista suppliers ya no existe.
-- journal_entry_lines NO se elimina (es core de contabilidad).
-- =====================================================

BEGIN;

-- =====================================================
-- PASO 1: Eliminar triggers asociados
-- =====================================================

-- Trigger en purchases que llama update_stock_on_purchase_received()
DROP TRIGGER IF EXISTS trigger_purchase_received ON purchases;

-- Trigger en materials que llama log_material_price_change()
DROP TRIGGER IF EXISTS trigger_material_price_change ON materials;

-- =====================================================
-- PASO 2: Eliminar funciones asociadas
-- =====================================================

DROP FUNCTION IF EXISTS update_stock_on_purchase_received() CASCADE;
DROP FUNCTION IF EXISTS generate_purchase_number() CASCADE;
DROP FUNCTION IF EXISTS log_material_price_change() CASCADE;

-- =====================================================
-- PASO 3: Recrear view v_profit_loss_monthly SIN monthly_expenses
-- =====================================================
-- La view original hacía LEFT JOIN a monthly_expenses para obtener
-- total_fixed (gastos fijos mensuales). Como la tabla tenía 0 filas,
-- siempre retornaba 0. Recreamos sin esa dependencia.

DROP VIEW IF EXISTS v_profit_loss_monthly CASCADE;

CREATE OR REPLACE VIEW v_profit_loss_monthly AS
WITH monthly_sales AS (
    SELECT
        EXTRACT(year FROM issue_date)::integer AS year,
        EXTRACT(month FROM issue_date)::integer AS month,
        COALESCE(SUM(total), 0) AS revenue
    FROM invoices
    WHERE status <> 'cancelled'::invoice_status
    GROUP BY EXTRACT(year FROM issue_date), EXTRACT(month FROM issue_date)
),
monthly_variable_expenses AS (
    SELECT
        EXTRACT(year FROM date)::integer AS year,
        EXTRACT(month FROM date)::integer AS month,
        COALESCE(SUM(amount), 0) AS variable_expenses
    FROM cash_movements
    WHERE type::text = 'expense'
    GROUP BY EXTRACT(year FROM date), EXTRACT(month FROM date)
)
SELECT
    ms.year,
    ms.month,
    ms.revenue,
    0::numeric AS fixed_expenses,
    COALESCE(mve.variable_expenses, 0) AS variable_expenses,
    (ms.revenue - COALESCE(mve.variable_expenses, 0)) AS gross_profit
FROM monthly_sales ms
LEFT JOIN monthly_variable_expenses mve
    ON ms.year = mve.year AND ms.month = mve.month
ORDER BY ms.year DESC, ms.month DESC;

-- =====================================================
-- PASO 4: Eliminar tablas (orden correcto por FK)
-- =====================================================

-- 4a. purchase_items primero (tiene FK -> purchases)
DROP TABLE IF EXISTS purchase_items CASCADE;

-- 4b. purchases (tiene FK -> proveedores)
DROP TABLE IF EXISTS purchases CASCADE;

-- 4c. monthly_expenses (standalone, view ya recreada sin ella)
DROP TABLE IF EXISTS monthly_expenses CASCADE;

-- 4d. material_price_history (FK -> materials, trigger ya eliminado)
DROP TABLE IF EXISTS material_price_history CASCADE;

-- =====================================================
-- PASO 5: Tablas que migración 029 debía eliminar pero no fue ejecutada
-- =====================================================

-- 5a. employee_payments (0 filas, reemplazada por payroll + payroll_details)
DROP TABLE IF EXISTS employee_payments CASCADE;

-- 5b. product_templates (0 filas, reemplazada por products.is_recipe + product_components)
DROP TABLE IF EXISTS product_templates CASCADE;

-- 5c. suppliers (0 filas, tabla duplicada de proveedores — nunca fue convertida a VIEW)
DROP TABLE IF EXISTS suppliers CASCADE;

-- =====================================================
-- PASO 6: Limpiar políticas RLS huérfanas (por seguridad)
-- =====================================================
DO $$
DECLARE
    _table TEXT;
BEGIN
    FOR _table IN SELECT unnest(ARRAY[
        'purchase_items', 'purchases', 
        'monthly_expenses', 'material_price_history',
        'employee_payments', 'product_templates', 'suppliers'
    ]) LOOP
        BEGIN
            EXECUTE format(
                'DROP POLICY IF EXISTS %I ON %I',
                'policy_' || _table || '_crud', _table
            );
        EXCEPTION WHEN undefined_table THEN
            NULL; -- tabla ya no existe
        END;
    END LOOP;
END $$;

COMMIT;

-- =====================================================
-- RESULTADO: 7 tablas eliminadas, 3 funciones eliminadas,
--            2 triggers eliminados, 1 view recreada.
-- Tablas: 53 → 46
-- =====================================================
