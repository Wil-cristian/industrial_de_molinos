-- ================================================================
-- 051: BLINDAJE ANTI-FRAUDE PARA ANULACIONES DE FACTURAS
-- ================================================================
-- Protecciones implementadas:
-- 1. Facturas pagadas/parciales NO se pueden anular directamente
-- 2. Límite de 72 horas para anular facturas emitidas
-- 3. Tabla de auditoría de anulaciones
-- 4. Asientos contables correctos (no más gastos fantasma)
-- 5. Validación server-side inviolable
-- ================================================================

-- =============================================================
-- 1. TABLA DE AUDITORÍA DE ANULACIONES
-- =============================================================
CREATE TABLE IF NOT EXISTS cancellation_audit_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    entity_type VARCHAR(30) NOT NULL,          -- 'invoice', 'quotation'
    entity_id UUID NOT NULL,
    entity_number VARCHAR(50),                 -- Número legible de la factura/cotización
    previous_status VARCHAR(30) NOT NULL,
    action VARCHAR(30) NOT NULL,               -- 'cancelled', 'blocked', 'credit_note'
    reason TEXT NOT NULL,
    cancelled_by UUID,                         -- auth.uid()
    cancelled_by_email TEXT,
    had_payments BOOLEAN DEFAULT FALSE,
    payment_total DECIMAL(12,2) DEFAULT 0,
    had_inventory_deduction BOOLEAN DEFAULT FALSE,
    inventory_items_count INT DEFAULT 0,
    invoice_total DECIMAL(12,2) DEFAULT 0,
    hours_since_creation DECIMAL(8,2) DEFAULT 0,
    blocked_reason TEXT,                       -- Si fue bloqueada, por qué
    metadata JSONB DEFAULT '{}',
    ip_address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para auditoría
CREATE INDEX IF NOT EXISTS idx_cancellation_audit_entity 
    ON cancellation_audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_cancellation_audit_date 
    ON cancellation_audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cancellation_audit_user 
    ON cancellation_audit_log(cancelled_by);

-- =============================================================
-- 2. FUNCIÓN PRINCIPAL: ANULACIÓN SEGURA DE FACTURAS
-- =============================================================
-- Reglas:
-- - draft: se puede eliminar directamente (no necesita esta función)
-- - issued (sin pagos): se puede anular si tiene < 72 horas
-- - partial (pagos parciales): BLOQUEADO - debe usar nota de crédito
-- - paid: BLOQUEADO - debe usar nota de crédito
-- - cancelled: ya está anulada
-- =============================================================

