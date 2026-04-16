-- =====================================================
-- MIGRACIÓN 041: Corregir contabilización de préstamos
-- 
-- PROBLEMA: Un préstamo a empleado se contabiliza como
-- "642 Otros Gastos" (INCORRECTO). Un préstamo NO es gasto,
-- es un ACTIVO (cuenta por cobrar al empleado).
--
-- CORRECTO:
--   Débito:  122 - Préstamos a Empleados (activo sube)
--   Crédito: 101 - Caja (activo baja)
--
-- También se agrega: nomina → 621 Sueldos y Salarios
-- =====================================================

-- PASO 1: Actualizar el trigger para manejar préstamos y nómina correctamente
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
    
        -- ═══════════════════════════════════════════════
        -- PRÉSTAMO A EMPLEADO: NO es gasto, es ACTIVO
        -- Débito: 122 Préstamos a Empleados (activo sube)
        -- Crédito: Caja/Banco (activo baja)
        -- ═══════════════════════════════════════════════
        IF NEW.category = 'prestamo_empleado' THEN
            v_lines := jsonb_build_array(
                jsonb_build_object('account_code', '122', 'account_name', 'Préstamos a Empleados', 'debit', NEW.amount, 'credit', 0),
                jsonb_build_object('account_code', v_debit_code, 'account_name', v_debit_name, 'debit', 0, 'credit', NEW.amount)
            );
        ELSE
            -- GASTO normal: Débito a cuenta de gasto, Crédito a Caja/Banco
            CASE NEW.category
                WHEN 'purchase' THEN v_credit_code := '601'; v_credit_name := 'Costo de Productos Vendidos';
                WHEN 'salary' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
                WHEN 'payroll' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
                WHEN 'nomina' THEN v_credit_code := '621'; v_credit_name := 'Sueldos y Salarios';
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
        END IF;

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

-- Re-crear el trigger (mismo nombre, se reemplaza)
DROP TRIGGER IF EXISTS trg_auto_journal_cash_movement ON cash_movements;
CREATE TRIGGER trg_auto_journal_cash_movement
    AFTER INSERT ON cash_movements
    FOR EACH ROW
    EXECUTE FUNCTION trg_journal_from_cash_movement();


-- =====================================================
-- PASO 2: Corregir asientos existentes de préstamos
-- que quedaron como "642 Otros Gastos"
-- =====================================================

-- Actualizar líneas de asientos de préstamos existentes
UPDATE journal_entry_lines jel
SET account_code = '122',
    account_name = 'Préstamos a Empleados'
FROM journal_entries je
JOIN cash_movements cm ON je.reference_type = 'cash_movement' AND je.reference_id = cm.id
WHERE jel.entry_id = je.id
  AND cm.category = 'prestamo_empleado'
  AND jel.account_code = '642'
  AND jel.debit > 0;
