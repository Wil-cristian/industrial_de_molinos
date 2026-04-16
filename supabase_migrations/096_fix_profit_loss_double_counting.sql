-- =====================================================
-- FIX: v_profit_loss_monthly duplicaba gastos (bug crítico)
-- 
-- PROBLEMA: monthly_expenses y monthly_variable_expenses 
-- calculaban lo mismo, y luego gross_profit = revenue - fijo - variable
-- = revenue - 2*gastos (DOBLE CONTEO)
--
-- SOLUCIÓN: Separar gastos fijos (nómina, impuestos, servicios) 
-- vs gastos variables (consumibles, transporte, papelería, etc.)
-- =====================================================

CREATE OR REPLACE VIEW v_profit_loss_monthly AS
WITH monthly_sales AS (
    SELECT 
        EXTRACT(YEAR FROM issue_date)::INTEGER AS year,
        EXTRACT(MONTH FROM issue_date)::INTEGER AS month,
        COALESCE(SUM(total), 0) AS revenue
    FROM invoices
    WHERE status != 'cancelled'
    AND (sale_payment_type != 'advance' OR delivery_date IS NOT NULL)
    GROUP BY EXTRACT(YEAR FROM issue_date), EXTRACT(MONTH FROM issue_date)
),
monthly_expenses AS (
    SELECT
        EXTRACT(YEAR FROM date)::INTEGER AS year,
        EXTRACT(MONTH FROM date)::INTEGER AS month,
        -- Gastos fijos: nómina, impuestos, servicios públicos
        COALESCE(SUM(CASE 
            WHEN category IN ('nomina', 'impuestos', 'servicios_publicos') 
            THEN amount ELSE 0 
        END), 0) AS fixed_expenses,
        -- Gastos variables: todo lo demás (consumibles, transporte, papelería, etc.)
        COALESCE(SUM(CASE 
            WHEN category NOT IN ('nomina', 'impuestos', 'servicios_publicos', 'transfer_out', 'transfer_in') 
            THEN amount ELSE 0 
        END), 0) AS variable_expenses
    FROM cash_movements
    WHERE type = 'expense'
    GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)
)
SELECT 
    ms.year,
    ms.month,
    ms.revenue,
    COALESCE(me.fixed_expenses, 0) AS fixed_expenses,
    COALESCE(me.variable_expenses, 0) AS variable_expenses,
    ms.revenue - COALESCE(me.fixed_expenses, 0) - COALESCE(me.variable_expenses, 0) AS gross_profit
FROM monthly_sales ms
LEFT JOIN monthly_expenses me ON ms.year = me.year AND ms.month = me.month
ORDER BY ms.year DESC, ms.month DESC;
