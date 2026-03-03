-- =====================================================
-- MIGRACIÓN 040: FIX CONTABILIDAD AUTOMÁTICA
-- =====================================================
-- PROBLEMA: El trigger trg_journal_from_payment creaba asientos
-- que REVERTÍAN el ingreso y duplicaban la reducción de CxC.
--
-- Flujo correcto (ya cubierto por triggers existentes):
-- 1. Factura emitida → Debit 121 (CxC) / Credit 701 (Ventas) [trigger invoice]
-- 2. Cobro/Abono     → Debit Caja / Credit 121 (CxC)         [trigger cash_movement]
--
-- El trigger de payment era redundante y generaba:
--   Debit 701 / Credit 121 (reducía ventas y duplicaba CxC)
-- =====================================================

-- ─────────────────────────────────────────────────────────
-- PASO 1: Eliminar trigger de pagos (causa del error)
-- ─────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_auto_journal_payment ON payments;
DROP FUNCTION IF EXISTS trg_journal_from_payment() CASCADE;

-- ─────────────────────────────────────────────────────────
-- PASO 2: Limpiar asientos contables erróneos generados
-- por el trigger de pagos (reference_type = 'payment')
-- Estos ya están cubiertos por los cash_movement entries
-- ─────────────────────────────────────────────────────────
DELETE FROM journal_entry_lines 
WHERE entry_id IN (
    SELECT id FROM journal_entries WHERE reference_type = 'payment'
);

DELETE FROM journal_entries 
WHERE reference_type = 'payment';

-- ─────────────────────────────────────────────────────────
-- PASO 3: Mejorar trigger de invoice para distinguir
-- contado vs crédito en la descripción
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION trg_journal_from_invoice()
RETURNS TRIGGER AS $$
DECLARE
    v_lines JSONB;
    v_description TEXT;
BEGIN
    -- Solo al cambiar a status 'issued' o 'partial' desde 'draft'
    IF NEW.status IN ('issued', 'partial') AND 
       (OLD.status IS NULL OR OLD.status = 'draft') THEN
        
        -- Asiento universal: CxC Clientes (Débito) ↔ Ventas (Crédito)
        -- Para contado: el cash_movement posterior cancela la CxC de inmediato
        -- Para crédito: la CxC queda pendiente hasta que se registren abonos
        v_lines := jsonb_build_array(
            jsonb_build_object(
                'account_code', '121', 
                'account_name', 'Clientes - ' || NEW.customer_name, 
                'debit', NEW.total, 
                'credit', 0
            ),
            jsonb_build_object(
                'account_code', '701', 
                'account_name', 'Ventas de Productos', 
                'debit', 0, 
                'credit', NEW.total
            )
        );

        v_description := 'Factura emitida ' || 
            COALESCE(NEW.full_number, NEW.series || '-' || NEW.number) || 
            ' - ' || COALESCE(NEW.customer_name, 'S/N');

        PERFORM create_journal_entry(
            NEW.issue_date,
            v_description,
            'invoice',
            NEW.id,
            v_lines
        );
    END IF;

    -- Anulación: revertir el asiento de venta
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        v_lines := jsonb_build_array(
            jsonb_build_object(
                'account_code', '701', 
                'account_name', 'Ventas de Productos (Anulación)', 
                'debit', NEW.total, 
                'credit', 0
            ),
            jsonb_build_object(
                'account_code', '121', 
                'account_name', 'Clientes - ' || NEW.customer_name, 
                'debit', 0, 
                'credit', NEW.total
            )
        );

        PERFORM create_journal_entry(
            CURRENT_DATE,
            'Anulación factura ' || 
                COALESCE(NEW.full_number, NEW.series || '-' || NEW.number) || 
                ' - ' || COALESCE(NEW.customer_name, 'S/N'),
            'invoice_cancel',
            NEW.id,
            v_lines
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────
-- VERIFICACIÓN
-- ─────────────────────────────────────────────────────────
DO $$
DECLARE
    v_remaining INT;
BEGIN
    SELECT COUNT(*) INTO v_remaining 
    FROM journal_entries WHERE reference_type = 'payment';
    
    RAISE NOTICE '✅ Migración 040: Contabilidad corregida';
    RAISE NOTICE '   • Trigger trg_journal_from_payment ELIMINADO';
    RAISE NOTICE '   • Asientos erróneos tipo "payment" restantes: %', v_remaining;
    RAISE NOTICE '   • Flujo correcto:';
    RAISE NOTICE '     Factura → Debit 121 (CxC) / Credit 701 (Ventas)';
    RAISE NOTICE '     Cobro   → Debit Caja / Credit 121 (CxC)';
    RAISE NOTICE '     Abono   → Debit Caja / Credit 121 (CxC)';
END $$;