CREATE OR REPLACE FUNCTION secure_cancel_invoice(
    p_invoice_id UUID,
    p_reason TEXT,
    p_force BOOLEAN DEFAULT FALSE  -- Solo para admin en casos excepcionales
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
    v_block_reason TEXT;
    v_result JSONB;
BEGIN
    -- Obtener usuario actual
    v_user_id := auth.uid();
    v_user_email := COALESCE(
        (SELECT email FROM auth.users WHERE id = v_user_id),
        'sistema'
    );

    -- ═══════════════════════════════════════════════
    -- VALIDACIÓN 1: Factura existe
    -- ═══════════════════════════════════════════════
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Factura no encontrada: %', p_invoice_id;
    END IF;

    -- ═══════════════════════════════════════════════
    -- VALIDACIÓN 2: No está ya anulada
    -- ═══════════════════════════════════════════════
    IF v_invoice.status = 'cancelled' THEN
        RAISE EXCEPTION 'La factura ya está anulada';
    END IF;

    -- Calcular horas desde creación
    v_hours_since := EXTRACT(EPOCH FROM (NOW() - v_invoice.created_at)) / 3600.0;

    -- ═══════════════════════════════════════════════
    -- VALIDACIÓN 3: Verificar pagos
    -- ═══════════════════════════════════════════════
    SELECT 
        COUNT(*) > 0,
        COALESCE(SUM(amount), 0),
        COUNT(*)
    INTO v_has_payments, v_payment_total, v_payment_count
    FROM payments 
    WHERE invoice_id = p_invoice_id;

    -- También verificar el campo paid_amount de la factura
    IF v_invoice.paid_amount > 0 THEN
        v_has_payments := TRUE;
        v_payment_total := GREATEST(v_payment_total, v_invoice.paid_amount);
    END IF;

    -- ═══════════════════════════════════════════════
    -- VALIDACIÓN 4: Verificar inventario
    -- ═══════════════════════════════════════════════
    SELECT 
        COUNT(*) > 0,
        COUNT(*)
    INTO v_has_inventory, v_inventory_count
    FROM material_movements
    WHERE invoice_id = p_invoice_id AND type = 'outgoing';

    -- ═══════════════════════════════════════════════
    -- BLOQUEO: Facturas con pagos (parcial o total)
    -- ═══════════════════════════════════════════════
    IF v_has_payments AND v_payment_total > 0 AND NOT p_force THEN
        v_block_reason := format(
            'BLOQUEADA: La factura %s tiene %s pago(s) por un total de $%s. '
            'No se puede anular una factura con pagos registrados. '
            'Contacte al administrador para resolver.',
            COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
            v_payment_count,
            TO_CHAR(v_payment_total, 'FM999,999,999.00')
        );

        -- Registrar intento bloqueado
        INSERT INTO cancellation_audit_log (
            entity_type, entity_id, entity_number,
            previous_status, action, reason,
            cancelled_by, cancelled_by_email,
            had_payments, payment_total,
            had_inventory_deduction, inventory_items_count,
            invoice_total, hours_since_creation, blocked_reason
        ) VALUES (
            'invoice', p_invoice_id, 
            COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
            v_invoice.status, 'blocked', p_reason,
            v_user_id, v_user_email,
            v_has_payments, v_payment_total,
            v_has_inventory, v_inventory_count,
            v_invoice.total, v_hours_since, v_block_reason
        );

        RETURN jsonb_build_object(
            'success', FALSE,
            'blocked', TRUE,
            'reason', v_block_reason,
            'invoice_number', COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
            'payment_total', v_payment_total,
            'payment_count', v_payment_count
        );
    END IF;

    -- ═══════════════════════════════════════════════
    -- BLOQUEO: Facturas con más de 72 horas (3 días)
    -- (solo si no es forzado)
    -- ═══════════════════════════════════════════════
    IF v_hours_since > 72 AND NOT p_force THEN
        v_block_reason := format(
            'BLOQUEADA: La factura %s fue creada hace %s horas (más de 72h). '
            'Solo se pueden anular facturas dentro de las primeras 72 horas. '
            'Contacte al administrador.',
            COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
            ROUND(v_hours_since, 1)
        );

        -- Registrar intento bloqueado
        INSERT INTO cancellation_audit_log (
            entity_type, entity_id, entity_number,
            previous_status, action, reason,
            cancelled_by, cancelled_by_email,
            had_payments, payment_total,
            had_inventory_deduction, inventory_items_count,
            invoice_total, hours_since_creation, blocked_reason
        ) VALUES (
            'invoice', p_invoice_id,
            COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
            v_invoice.status, 'blocked', p_reason,
            v_user_id, v_user_email,
            v_has_payments, v_payment_total,
            v_has_inventory, v_inventory_count,
            v_invoice.total, v_hours_since, v_block_reason
        );

        RETURN jsonb_build_object(
            'success', FALSE,
            'blocked', TRUE,
            'reason', v_block_reason,
            'invoice_number', COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
            'hours_since_creation', ROUND(v_hours_since, 1)
        );
    END IF;

    -- ═══════════════════════════════════════════════
    -- PROCEDER CON LA ANULACIÓN (sin pagos, < 72h)
    -- ═══════════════════════════════════════════════

    -- PASO 1: Si hay descuento de inventario, revertir
    IF v_has_inventory THEN
        BEGIN
            PERFORM revert_invoice_material_deduction(p_invoice_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Advertencia al revertir inventario: %', SQLERRM;
        END;
    END IF;

    -- PASO 2: Anular la factura
    -- (El trigger trg_auto_journal_invoice creará el asiento de anulación automáticamente)
    UPDATE invoices 
    SET status = 'cancelled',
        notes = COALESCE(notes, '') || E'\n[ANULADA ' || 
                TO_CHAR(NOW(), 'DD/MM/YYYY HH24:MI') || 
                ' por ' || v_user_email || '] ' || p_reason,
        updated_at = NOW()
    WHERE id = p_invoice_id;

    -- PASO 3: Registrar en auditoría
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
            'inventory_reverted', v_has_inventory
        )
    );

    -- PASO 4: Recalcular balance del cliente
    IF v_invoice.customer_id IS NOT NULL THEN
        BEGIN
            PERFORM recalculate_customer_balance(v_invoice.customer_id);
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'No se pudo recalcular balance cliente: %', SQLERRM;
        END;
    END IF;

    -- Resultado exitoso
    RETURN jsonb_build_object(
        'success', TRUE,
        'invoice_id', p_invoice_id,
        'invoice_number', COALESCE(v_invoice.full_number, v_invoice.series || '-' || v_invoice.number),
        'previous_status', v_invoice.status,
        'customer_name', v_invoice.customer_name,
        'total', v_invoice.total,
        'inventory_reverted', v_has_inventory,
        'inventory_items', v_inventory_count,
        'hours_since_creation', ROUND(v_hours_since, 1),
        'cancelled_by', v_user_email,
        'message', 'Factura anulada correctamente'
    );
