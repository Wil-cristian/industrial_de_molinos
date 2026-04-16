-- ============================================================
-- MIGRACIÓN 048: Fix Balance General
--
-- PROBLEMA: El Balance General aparece vacío ("Sin datos de 
-- balance") aunque el Estado de Resultados funciona correctamente.
-- Las cuentas existen en chart_of_accounts. La función 
-- get_balance_general() debe ser recreada con SECURITY DEFINER
-- para garantizar acceso a las tablas subyacentes.
-- ============================================================

-- ═══════════════════════════════════════════════════════════
-- PASO 1: DIAGNÓSTICO - Ver qué datos existen
-- ═══════════════════════════════════════════════════════════

-- 1a. ¿Cuántos asientos existen?
SELECT COUNT(*) AS total_asientos, 
       COUNT(*) FILTER (WHERE status = 'posted') AS posted,
       COUNT(*) FILTER (WHERE status != 'posted') AS otros
FROM journal_entries;

-- 1b. ¿Qué account_codes hay en journal_entry_lines?
SELECT jel.account_code, 
       MAX(jel.account_name) AS nombre,
       coa.type AS tipo_coa,
       COUNT(*) AS lineas,
       SUM(jel.debit) AS total_debit,
       SUM(jel.credit) AS total_credit,
       SUM(jel.debit) - SUM(jel.credit) AS saldo_neto
FROM journal_entry_lines jel
JOIN journal_entries je ON je.id = jel.entry_id
LEFT JOIN chart_of_accounts coa ON coa.code = jel.account_code
WHERE je.status = 'posted'
GROUP BY jel.account_code, coa.type
ORDER BY jel.account_code;

-- 1c. ¿La función existe?
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name = 'get_balance_general'
  AND routine_schema = 'public';

-- ═══════════════════════════════════════════════════════════
-- PASO 2: RECREAR la función con SECURITY DEFINER
-- Esto garantiza que la función ejecute con permisos del owner
-- (bypassing cualquier RLS en las tablas subyacentes)
-- ═══════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS get_balance_general(DATE);

CREATE OR REPLACE FUNCTION get_balance_general(p_hasta_fecha DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
    seccion TEXT,
    tipo VARCHAR,
    codigo VARCHAR,
    cuenta VARCHAR,
    saldo DECIMAL
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE 
            WHEN coa.type = 'asset' THEN '1. ACTIVOS'
            WHEN coa.type = 'liability' THEN '2. PASIVOS'
            WHEN coa.type = 'equity' THEN '3. PATRIMONIO'
        END AS seccion,
        coa.type AS tipo,
        jel.account_code AS codigo,
        MAX(jel.account_name)::VARCHAR AS cuenta,
        SUM(jel.debit) - SUM(jel.credit) AS saldo
    FROM journal_entry_lines jel
    INNER JOIN journal_entries je ON je.id = jel.entry_id
    INNER JOIN chart_of_accounts coa ON coa.code = jel.account_code
    WHERE je.status = 'posted'
      AND je.entry_date <= p_hasta_fecha
      AND coa.type IN ('asset', 'liability', 'equity')
    GROUP BY coa.type, jel.account_code
    HAVING ABS(SUM(jel.debit) - SUM(jel.credit)) > 0.01
    ORDER BY jel.account_code;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════
-- PASO 3: También recrear get_estado_resultados con SECURITY DEFINER
-- (para consistencia y evitar problemas futuros)
-- ═══════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS get_estado_resultados(DATE, DATE);

CREATE OR REPLACE FUNCTION get_estado_resultados(
    p_desde DATE DEFAULT DATE_TRUNC('month', CURRENT_DATE)::DATE,
    p_hasta DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    seccion TEXT,
    tipo VARCHAR,
    codigo VARCHAR,
    cuenta VARCHAR,
    monto DECIMAL
)
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE 
            WHEN coa.type = 'income' THEN '1. INGRESOS'
            WHEN coa.type = 'expense' THEN '2. GASTOS'
        END AS seccion,
        coa.type AS tipo,
        jel.account_code AS codigo,
        MAX(jel.account_name)::VARCHAR AS cuenta,
        CASE 
            WHEN coa.type = 'income' THEN SUM(jel.credit) - SUM(jel.debit)
            WHEN coa.type = 'expense' THEN SUM(jel.debit) - SUM(jel.credit)
        END AS monto
    FROM journal_entry_lines jel
    INNER JOIN journal_entries je ON je.id = jel.entry_id
    INNER JOIN chart_of_accounts coa ON coa.code = jel.account_code
    WHERE je.status = 'posted'
      AND je.entry_date BETWEEN p_desde AND p_hasta
      AND coa.type IN ('income', 'expense')
    GROUP BY coa.type, jel.account_code
    HAVING ABS(SUM(jel.debit) - SUM(jel.credit)) > 0.01
    ORDER BY coa.type DESC, jel.account_code;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════
-- PASO 4: GRANT permisos para que anon pueda ejecutar las RPCs
-- ═══════════════════════════════════════════════════════════

GRANT EXECUTE ON FUNCTION get_balance_general(DATE) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_estado_resultados(DATE, DATE) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_journal_entries(DATE, DATE, VARCHAR, VARCHAR, INTEGER) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- PASO 5: VERIFICACIÓN - Ejecutar la función directamente
-- ═══════════════════════════════════════════════════════════

SELECT * FROM get_balance_general();
SELECT * FROM get_estado_resultados();
