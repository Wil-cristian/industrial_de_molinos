-- =====================================================
-- MIGRACIÓN 029: Eliminar tablas no utilizadas
-- =====================================================
-- Tablas identificadas como muertas (sin uso desde Dart):
--   - product_templates (reemplazada por products.is_recipe + product_components)
--   - employee_payments (reemplazada por payroll + payroll_details)
--   - journal_entries + journal_entry_lines (contabilidad no implementada)
-- NOTA: sync_log se mantiene — sí es usada por SettingsDataSource.
-- =====================================================

-- 1. Eliminar journal_entry_lines primero (tiene FK a journal_entries)
DROP TABLE IF EXISTS journal_entry_lines CASCADE;

-- 2. Eliminar journal_entries
DROP TABLE IF EXISTS journal_entries CASCADE;

-- 3. Eliminar employee_payments
DROP TABLE IF EXISTS employee_payments CASCADE;

-- 4. Eliminar product_templates
DROP TABLE IF EXISTS product_templates CASCADE;

-- 5. Eliminar RLS policies asociadas (si existen)
-- Las políticas se eliminan automáticamente con CASCADE,
-- pero limpiamos por seguridad
DO $$
DECLARE
    _table TEXT;
BEGIN
    FOR _table IN SELECT unnest(ARRAY[
        'journal_entry_lines', 'journal_entries', 
        'employee_payments', 'product_templates'
    ]) LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON %I',
            'policy_' || _table || '_crud', _table
        );
    END LOOP;
EXCEPTION WHEN undefined_table THEN
    -- Tabla ya no existe, OK
    NULL;
END $$;

-- 6. Limpiar vistas que referencien tablas eliminadas (si las hay)
DROP VIEW IF EXISTS v_journal_summary CASCADE;
DROP VIEW IF EXISTS v_employee_payment_history CASCADE;

COMMENT ON SCHEMA public IS 'Tablas muertas eliminadas: product_templates, employee_payments, journal_entries, journal_entry_lines';
