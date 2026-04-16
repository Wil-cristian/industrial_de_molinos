-- ============================================================
-- Migración 026: Políticas RLS Reales
-- Fecha: 2026-02-21
-- Descripción: Reemplaza las políticas permisivas (USING true)
--   por políticas que requieren usuario autenticado.
--   Revoca acceso anónimo a todas las tablas.
-- ============================================================

-- ============================================================
-- PASO 1: Habilitar RLS en TODAS las tablas
-- ============================================================

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'accounts', 'activities', 'asset_maintenance', 'assets',
            'cash_movements', 'categories', 'chart_of_accounts',
            'company_settings', 'customers', 'employee_incapacities',
            'employee_loans', 'employee_payments', 'employee_tasks',
            'employees', 'invoice_interests', 'invoice_items', 'invoices',
            'journal_entries', 'journal_entry_lines', 'loan_payments',
            'material_movements', 'material_price_history', 'material_prices',
            'materials', 'monthly_expenses', 'notifications',
            'operational_costs', 'payroll', 'payroll_concepts',
            'payroll_details', 'payroll_periods', 'payments',
            'product_components', 'product_templates', 'products',
            'proveedores', 'purchase_items', 'purchases',
            'quotation_items', 'quotations', 'stock_movements',
            'suppliers', 'sync_log'
        ])
    LOOP
        -- Verificar si la tabla existe antes de operar
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            -- Habilitar RLS
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl);
            
            -- Forzar RLS incluso para el dueño de la tabla
            EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', tbl);
            
            RAISE NOTICE 'RLS habilitado en: %', tbl;
        ELSE
            RAISE NOTICE 'Tabla no existe (skip): %', tbl;
        END IF;
    END LOOP;
END $$;

-- ============================================================
-- PASO 2: Eliminar TODAS las políticas permisivas existentes
-- ============================================================

DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
        RAISE NOTICE 'Política eliminada: % en %', pol.policyname, pol.tablename;
    END LOOP;
END $$;

-- ============================================================
-- PASO 3: Crear políticas para usuarios autenticados
-- Modelo: Un solo negocio / todos los usuarios autenticados
-- tienen acceso completo a los datos del negocio.
-- ============================================================

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'accounts', 'activities', 'asset_maintenance', 'assets',
            'cash_movements', 'categories', 'chart_of_accounts',
            'company_settings', 'customers', 'employee_incapacities',
            'employee_loans', 'employee_payments', 'employee_tasks',
            'employees', 'invoice_interests', 'invoice_items', 'invoices',
            'journal_entries', 'journal_entry_lines', 'loan_payments',
            'material_movements', 'material_price_history', 'material_prices',
            'materials', 'monthly_expenses', 'notifications',
            'operational_costs', 'payroll', 'payroll_concepts',
            'payroll_details', 'payroll_periods', 'payments',
            'product_components', 'product_templates', 'products',
            'proveedores', 'purchase_items', 'purchases',
            'quotation_items', 'quotations', 'stock_movements',
            'suppliers', 'sync_log'
        ])
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            -- SELECT: Solo usuarios autenticados
            EXECUTE format(
                'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (true)',
                'authenticated_select_' || tbl, tbl
            );
            
            -- INSERT: Solo usuarios autenticados
            EXECUTE format(
                'CREATE POLICY %I ON public.%I FOR INSERT TO authenticated WITH CHECK (true)',
                'authenticated_insert_' || tbl, tbl
            );
            
            -- UPDATE: Solo usuarios autenticados
            EXECUTE format(
                'CREATE POLICY %I ON public.%I FOR UPDATE TO authenticated USING (true) WITH CHECK (true)',
                'authenticated_update_' || tbl, tbl
            );
            
            -- DELETE: Solo usuarios autenticados
            EXECUTE format(
                'CREATE POLICY %I ON public.%I FOR DELETE TO authenticated USING (true)',
                'authenticated_delete_' || tbl, tbl
            );
            
            RAISE NOTICE 'Políticas creadas para: %', tbl;
        END IF;
    END LOOP;
END $$;

-- ============================================================
-- PASO 4: Revocar acceso del rol anon (anónimo)
-- Solo mantener acceso para registro/login vía Supabase Auth
-- ============================================================

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'accounts', 'activities', 'asset_maintenance', 'assets',
            'cash_movements', 'categories', 'chart_of_accounts',
            'company_settings', 'customers', 'employee_incapacities',
            'employee_loans', 'employee_payments', 'employee_tasks',
            'employees', 'invoice_interests', 'invoice_items', 'invoices',
            'journal_entries', 'journal_entry_lines', 'loan_payments',
            'material_movements', 'material_price_history', 'material_prices',
            'materials', 'monthly_expenses', 'notifications',
            'operational_costs', 'payroll', 'payroll_concepts',
            'payroll_details', 'payroll_periods', 'payments',
            'product_components', 'product_templates', 'products',
            'proveedores', 'purchase_items', 'purchases',
            'quotation_items', 'quotations', 'stock_movements',
            'suppliers', 'sync_log'
        ])
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            -- Revocar todo del rol anónimo
            EXECUTE format('REVOKE ALL ON public.%I FROM anon', tbl);
            
            -- Asegurar que authenticated tiene acceso
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', tbl);
            
            RAISE NOTICE 'Permisos ajustados para: %', tbl;
        END IF;
    END LOOP;
END $$;

-- ============================================================
-- PASO 5: Revocar acceso de anon a funciones sensibles
-- ============================================================

-- Funciones de negocio que NO deben ser accesibles sin auth
DO $$
DECLARE
    func TEXT;
BEGIN
    FOR func IN
        SELECT unnest(ARRAY[
            'approve_quotation_with_materials',
            'approve_quotation_and_create_invoice',
            'deduct_inventory_item',
            'deduct_inventory_for_invoice',
            'deduct_materials_for_quotation',
            'register_payment',
            'register_payroll_payment',
            'register_employee_loan',
            'calculate_payroll_totals',
            'generate_invoice_number',
            'generate_quotation_number',
            'generate_purchase_number',
            'check_stock_availability',
            'check_quotation_stock',
            'check_recipe_stock',
            'revert_material_deduction',
            'calculate_customer_clv',
            'get_related_products',
            'calculate_dso',
            'get_inventory_abc_summary',
            'get_sales_summary',
            'get_customer_mora_summary',
            'get_inventory_with_margins'
        ])
    LOOP
        BEGIN
            -- Revocar ejecución del rol anónimo en todas las overloads
            EXECUTE format('REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon');
            -- Re-grant a authenticated
            EXECUTE format('GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated');
            EXIT; -- Solo necesitamos ejecutar esto una vez
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error revocando funciones: %', SQLERRM;
        END;
    END LOOP;
END $$;

-- ============================================================
-- PASO 6: Revocar acceso a secuencias
-- ============================================================

REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================
-- PASO 7: Verificación
-- ============================================================

-- Listar todas las políticas activas para verificar
DO $$
DECLARE
    pol RECORD;
    count INTEGER := 0;
BEGIN
    FOR pol IN
        SELECT tablename, policyname, permissive, roles, cmd
        FROM pg_policies
        WHERE schemaname = 'public'
        ORDER BY tablename, cmd
    LOOP
        count := count + 1;
    END LOOP;
    RAISE NOTICE 'Total de políticas RLS activas: %', count;
END $$;
