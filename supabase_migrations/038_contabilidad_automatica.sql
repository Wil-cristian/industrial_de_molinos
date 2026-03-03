-- =====================================================
-- MIGRACIÓN 038: CONTABILIDAD AUTOMÁTICA
-- Fase 1: Tablas, triggers y vistas contables
-- Industrial de Molinos
-- =====================================================

-- ─────────────────────────────────────────────────────────
-- PASO 1: Recrear tablas de asientos contables
-- (fueron eliminadas en migración 029, ahora se usan de verdad)
-- Forzar DROP porque puede existir con esquema viejo
-- ─────────────────────────────────────────────────────────

-- Eliminar vistas dependientes primero
DROP VIEW IF EXISTS v_libro_diario CASCADE;
DROP VIEW IF EXISTS v_libro_mayor CASCADE;
DROP VIEW IF EXISTS v_balance_comprobacion CASCADE;
DROP VIEW IF EXISTS v_balance_general CASCADE;
DROP VIEW IF EXISTS v_estado_resultados CASCADE;
DROP VIEW IF EXISTS v_estado_resultados_mensual CASCADE;
DROP VIEW IF EXISTS v_pyl_mensual CASCADE;

-- Eliminar triggers dependientes
DROP TRIGGER IF EXISTS trg_auto_journal_cash_movement ON cash_movements;
DROP TRIGGER IF EXISTS trg_auto_journal_payment ON payments;
DROP TRIGGER IF EXISTS trg_auto_journal_invoice ON invoices;

-- Eliminar funciones dependientes
DROP FUNCTION IF EXISTS get_journal_entries CASCADE;
DROP FUNCTION IF EXISTS get_balance_general CASCADE;
DROP FUNCTION IF EXISTS get_estado_resultados CASCADE;
DROP FUNCTION IF EXISTS create_journal_entry CASCADE;
DROP FUNCTION IF EXISTS generate_journal_entry_number CASCADE;
DROP FUNCTION IF EXISTS trg_journal_from_cash_movement CASCADE;
DROP FUNCTION IF EXISTS trg_journal_from_payment CASCADE;
DROP FUNCTION IF EXISTS trg_journal_from_invoice CASCADE;

-- Eliminar tablas (lines primero por FK)
DROP TABLE IF EXISTS journal_entry_lines CASCADE;
DROP TABLE IF EXISTS journal_entries CASCADE;

