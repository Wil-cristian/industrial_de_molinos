-- =====================================================
-- MIGRACIÓN 041: FIX CONTABILIDAD - Numeración, Rotulación y Balances
-- =====================================================
-- Problemas detectados:
-- 1. Todos los asientos tienen el MISMO número (2026-000001)
--    → Bug en SUBSTRING(entry_number FROM 5) que parsea '-000001' como -1
-- 2. Las cobranzas dicen "Clientes (Cobro)" en vez de "Clientes - [nombre]"
--    → El cash_movement trigger no usa person_name
-- 3. El saldo de Caja está corrupto (986 millones)
--    → Recalcular balances de accounts desde cash_movements
-- =====================================================

-- ─────────────────────────────────────────────────────────
-- PASO 1: Corregir generación de número de asiento
-- Bug: SUBSTRING(entry_number FROM 5) sobre '2026-000001' da '-000001' = -1
-- Fix: Usar SPLIT_PART para extraer solo la parte numérica
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_journal_entry_number()
RETURNS TEXT AS $$
DECLARE
    v_year TEXT;
    v_seq INTEGER;
BEGIN
    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(
        CAST(SPLIT_PART(entry_number, '-', 2) AS INTEGER)
    ), 0) + 1 INTO v_seq
    FROM journal_entries
    WHERE entry_number LIKE v_year || '-%';

    RETURN v_year || '-' || LPAD(v_seq::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────
-- PASO 2: Re-numerar asientos existentes (todos tienen 2026-000001)
-- ─────────────────────────────────────────────────────────
DO $$
DECLARE
    r RECORD;
    v_seq INTEGER := 0;
BEGIN
    FOR r IN 
        SELECT id FROM journal_entries
        ORDER BY entry_date ASC, created_at ASC
    LOOP
        v_seq := v_seq + 1;
        UPDATE journal_entries 
        SET entry_number = TO_CHAR(CURRENT_DATE, 'YYYY') || '-' || LPAD(v_seq::TEXT, 6, '0')
        WHERE id = r.id;
    END LOOP;
    RAISE NOTICE '✅ Re-numerados % asientos contables', v_seq;
END $$;

-- ─────────────────────────────────────────────────────────
-- PASO 3: Mejorar trigger de cash_movements para rotular
-- correctamente las cobranzas con nombre de cliente
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION trg_journal_from_cash_movement()
RETURNS TRIGGER AS $$
DECLARE
    v_account_name TEXT;
    v_debit_code VARCHAR(20);
    v_debit_name VARCHAR(255);
    v_credit_code VARCHAR(20);
    v_credit_name VARCHAR(255);
    v_description TEXT;
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

    -- Descripción base
    v_description := COALESCE(NEW.description, NEW.type || ' - ' || NEW.category);

    -- Determinar cuenta contraparte según categoría
    IF NEW.type = 'income' THEN
        -- INGRESO: Débito a Caja/Banco, Crédito a cuenta de ingreso
        CASE NEW.category
            WHEN 'sale' THEN 
                v_credit_code := '701'; 
                v_credit_name := 'Ventas de Productos';
            WHEN 'collection' THEN 
                v_credit_code := '121'; 
                -- Usar nombre del cliente (person_name) si está disponible
                v_credit_name := 'Clientes - ' || COALESCE(NEW.person_name, 'Cobro');
            WHEN 'service' THEN 
                v_credit_code := '702'; 
                v_credit_name := 'Ventas de Servicios';
            ELSE 
                v_credit_code := '703'; 
                v_credit_name := 'Otros Ingresos';
        END CASE;
        
        v_lines := jsonb_build_array(
            jsonb_build_object(
                'account_code', v_debit_code, 
                'account_name', v_debit_name, 
                'debit', NEW.amount, 
                'credit', 0
            ),
            jsonb_build_object(
                'account_code', v_credit_code, 
                'account_name', v_credit_name, 
                'debit', 0, 
                'credit', NEW.amount
            )
        );
        
    ELSIF NEW.type = 'expense' THEN
        -- GASTO: Débito a cuenta de gasto, Crédito a Caja/Banco
        CASE NEW.category
            WHEN 'purchase' THEN v_credit_code := '601'; v_credit_name := 'Costo de Productos Vendidos';
            WHEN 'salary' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'payroll' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'services' THEN v_credit_code := '631'; v_credit_name := 'Energía Eléctrica';
            WHEN 'rent' THEN v_credit_code := '641'; v_credit_name := 'Alquiler';
            WHEN 'transfer_out' THEN v_credit_code := NULL;
            ELSE v_credit_code := '642'; v_credit_name := 'Otros Gastos';
        END CASE;
        
        -- No generar asiento para transfer_out (se hace en el transfer_in)
        IF v_credit_code IS NULL THEN
            RETURN NEW;
        END IF;
        
        v_lines := jsonb_build_array(
            jsonb_build_object(
                'account_code', v_credit_code, 
                'account_name', v_credit_name, 
                'debit', NEW.amount, 
                'credit', 0
            ),
            jsonb_build_object(
                'account_code', v_debit_code, 
                'account_name', v_debit_name, 
                'debit', 0, 
                'credit', NEW.amount
            )
        );

    ELSIF NEW.type = 'transfer' THEN
        -- TRASLADO: Solo procesar transfer_in
        IF NEW.category = 'transfer_in' AND NEW.to_account_id IS NOT NULL THEN
            DECLARE
                v_from_name TEXT;
                v_from_code VARCHAR(20);
                v_from_acct_name VARCHAR(255);
            BEGIN
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
                    jsonb_build_object(
                        'account_code', v_debit_code, 
                        'account_name', v_debit_name, 
                        'debit', NEW.amount, 
                        'credit', 0
                    ),
                    jsonb_build_object(
                        'account_code', v_from_code, 
                        'account_name', v_from_acct_name, 
                        'debit', 0, 
                        'credit', NEW.amount
                    )
                );
            END;
        ELSE
            RETURN NEW;
        END IF;
    END IF;

    -- Crear el asiento
    IF v_lines IS NOT NULL THEN
        PERFORM create_journal_entry(
            NEW.date::DATE,
            v_description,
            'cash_movement',
            NEW.id,
            v_lines
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─────────────────────────────────────────────────────────
-- PASO 4: Corregir los labels de asientos existentes
-- Cambiar "Clientes (Cobro)" a "Clientes - [nombre]" 
-- usando datos del cash_movement original
-- ─────────────────────────────────────────────────────────
UPDATE journal_entry_lines jel
SET account_name = 'Clientes - ' || COALESCE(cm.person_name, 'Cobro')
FROM journal_entries je
JOIN cash_movements cm ON cm.id = je.reference_id
WHERE jel.entry_id = je.id
  AND je.reference_type = 'cash_movement'
  AND jel.account_code = '121'
  AND jel.account_name LIKE 'Clientes (Cobro)%';


-- ─────────────────────────────────────────────────────────
-- PASO 5: Recalcular balances de accounts desde cash_movements
-- El balance de Caja está corrupto (986 millones)
-- ─────────────────────────────────────────────────────────
UPDATE accounts a
SET balance = COALESCE(calc.net_balance, 0)
FROM (
    SELECT 
        account_id,
        SUM(
            CASE 
                WHEN type = 'income' THEN amount
                WHEN type = 'transfer' AND category = 'transfer_in' THEN amount
                WHEN type = 'expense' THEN -amount
                WHEN type = 'transfer' AND category = 'transfer_out' THEN -amount
                ELSE 0
            END
        ) AS net_balance
    FROM cash_movements
    GROUP BY account_id
) calc
WHERE a.id = calc.account_id;

-- Para cuentas SIN movimientos, poner balance en 0
UPDATE accounts 
SET balance = 0 
WHERE id NOT IN (SELECT DISTINCT account_id FROM cash_movements);


-- ─────────────────────────────────────────────────────────
-- VERIFICACIÓN
-- ─────────────────────────────────────────────────────────
DO $$
DECLARE
    v_count INTEGER;
    r RECORD;
BEGIN
    -- Verificar que ya no hay números duplicados
    SELECT COUNT(DISTINCT entry_number) INTO v_count FROM journal_entries;
    RAISE NOTICE '✅ Asientos con números únicos: %', v_count;
    
    -- Verificar balances de cuentas
    FOR r IN SELECT name, balance FROM accounts ORDER BY name
    LOOP
        RAISE NOTICE '   💰 %: $%', r.name, r.balance;
    END LOOP;
    
    -- Verificar que no quedan "Clientes (Cobro)"
    SELECT COUNT(*) INTO v_count 
    FROM journal_entry_lines WHERE account_name LIKE 'Clientes (Cobro)%';
    RAISE NOTICE '   Etiquetas "Clientes (Cobro)" restantes: %', v_count;
END $$;