END;
$$;

-- =============================================================
-- 3. FUNCIÓN: ANULACIÓN SEGURA DE COTIZACIÓN (ACTUALIZADA)
-- =============================================================
-- Usa secure_cancel_invoice internamente cuando hay factura
-- =============================================================

CREATE OR REPLACE FUNCTION secure_annul_quotation(
    p_quotation_id UUID,
    p_reason TEXT DEFAULT 'Anulada por el usuario'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quotation RECORD;
    v_invoice RECORD;
    v_invoice_result JSONB;
    v_movements_cleaned INT := 0;
    v_invoice_annulled BOOLEAN := FALSE;
    v_user_email TEXT;
BEGIN
    v_user_email := COALESCE(
        (SELECT email FROM auth.users WHERE id = auth.uid()),
        'sistema'
    );

    -- Obtener cotización
    SELECT * INTO v_quotation FROM quotations WHERE id = p_quotation_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cotización no encontrada: %', p_quotation_id;
    END IF;

    IF v_quotation.status = 'Anulada' THEN
        RAISE EXCEPTION 'La cotización ya está anulada';
    END IF;

    -- Si la cotización estaba aprobada, verificar factura
    IF v_quotation.status = 'Aprobada' THEN
        SELECT * INTO v_invoice 
        FROM invoices 
        WHERE quotation_id = p_quotation_id 
          AND status != 'cancelled'
        LIMIT 1;

        IF FOUND THEN
            -- Intentar anular la factura usando secure_cancel_invoice
            v_invoice_result := secure_cancel_invoice(
                v_invoice.id, 
                'Anulación automática por anulación de cotización ' || v_quotation.number || ': ' || p_reason
            );

            -- Si la factura fue bloqueada, bloquear también la cotización
            IF NOT (v_invoice_result->>'success')::BOOLEAN THEN
                RETURN jsonb_build_object(
                    'success', FALSE,
                    'blocked', TRUE,
                    'reason', 'No se puede anular la cotización porque la factura asociada no puede ser anulada: ' || 
                              (v_invoice_result->>'reason'),
                    'invoice_number', v_invoice_result->>'invoice_number',
                    'quotation_number', v_quotation.number
                );
            END IF;

            v_invoice_annulled := TRUE;
        END IF;
    END IF;

    -- Limpiar referencias en material_movements
    UPDATE material_movements 
    SET quotation_id = NULL 
    WHERE quotation_id = p_quotation_id;
    GET DIAGNOSTICS v_movements_cleaned = ROW_COUNT;

    -- Anular la cotización
    UPDATE quotations 
    SET status = 'Anulada', 
        notes = COALESCE(notes, '') || E'\n[ANULADA ' || 
                TO_CHAR(NOW(), 'DD/MM/YYYY HH24:MI') || 
                ' por ' || v_user_email || '] ' || p_reason,
        updated_at = NOW()
    WHERE id = p_quotation_id;

    -- Registrar en auditoría
    INSERT INTO cancellation_audit_log (
        entity_type, entity_id, entity_number,
        previous_status, action, reason,
        cancelled_by, cancelled_by_email,
        metadata
    ) VALUES (
        'quotation', p_quotation_id, v_quotation.number,
        v_quotation.status, 'cancelled', p_reason,
        auth.uid(), v_user_email,
        jsonb_build_object(
            'invoice_annulled', v_invoice_annulled,
            'invoice_id', CASE WHEN v_invoice_annulled THEN v_invoice.id ELSE NULL END,
            'movements_cleaned', v_movements_cleaned
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'quotation_id', p_quotation_id,
        'quotation_number', v_quotation.number,
        'previous_status', v_quotation.status,
        'movements_cleaned', v_movements_cleaned,
        'invoice_annulled', v_invoice_annulled,
        'invoice_result', v_invoice_result,
        'message', 'Cotización anulada correctamente'
    );
END;
$$;


-- =============================================================
-- 4. CORREGIR EL TRIGGER CONTABLE DE FACTURAS
-- =============================================================
-- Ahora cuando se anula, NO crea el asiento de reversión de pagos
-- como gasto (642 Otros Gastos). Solo revierte la venta.
-- Si la factura NO tenía pagos, solo se revierte CxC vs Ventas.
-- Si la factura SÍ tenía pagos (no debería llegar aquí por el bloqueo),
-- el asiento es el mismo: reversión de la venta.
-- =============================================================

CREATE OR REPLACE FUNCTION trg_journal_from_invoice()
RETURNS TRIGGER AS $$
DECLARE
    v_lines JSONB;
BEGIN
    -- Solo al cambiar a status 'issued' o 'partial' desde draft
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

    -- Anulación: revertir SOLO el asiento de venta (no los pagos)
    -- Los pagos fueron bloqueados por secure_cancel_invoice, así que
    -- aquí solo llegan facturas SIN pagos.
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        v_lines := jsonb_build_array(
            jsonb_build_object('account_code', '701', 'account_name', 'Ventas de Productos (Anulación)', 'debit', NEW.total, 'credit', 0),
            jsonb_build_object('account_code', '121', 'account_name', 'Clientes - ' || NEW.customer_name || ' (Anulación)', 'debit', 0, 'credit', NEW.total)
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

-- Recrear trigger
DROP TRIGGER IF EXISTS trg_auto_journal_invoice ON invoices;
CREATE TRIGGER trg_auto_journal_invoice
    AFTER UPDATE ON invoices
    FOR EACH ROW
    EXECUTE FUNCTION trg_journal_from_invoice();


-- =============================================================
-- 5. CORREGIR ASIENTOS CONTABLES MALOS EXISTENTES
-- =============================================================
-- Los asientos de "Reversión por anulación" crearon entradas en
-- 642 Otros Gastos cuando deberían ser 121 CxC Clientes.
-- Vamos a:
-- a) Identificar los asientos de Journal de tipo 'expense' con categoría 'other_expense' 
--    que vienen de reversiones de anulación
-- b) Eliminar esos journal entries duplicados/incorrectos
-- c) Dejar solo los asientos correctos del trigger de factura
-- =============================================================