CREATE TABLE journal_entries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_number    VARCHAR(20) NOT NULL,
    entry_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    description     TEXT NOT NULL,
    reference_type  VARCHAR(30),  -- 'cash_movement', 'payment', 'invoice', 'payroll', 'loan', 'purchase'
    reference_id    UUID,         -- ID del registro origen
    total_debit     DECIMAL(12,2) DEFAULT 0,
    total_credit    DECIMAL(12,2) DEFAULT 0,
    is_auto         BOOLEAN DEFAULT TRUE, -- TRUE = generado automáticamente
    status          VARCHAR(20) DEFAULT 'posted', -- 'posted', 'cancelled'
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE journal_entry_lines (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id        UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_code    VARCHAR(20) NOT NULL,
    account_name    VARCHAR(255) NOT NULL,
    description     TEXT,
    debit           DECIMAL(12,2) DEFAULT 0,
    credit          DECIMAL(12,2) DEFAULT 0,
    sort_order      INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_journal_entries_ref ON journal_entries(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_number ON journal_entries(entry_number);
CREATE INDEX IF NOT EXISTS idx_jel_entry ON journal_entry_lines(entry_id);
CREATE INDEX IF NOT EXISTS idx_jel_account ON journal_entry_lines(account_code);

-- RLS
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "journal_entries_all" ON journal_entries;
CREATE POLICY "journal_entries_all" ON journal_entries FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "journal_entry_lines_all" ON journal_entry_lines;
CREATE POLICY "journal_entry_lines_all" ON journal_entry_lines FOR ALL USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────
-- PASO 2: Ampliar plan de cuentas con cuentas faltantes
-- ─────────────────────────────────────────────────────────

INSERT INTO chart_of_accounts (code, name, type, parent_code, level, accepts_entries) VALUES
    -- Cuentas de detalle faltantes
    ('103', 'Cuenta Industrial de Molinos', 'asset', '10', 3, TRUE),
    ('104', 'Cuenta Daniela', 'asset', '10', 3, TRUE),
    ('122', 'Préstamos a Empleados', 'asset', '12', 3, TRUE),
    ('14', 'ANTICIPOS', 'asset', '1', 2, FALSE),
    ('141', 'Anticipos a Proveedores', 'asset', '14', 3, TRUE),
    ('41', 'REMUNERACIONES POR PAGAR', 'liability', '4', 2, FALSE),
    ('411', 'Sueldos por Pagar', 'liability', '41', 3, TRUE),
    ('622', 'Horas Extra', 'expense', '62', 3, TRUE),
    ('623', 'Bonificaciones', 'expense', '62', 3, TRUE),
    ('64', 'GASTOS ADMINISTRATIVOS', 'expense', '6', 2, FALSE),
    ('641', 'Alquiler', 'expense', '64', 3, TRUE),
    ('642', 'Otros Gastos', 'expense', '64', 3, TRUE),
    ('65', 'GASTOS DE VENTAS', 'expense', '6', 2, FALSE),
    ('651', 'Comisiones', 'expense', '65', 3, TRUE),
    ('66', 'GASTOS FINANCIEROS', 'expense', '6', 2, FALSE),
    ('661', 'Intereses', 'expense', '66', 3, TRUE),
    ('703', 'Otros Ingresos', 'income', '70', 3, TRUE),
    ('71', 'INGRESOS FINANCIEROS', 'income', '7', 2, FALSE),
    ('711', 'Intereses Ganados', 'income', '71', 3, TRUE)
ON CONFLICT (code) DO NOTHING;


-- ─────────────────────────────────────────────────────────
-- PASO 3: Función para generar número de asiento
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION generate_journal_entry_number()
RETURNS TEXT AS $$
DECLARE
    v_year TEXT;
    v_seq INTEGER;
BEGIN
    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(entry_number FROM 5) AS INTEGER)
    ), 0) + 1 INTO v_seq
    FROM journal_entries
    WHERE entry_number LIKE v_year || '%';

    RETURN v_year || '-' || LPAD(v_seq::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────
-- PASO 4: Función principal para crear asiento contable
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_journal_entry(
    p_date          DATE,
    p_description   TEXT,
    p_ref_type      VARCHAR(30),
    p_ref_id        UUID,
    p_lines         JSONB  -- [{"account_code": "101", "account_name": "Caja", "debit": 100, "credit": 0}, ...]
)
RETURNS UUID AS $$
DECLARE
    v_entry_id UUID;
    v_entry_number TEXT;
    v_total_debit DECIMAL(12,2) := 0;
    v_total_credit DECIMAL(12,2) := 0;
    v_line JSONB;
    v_sort INTEGER := 0;
BEGIN
    -- Generar número
    v_entry_number := generate_journal_entry_number();
    
    -- Calcular totales
    FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
    LOOP
        v_total_debit := v_total_debit + COALESCE((v_line->>'debit')::DECIMAL, 0);
        v_total_credit := v_total_credit + COALESCE((v_line->>'credit')::DECIMAL, 0);
    END LOOP;
    
    -- Verificar que el asiento esté balanceado
    IF ABS(v_total_debit - v_total_credit) > 0.01 THEN
        RAISE EXCEPTION 'Asiento desbalanceado: Débito=%, Crédito=%', v_total_debit, v_total_credit;
    END IF;
    
    -- Crear cabecera
    INSERT INTO journal_entries (entry_number, entry_date, description, reference_type, reference_id, total_debit, total_credit)
    VALUES (v_entry_number, p_date, p_description, p_ref_type, p_ref_id, v_total_debit, v_total_credit)
    RETURNING id INTO v_entry_id;
    
    -- Crear líneas
    FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
    LOOP
        v_sort := v_sort + 1;
        INSERT INTO journal_entry_lines (entry_id, account_code, account_name, description, debit, credit, sort_order)
        VALUES (
            v_entry_id,
            v_line->>'account_code',
            v_line->>'account_name',
            p_description,
            COALESCE((v_line->>'debit')::DECIMAL, 0),
            COALESCE((v_line->>'credit')::DECIMAL, 0),
            v_sort
        );
    END LOOP;
    
    RETURN v_entry_id;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────
-- PASO 5: Trigger automático desde CASH_MOVEMENTS
-- Cada ingreso/gasto/traslado genera un asiento
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION trg_journal_from_cash_movement()
RETURNS TRIGGER AS $$
DECLARE
    v_account_name TEXT;
    v_debit_code VARCHAR(20);
    v_debit_name VARCHAR(255);
    v_credit_code VARCHAR(20);
    v_credit_name VARCHAR(255);
    v_lines JSONB;
BEGIN
    -- Obtener nombre de la cuenta bancaria/caja
    SELECT name INTO v_account_name FROM accounts WHERE id = NEW.account_id;
    
    -- Determinar cuenta contable según el nombre de la cuenta
    IF v_account_name ILIKE '%caja%' THEN
        v_debit_code := '101'; v_debit_name := 'Caja';
    ELSIF v_account_name ILIKE '%industrial%' THEN
        v_debit_code := '103'; v_debit_name := 'Cuenta Industrial de Molinos';
    ELSIF v_account_name ILIKE '%daniela%' THEN
        v_debit_code := '104'; v_debit_name := 'Cuenta Daniela';
    ELSE
        v_debit_code := '102'; v_debit_name := 'Bancos';
    END IF;

    -- Determinar cuenta contraparte según categoría
    IF NEW.type = 'income' THEN
        -- INGRESO: Débito a Caja/Banco, Crédito a cuenta de ingreso
        CASE NEW.category
            WHEN 'sale' THEN v_credit_code := '701'; v_credit_name := 'Ventas de Productos';
            WHEN 'collection' THEN v_credit_code := '121'; v_credit_name := 'Clientes (Cobro)';
            WHEN 'service' THEN v_credit_code := '702'; v_credit_name := 'Ventas de Servicios';
            ELSE v_credit_code := '703'; v_credit_name := 'Otros Ingresos';
        END CASE;
        
        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', NEW.amount, 'credit', 0),
            jsonb_build_object('account_code', v_credit_code, 'account_name', v_credit_name, 'debit', 0, 'credit', NEW.amount)
        );
        
    ELSIF NEW.type = 'expense' THEN
        -- GASTO: Débito a cuenta de gasto, Crédito a Caja/Banco
        CASE NEW.category
            WHEN 'purchase' THEN v_credit_code := '601'; v_credit_name := 'Costo de Productos Vendidos';
            WHEN 'salary' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'payroll' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'services' THEN v_credit_code := '631'; v_credit_name := 'Energía Eléctrica';
            WHEN 'rent' THEN v_credit_code := '641'; v_credit_name := 'Alquiler';
            WHEN 'transfer_out' THEN v_credit_code := NULL; -- Los traslados se manejan aparte
            ELSE v_credit_code := '642'; v_credit_name := 'Otros Gastos';
        END CASE;
        
        -- No generar asiento para transfer_out (se hace en el transfer_in)
        IF v_credit_code IS NULL THEN
            RETURN NEW;
        END IF;
        
        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', v_credit_code, 'account_name', v_credit_name, 'debit', NEW.amount, 'credit', 0),
            jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', 0, 'credit', NEW.amount)
        );

    ELSIF NEW.type = 'transfer' THEN
        -- TRASLADO: Solo procesar transfer_in
        IF NEW.category = 'transfer_in' AND NEW.to_account_id IS NOT NULL THEN
            DECLARE
                v_from_name TEXT;
                v_from_code VARCHAR(20);
                v_from_acct_name VARCHAR(255);
            BEGIN
                -- Cuenta origen (de donde salió el dinero)
                SELECT name INTO v_from_name FROM accounts WHERE id = NEW.to_account_id;
                IF v_from_name ILIKE '%caja%' THEN
                    v_from_code := '101'; v_from_acct_name := 'Caja';
                ELSIF v_from_name ILIKE '%industrial%' THEN
                    v_from_code := '103'; v_from_acct_name := 'Cuenta Industrial de Molinos';
                ELSIF v_from_name ILIKE '%daniela%' THEN
                    v_from_code := '104'; v_from_acct_name := 'Cuenta Daniela';
                ELSE
                    v_from_code := '102'; v_from_acct_name := 'Bancos';
                END IF;
                
                v_lines := jsonb_build_array(
                    jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', NEW.amount, 'credit', 0),
                    jsonb_build_object('account_code', v_from_code, 'account_name', v_from_acct_name, 'debit', 0, 'credit', NEW.amount)
                );
            END;
        ELSE
            RETURN NEW; -- Ignorar transfer_out
        END IF;
    END IF;

    -- Crear el asiento
    IF v_lines IS NOT NULL THEN
        PERFORM create_journal_entry(
            NEW.date::DATE,
            COALESCE(NEW.description, NEW.type || ' - ' || NEW.category),
            'cash_movement',
            NEW.id,
            v_lines
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_journal_cash_movement ON cash_movements;
CREATE TRIGGER trg_auto_journal_cash_movement
    AFTER INSERT ON cash_movements
    FOR EACH ROW
    EXECUTE FUNCTION trg_journal_from_cash_movement();


-- ─────────────────────────────────────────────────────────
-- PASO 6: Trigger automático desde PAYMENTS (cobros de facturas)
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION trg_journal_from_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_invoice_number TEXT;
    v_customer_name TEXT;
    v_lines JSONB;
BEGIN
    -- Obtener datos de la factura
    SELECT full_number, customer_name INTO v_invoice_number, v_customer_name
    FROM invoices WHERE id = NEW.invoice_id;

    -- Asiento: Caja/Banco (Débito) ↔ Cuentas por Cobrar (Crédito)
    -- Nota: El cash_movement ya genera su propio asiento de caja.
    -- Este asiento refleja la REDUCCIÓN de la cuenta por cobrar del cliente.
    v_lines := jsonb_build_array(
        jsonb_build_object('account_code', '121', 'account_name', 'Clientes - ' || v_customer_name, 'debit', 0, 'credit', NEW.amount),
        jsonb_build_object('account_code', '701', 'account_name', 'Ventas de Productos', 'debit', NEW.amount, 'credit', 0)
    );

    PERFORM create_journal_entry(
        NEW.payment_date,
        'Cobro factura ' || COALESCE(v_invoice_number, '') || ' - ' || COALESCE(v_customer_name, ''),
        'payment',
        NEW.id,
        v_lines
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_journal_payment ON payments;
CREATE TRIGGER trg_auto_journal_payment
    AFTER INSERT ON payments
    FOR EACH ROW
    EXECUTE FUNCTION trg_journal_from_payment();


-- ─────────────────────────────────────────────────────────
-- PASO 7: Trigger automático desde INVOICES (emisión de factura)
-- Cuando se emite una factura a crédito, genera CxC
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION trg_journal_from_invoice()
RETURNS TRIGGER AS $$
DECLARE
    v_lines JSONB;
BEGIN
    -- Solo al cambiar a status 'issued' o 'partial'
    IF NEW.status IN ('issued', 'partial') AND 
       (OLD.status IS NULL OR OLD.status = 'draft') THEN
        
        -- Asiento: CxC Clientes (Débito) ↔ Ventas (Crédito)
        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', '121', 'account_name', 'Clientes - ' || NEW.customer_name, 'debit', NEW.total, 'credit', 0),
            jsonb_build_object('account_code', '701', 'account_name', 'Ventas de Productos', 'debit', 0, 'credit', NEW.total)
        );

        PERFORM create_journal_entry(
            NEW.issue_date,
            'Factura emitida ' || COALESCE(NEW.full_number, '') || ' - ' || COALESCE(NEW.customer_name, ''),
            'invoice',
            NEW.id,
            v_lines
        );
    END IF;

    -- Anulación: revertir el asiento
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', '701', 'account_name', 'Ventas de Productos (Anulación)', 'debit', NEW.total, 'credit', 0),
            jsonb_build_object('account_code', '121', 'account_name', 'Clientes - ' || NEW.customer_name, 'debit', 0, 'credit', NEW.total)
        );

        PERFORM create_journal_entry(
            CURRENT_DATE,
            'Anulación factura ' || COALESCE(NEW.full_number, '') || ' - ' || COALESCE(NEW.customer_name, ''),
            'invoice_cancel',
            NEW.id,
            v_lines
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_journal_invoice ON invoices;
CREATE TRIGGER trg_auto_journal_invoice
    AFTER UPDATE ON invoices
    FOR EACH ROW
    EXECUTE FUNCTION trg_journal_from_invoice();


-- ─────────────────────────────────────────────────────────
-- PASO 8: Vistas para reportes contables
-- ─────────────────────────────────────────────────────────

-- LIBRO DIARIO: Lista cronológica de todos los asientos
CREATE OR REPLACE VIEW v_libro_diario AS
SELECT 
    je.entry_number AS numero,
    je.entry_date AS fecha,
    je.description AS descripcion,
    je.reference_type AS tipo_referencia,
    jel.account_code AS codigo_cuenta,
    jel.account_name AS nombre_cuenta,
    jel.debit AS debe,
    jel.credit AS haber,
    je.status,
    je.is_auto,
    je.created_at
FROM journal_entries je
JOIN journal_entry_lines jel ON jel.entry_id = je.id
WHERE je.status = 'posted'
ORDER BY je.entry_date DESC, je.entry_number DESC, jel.sort_order;

-- LIBRO MAYOR: Movimientos agrupados por cuenta
CREATE OR REPLACE VIEW v_libro_mayor AS
SELECT
    jel.account_code AS codigo,
    jel.account_name AS cuenta,
    je.entry_date AS fecha,
    je.entry_number AS asiento,
    je.description AS descripcion,
    jel.debit AS debe,
    jel.credit AS haber,
    SUM(jel.debit - jel.credit) OVER (
        PARTITION BY jel.account_code 
        ORDER BY je.entry_date, je.entry_number
    ) AS saldo_acumulado
FROM journal_entry_lines jel
JOIN journal_entries je ON je.id = jel.entry_id
WHERE je.status = 'posted'
ORDER BY jel.account_code, je.entry_date, je.entry_number;

-- BALANCE DE COMPROBACIÓN: Saldos por cuenta
CREATE OR REPLACE VIEW v_balance_comprobacion AS
SELECT
    jel.account_code AS codigo,
    MAX(jel.account_name) AS cuenta,
    COALESCE(coa.type, 'unknown') AS tipo,
    COALESCE(coa.level, 3) AS nivel,
    SUM(jel.debit) AS total_debe,
    SUM(jel.credit) AS total_haber,
    SUM(jel.debit) - SUM(jel.credit) AS saldo
FROM journal_entry_lines jel
JOIN journal_entries je ON je.id = jel.entry_id
LEFT JOIN chart_of_accounts coa ON coa.code = jel.account_code
WHERE je.status = 'posted'
GROUP BY jel.account_code, coa.type, coa.level
ORDER BY jel.account_code;

-- BALANCE GENERAL: Activos, Pasivos, Patrimonio
CREATE OR REPLACE VIEW v_balance_general AS
SELECT
    CASE 
        WHEN coa.type = 'asset' THEN '1. ACTIVOS'
        WHEN coa.type = 'liability' THEN '2. PASIVOS'
        WHEN coa.type = 'equity' THEN '3. PATRIMONIO'
    END AS seccion,
    coa.type AS tipo,
    jel.account_code AS codigo,
    MAX(jel.account_name) AS cuenta,
    SUM(jel.debit) - SUM(jel.credit) AS saldo
FROM journal_entry_lines jel
JOIN journal_entries je ON je.id = jel.entry_id
LEFT JOIN chart_of_accounts coa ON coa.code = jel.account_code
WHERE je.status = 'posted'
  AND coa.type IN ('asset', 'liability', 'equity')
GROUP BY coa.type, jel.account_code
HAVING ABS(SUM(jel.debit) - SUM(jel.credit)) > 0.01
ORDER BY jel.account_code;

-- ESTADO DE RESULTADOS: Ingresos - Gastos
CREATE OR REPLACE VIEW v_estado_resultados AS
SELECT
    CASE 
        WHEN coa.type = 'income' THEN '1. INGRESOS'
        WHEN coa.type = 'expense' THEN '2. GASTOS'
    END AS seccion,
    coa.type AS tipo,
    jel.account_code AS codigo,
    MAX(jel.account_name) AS cuenta,
    CASE 
        WHEN coa.type = 'income' THEN SUM(jel.credit) - SUM(jel.debit)
        WHEN coa.type = 'expense' THEN SUM(jel.debit) - SUM(jel.credit)
    END AS monto
FROM journal_entry_lines jel
JOIN journal_entries je ON je.id = jel.entry_id
LEFT JOIN chart_of_accounts coa ON coa.code = jel.account_code
WHERE je.status = 'posted'
  AND coa.type IN ('income', 'expense')
GROUP BY coa.type, jel.account_code
HAVING ABS(SUM(jel.debit) - SUM(jel.credit)) > 0.01
ORDER BY coa.type DESC, jel.account_code;

-- ESTADO DE RESULTADOS POR MES
CREATE OR REPLACE VIEW v_estado_resultados_mensual AS
SELECT
    DATE_TRUNC('month', je.entry_date) AS mes,
    coa.type AS tipo,
    SUM(CASE WHEN coa.type = 'income' THEN jel.credit - jel.debit ELSE 0 END) AS ingresos,
    SUM(CASE WHEN coa.type = 'expense' THEN jel.debit - jel.credit ELSE 0 END) AS gastos
FROM journal_entry_lines jel
JOIN journal_entries je ON je.id = jel.entry_id
LEFT JOIN chart_of_accounts coa ON coa.code = jel.account_code
WHERE je.status = 'posted'
  AND coa.type IN ('income', 'expense')
GROUP BY DATE_TRUNC('month', je.entry_date), coa.type
ORDER BY mes DESC, tipo;

-- RESUMEN ESTADO RESULTADOS POR MES (una fila por mes)
CREATE OR REPLACE VIEW v_pyl_mensual AS
SELECT
    DATE_TRUNC('month', je.entry_date) AS mes,
    SUM(CASE WHEN coa.type = 'income' THEN jel.credit - jel.debit ELSE 0 END) AS ingresos,
    SUM(CASE WHEN coa.type = 'expense' THEN jel.debit - jel.credit ELSE 0 END) AS gastos,
    SUM(CASE WHEN coa.type = 'income' THEN jel.credit - jel.debit ELSE 0 END) -
    SUM(CASE WHEN coa.type = 'expense' THEN jel.debit - jel.credit ELSE 0 END) AS utilidad_neta,
    CASE 
        WHEN SUM(CASE WHEN coa.type = 'income' THEN jel.credit - jel.debit ELSE 0 END) > 0 THEN
            ROUND(
                ((SUM(CASE WHEN coa.type = 'income' THEN jel.credit - jel.debit ELSE 0 END) -
                  SUM(CASE WHEN coa.type = 'expense' THEN jel.debit - jel.credit ELSE 0 END)) /
                 SUM(CASE WHEN coa.type = 'income' THEN jel.credit - jel.debit ELSE 0 END) * 100
                ), 2)
        ELSE 0
    END AS margen_pct
FROM journal_entry_lines jel
JOIN journal_entries je ON je.id = jel.entry_id
LEFT JOIN chart_of_accounts coa ON coa.code = jel.account_code
WHERE je.status = 'posted'
  AND coa.type IN ('income', 'expense')
GROUP BY DATE_TRUNC('month', je.entry_date)
ORDER BY mes DESC;


-- ─────────────────────────────────────────────────────────
-- PASO 9: Función RPC para consultar libro diario desde Flutter
-- ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_journal_entries(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_account_code VARCHAR DEFAULT NULL,
    p_reference_type VARCHAR DEFAULT NULL,
    p_limit INTEGER DEFAULT 200
)
RETURNS TABLE (
    entry_id UUID,
    entry_number VARCHAR,
    entry_date DATE,
    description TEXT,
    reference_type VARCHAR,
    reference_id UUID,
    total_debit DECIMAL,
    total_credit DECIMAL,
    is_auto BOOLEAN,
    status VARCHAR,
    created_at TIMESTAMPTZ,
    lines JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        je.id,
        je.entry_number,
        je.entry_date,
        je.description,
        je.reference_type,
        je.reference_id,
        je.total_debit,
        je.total_credit,
        je.is_auto,
        je.status,
        je.created_at,
        (
            SELECT jsonb_agg(jsonb_build_object(
                'account_code', jel2.account_code,
                'account_name', jel2.account_name,
                'debit', jel2.debit,
                'credit', jel2.credit
            ) ORDER BY jel2.sort_order)
            FROM journal_entry_lines jel2
            WHERE jel2.entry_id = je.id
        ) AS lines
    FROM journal_entries je
    WHERE je.status = 'posted'
      AND (p_start_date IS NULL OR je.entry_date >= p_start_date)
      AND (p_end_date IS NULL OR je.entry_date <= p_end_date)
      AND (p_reference_type IS NULL OR je.reference_type = p_reference_type)
      AND (p_account_code IS NULL OR EXISTS (
          SELECT 1 FROM journal_entry_lines jel3
          WHERE jel3.entry_id = je.id AND jel3.account_code = p_account_code
      ))
    ORDER BY je.entry_date DESC, je.entry_number DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener balance general
CREATE OR REPLACE FUNCTION get_balance_general(p_hasta_fecha DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
    seccion TEXT,
    tipo VARCHAR,
    codigo VARCHAR,
    cuenta VARCHAR,
    saldo DECIMAL
) AS $$
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
    JOIN journal_entries je ON je.id = jel.entry_id
    LEFT JOIN chart_of_accounts coa ON coa.code = jel.account_code
    WHERE je.status = 'posted'
      AND je.entry_date <= p_hasta_fecha
      AND coa.type IN ('asset', 'liability', 'equity')
    GROUP BY coa.type, jel.account_code
    HAVING ABS(SUM(jel.debit) - SUM(jel.credit)) > 0.01
    ORDER BY jel.account_code;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estado de resultados por rango
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
) AS $$
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
    JOIN journal_entries je ON je.id = jel.entry_id
    LEFT JOIN chart_of_accounts coa ON coa.code = jel.account_code
    WHERE je.status = 'posted'
      AND je.entry_date BETWEEN p_desde AND p_hasta
      AND coa.type IN ('income', 'expense')
    GROUP BY coa.type, jel.account_code
    HAVING ABS(SUM(jel.debit) - SUM(jel.credit)) > 0.01
    ORDER BY coa.type DESC, jel.account_code;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────
-- VERIFICACIÓN
-- ─────────────────────────────────────────────────────────

-- Verificar tablas creadas
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'journal_entries') THEN
        RAISE NOTICE '✅ journal_entries creada';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'journal_entry_lines') THEN
        RAISE NOTICE '✅ journal_entry_lines creada';
    END IF;
END $$;

-- Contar cuentas en plan contable
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM chart_of_accounts;
    RAISE NOTICE '📊 Plan de cuentas: % cuentas', v_count;
END $$;

COMMENT ON TABLE journal_entries IS 'Asientos contables automáticos - generados por triggers desde cash_movements, payments, invoices';
COMMENT ON TABLE journal_entry_lines IS 'Líneas de asientos contables con partida doble (debe/haber)';
