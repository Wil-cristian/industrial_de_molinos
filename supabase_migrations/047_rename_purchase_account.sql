-- ============================================
-- MIGRACIÓN 047: Renombrar cuenta 601
-- "Costo de Productos Vendidos" → "Compra de Materiales"
-- ============================================

-- 1. Renombrar en chart_of_accounts
UPDATE chart_of_accounts
SET name = 'Compra de Materiales'
WHERE code = '601';

-- 2. Renombrar en todas las líneas de asientos existentes
UPDATE journal_entry_lines
SET account_name = 'Compra de Materiales'
WHERE account_code = '601';

-- 3. Actualizar el trigger de contabilidad automática
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
        CASE NEW.category
            WHEN 'sale' THEN v_credit_code := '701'; v_credit_name := 'Ventas de Productos';
            WHEN 'collection' THEN v_credit_code := '121'; v_credit_name := 'Clientes (Cobro)';
            WHEN 'service' THEN v_credit_code := '702'; v_credit_name := 'Ventas de Servicios';
            WHEN 'pago_prestamo' THEN v_credit_code := '122'; v_credit_name := 'Préstamos a Empleados';
            ELSE v_credit_code := '703'; v_credit_name := 'Otros Ingresos';
        END CASE;
        
        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', NEW.amount, 'credit', 0),
            jsonb_build_object('account_code', v_credit_code, 'account_name', v_credit_name, 'debit', 0, 'credit', NEW.amount)
        );
        
    ELSIF NEW.type = 'expense' THEN
        CASE NEW.category
            WHEN 'purchase' THEN v_credit_code := '601'; v_credit_name := 'Compra de Materiales';
            WHEN 'salary' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'payroll' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'nomina' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
            WHEN 'services' THEN v_credit_code := '631'; v_credit_name := 'Energía Eléctrica';
            WHEN 'rent' THEN v_credit_code := '641'; v_credit_name := 'Alquiler';
            WHEN 'prestamo_empleado' THEN v_credit_code := '122'; v_credit_name := 'Préstamos a Empleados';
            WHEN 'adelanto_sueldo' THEN v_credit_code := '141'; v_credit_name := 'Anticipos a Empleados';
            WHEN 'transfer_out' THEN v_credit_code := NULL;
            ELSE v_credit_code := '642'; v_credit_name := 'Otros Gastos';
        END CASE;
        
        IF v_credit_code IS NULL THEN
            RETURN NEW;
        END IF;
        
        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', v_credit_code, 'account_name', v_credit_name, 'debit', NEW.amount, 'credit', 0),
            jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', 0, 'credit', NEW.amount)
        );

    ELSIF NEW.type = 'transfer' THEN
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
                    jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', NEW.amount, 'credit', 0),
                    jsonb_build_object('account_code', v_from_code, 'account_name', v_from_acct_name, 'debit', 0, 'credit', NEW.amount)
                );
            END;
        ELSE
            RETURN NEW;
        END IF;
    END IF;

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