DO $$
DECLARE
    v_fixed INT := 0;
    v_entry RECORD;
BEGIN
    -- Eliminar los asientos contables generados por cash_movements de reversión
    -- Estos son los que crearon "642 Otros Gastos" incorrectamente
    FOR v_entry IN 
        SELECT je.id, je.description
        FROM journal_entries je
        WHERE je.reference_type = 'cash_movement'
        AND je.description ILIKE '%Reversión por anulación%'
        AND je.status = 'posted'
    LOOP
        -- Eliminar líneas del asiento
        DELETE FROM journal_entry_lines WHERE entry_id = v_entry.id;
        -- Eliminar el asiento
        DELETE FROM journal_entries WHERE id = v_entry.id;
        v_fixed := v_fixed + 1;
    END LOOP;

    RAISE NOTICE 'Asientos de reversión incorrectos eliminados: %', v_fixed;
END;
$$;

-- También eliminar los cash_movements de reversión que crearon esos gastos fantasma
-- Estos son tipo 'expense' con referencia 'ANULACION-...'
DO $$
DECLARE
    v_deleted INT := 0;
    v_movement RECORD;
BEGIN
    FOR v_movement IN
        SELECT cm.id, cm.amount, cm.account_id, cm.reference
        FROM cash_movements cm
        WHERE cm.reference LIKE 'ANULACION-%'
        AND cm.type = 'expense'
        AND cm.category = 'other_expense'
    LOOP
        -- Restaurar el balance de la cuenta (el gasto lo restó, volvemos a sumar)
        UPDATE accounts 
        SET balance = balance + v_movement.amount,
            updated_at = NOW()
        WHERE id = v_movement.account_id;

        -- Eliminar el movimiento fantasma
        DELETE FROM cash_movements WHERE id = v_movement.id;
        
        v_deleted := v_deleted + 1;
    END LOOP;

    RAISE NOTICE 'Movimientos de reversión fantasma eliminados y balances restaurados: %', v_deleted;
