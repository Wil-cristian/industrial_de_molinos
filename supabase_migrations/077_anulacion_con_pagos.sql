-- ============================================================
-- 077: Permitir anulación de facturas con pagos
-- Antes: facturas con pagos estaban bloqueadas
-- Ahora: se anulan revirtiendo pagos + registro en auditoría
-- ============================================================

CREATE OR REPLACE FUNCTION secure_cancel_invoice(
    p_invoice_id UUID,
    p_reason TEXT,
    p_force BOOLEAN DEFAULT FALSE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invoice RECORD;
    v_hours_since DECIMAL(8,2);
    v_has_payments BOOLEAN;
    v_payment_total DECIMAL(12,2);
    v_payment_count INT;
    v_has_inventory BOOLEAN;
    v_inventory_count INT;
    v_user_id UUID;
    v_user_email TEXT;
    v_result JSONB;
    v_payments_reverted INT := 0;
BEGIN
    v_user_id := auth.uid();
    v_user_email := COALESCE(
        (SELECT email FROM auth.users WHERE id = v_user_id),
        'sistema'
    );

    -- VALIDACIÓN 1: Factura existe
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Factura no encontrada: %', p_invoice_id;
    END IF;

    -- VALIDACIÓN 2: No está ya anulada
    IF v_invoice.status = 'cancelled' THEN
        RAISE EXCEPTION 'La factura ya está anulada';
    END IF;

    -- VALIDACIÓN 3: Motivo obligatorio
    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RAISE EXCEPTION 'Debe proporcionar un motivo de anulación';
    END IF;

    v_hours_since := EXTRACT(EPOCH FROM (NOW() - v_invoice.created_at)) / 3600.0;

    -- Verificar pagos
    SELECT 
        COUNT(*) > 0,
        COALESCE(SUM(amount), 0),
        COUNT(*)
    INTO v_has_payments, v_payment_total, v_payment_count
    FROM payments 
    WHERE invoice_id = p_invoice_id;

    IF v_invoice.paid_amount > 0 THEN
        v_has_payments := TRUE;
        v_payment_total := GREATEST(v_payment_total, v_invoice.paid_amount);
    END IF;

    -- Verificar inventario
    SELECT 
        COUNT(*) > 0,
        COUNT(*)
    INTO v_has_inventory, v_inventory_count
    FROM material_movements
    WHERE invoice_id = p_invoice_id AND type = 'outgoing';

    -- ═══════════════════════════════════════════════
    -- PROCEDER CON LA ANULACIÓN
    -- ═══════════════════════════════════════════════

    -- PASO 1: Si hay pagos, revertirlos
    IF v_has_payments AND v_payment_total > 0 THEN
        UPDATE payments 
        SET notes = COALESCE(notes, '') || E'\n[ANULADO ' || 
                    TO_CHAR(NOW(), 'DD/MM/YYYY HH24:MI') || 
                    ' por ' || v_user_email || '] Pago revertido por anulación de factura. Motivo: ' || p_reason
        WHERE invoice_id = p_invoice_id;
        
        GET DIAGNOSTICS v_payments_reverted = ROW_COUNT;

        UPDATE cash_movements
        SET voided = TRUE,
            notes = COALESCE(notes, '') || E'\n[ANULADO] Revertido por anulación de factura'
        WHERE invoice_id = p_invoice_id
          AND voided IS NOT TRUE;
    END IF;

    -- PASO 2: Si hay descuento de inventario, revertir
    IF v_has_inventory THEN
        BEGIN
            PERFORM revert_invoice_material_deduction(p_invoice_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Advertencia al revertir inventario: %', SQLERRM;
        END;
    END IF;

    -- PASO 3: Anular la factura
    UPDATE invoices 
    SET status = 'cancelled',
        paid_amount = 0,
        notes = COALESCE(notes, '') || E'\n[ANULADA ' || 
                TO_CHAR(NOW(), 'DD/MM/YYYY HH24:MI') || 
                ' por ' || v_user_email || '] ' || p_reason ||
                CASE WHEN v_has_payments THEN
                    E'\n  → Se revirtieron ' || v_payment_count || ' pago(s) por $' || TO_CHAR(v_payment_total, 'FM999,999,999.00')
                ELSE '' END ||
                CASE WHEN v_has_inventory THEN
                    E'\n  → Se restauró inventario (' || v_inventory_count || ' items)'
                ELSE '' END,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- PASO 4: Registrar en auditoría
    INSERT INTO cancellation_audit_log (
        entity_type, entity_id, entity_number,
        previous_status, action, reason,
        cancelled_by, cancelled_by_email,
        had_payments, payment_total,
        had_inventory_deduction, inventory_items_count,
        invoice_total, hours_since_creation,
        metadata
    ) VALUES (
        'invoice', p_invoice_id,
        COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
        v_invoice.status, 'cancelled', p_reason,
        v_user_id, v_user_email,
        v_has_payments, v_payment_total,
        v_has_inventory, v_inventory_count,
        v_invoice.total, v_hours_since,
        jsonb_build_object(
            'customer_name', v_invoice.customer_name,
            'customer_id', v_invoice.customer_id,
            'issue_date', v_invoice.issue_date,
            'inventory_reverted', v_has_inventory,
            'payments_reverted', v_payments_reverted,
            'payment_total_reverted', v_payment_total
        )
    );

    -- PASO 5: Recalcular balance del cliente
    IF v_invoice.customer_id IS NOT NULL THEN
        BEGIN
            PERFORM recalculate_customer_balance(v_invoice.customer_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'No se pudo recalcular balance cliente: %', SQLERRM;
        END;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'invoice_number', COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
        'previous_status', v_invoice.status,
        'inventory_reverted', v_has_inventory,
        'inventory_items', v_inventory_count,
        'payments_reverted', v_payments_reverted,
        'payment_total_reverted', v_payment_total,
        'cancelled_by', v_user_email,
        'reason', p_reason
    );

END;
$$;