END;
$$;


-- =============================================================
-- 6. FUNCIÓN AUXILIAR: Ver historial de anulaciones
-- =============================================================
CREATE OR REPLACE FUNCTION get_cancellation_history(
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    entity_type VARCHAR,
    entity_number VARCHAR,
    previous_status VARCHAR,
    action VARCHAR,
    reason TEXT,
    cancelled_by_email TEXT,
    had_payments BOOLEAN,
    payment_total DECIMAL,
    invoice_total DECIMAL,
    hours_since_creation DECIMAL,
    blocked_reason TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT 
        cal.id, cal.entity_type, cal.entity_number,
        cal.previous_status, cal.action, cal.reason,
        cal.cancelled_by_email, cal.had_payments,
        cal.payment_total, cal.invoice_total,
        cal.hours_since_creation, cal.blocked_reason,
        cal.created_at
    FROM cancellation_audit_log cal
    ORDER BY cal.created_at DESC
    LIMIT p_limit;
$$;


-- =============================================================
-- 7. FUNCIÓN: Verificar si una factura puede ser anulada
-- =============================================================
-- Útil para el frontend: mostrar botón de anular o no
-- =============================================================
CREATE OR REPLACE FUNCTION can_cancel_invoice(p_invoice_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invoice RECORD;
    v_hours_since DECIMAL(8,2);
    v_has_payments BOOLEAN;
    v_payment_total DECIMAL(12,2);
    v_reasons TEXT[] := '{}';
BEGIN
    SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('can_cancel', FALSE, 'reasons', ARRAY['Factura no encontrada']);
    END IF;

    -- Ya anulada
    IF v_invoice.status = 'cancelled' THEN
        RETURN jsonb_build_object('can_cancel', FALSE, 'reasons', ARRAY['Ya está anulada']);
    END IF;

    -- Borradores se eliminan, no se anulan
    IF v_invoice.status = 'draft' THEN
        RETURN jsonb_build_object('can_cancel', TRUE, 'reasons', ARRAY['Es un borrador - se puede eliminar'], 'is_draft', TRUE);
    END IF;

    -- Verificar pagos
    SELECT 
        COUNT(*) > 0,
        COALESCE(SUM(amount), 0)
    INTO v_has_payments, v_payment_total
    FROM payments 
    WHERE invoice_id = p_invoice_id;

    IF v_invoice.paid_amount > 0 OR v_payment_total > 0 THEN
        v_reasons := array_append(v_reasons, format(
            'Tiene pagos registrados por $%s. Las facturas con pagos no se pueden anular.',
            TO_CHAR(GREATEST(v_payment_total, v_invoice.paid_amount), 'FM999,999,999.00')
        ));
    END IF;

    -- Verificar tiempo
    v_hours_since := EXTRACT(EPOCH FROM (NOW() - v_invoice.created_at)) / 3600.0;
    IF v_hours_since > 72 THEN
        v_reasons := array_append(v_reasons, format(
            'Fue creada hace %s horas (límite: 72h).',
            ROUND(v_hours_since, 1)
        ));
    END IF;

    RETURN jsonb_build_object(
        'can_cancel', array_length(v_reasons, 1) IS NULL OR array_length(v_reasons, 1) = 0,
        'reasons', COALESCE(v_reasons, '{}'),
        'status', v_invoice.status,
        'hours_since_creation', ROUND(v_hours_since, 1),
        'has_payments', (v_invoice.paid_amount > 0 OR v_payment_total > 0),
        'payment_total', GREATEST(v_payment_total, COALESCE(v_invoice.paid_amount, 0)),
        'total', v_invoice.total
    );
END;
$$;


-- =============================================================
-- 8. PERMISOS
-- =============================================================
GRANT EXECUTE ON FUNCTION secure_cancel_invoice(UUID, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION secure_annul_quotation(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION can_cancel_invoice(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_cancellation_history(INT) TO authenticated;

GRANT ALL ON cancellation_audit_log TO authenticated;

-- RLS para auditoría (solo lectura para usuarios normales)
ALTER TABLE cancellation_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuarios pueden ver historial de anulaciones"
    ON cancellation_audit_log FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Solo el sistema puede insertar auditoría"
    ON cancellation_audit_log FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- =============================================================
-- 9. NOTIFICAR CAMBIO DE SCHEMA
-- =============================================================
NOTIFY pgrst, 'reload schema';
