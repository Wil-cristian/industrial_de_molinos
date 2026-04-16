-- ============================================
-- MIGRACIÓN 093: Corregir timezone en funciones atómicas
-- ============================================
-- PROBLEMA: atomic_transfer y atomic_movement_with_balance reciben p_date como DATE.
-- Cuando Flutter envía '2026-04-14' (solo fecha), Postgres lo convierte a
-- '2026-04-14 00:00:00+00' (UTC midnight). Pero el filtro de Caja Diaria
-- busca desde '2026-04-14T00:00:00-05:00' = '2026-04-14T05:00:00Z'.
-- Resultado: los movimientos creados por RPC quedan con hora 00:00 UTC,
-- que es ANTES de las 05:00 UTC (medianoche Colombia), y NO aparecen en el día correcto.
--
-- SOLUCIÓN: Cambiar p_date a TIMESTAMPTZ para preservar la zona horaria.
-- Flutter ahora envía '2026-04-14T08:00:00.000-05:00' con la hora real de Colombia.
-- ============================================

-- 1. Eliminar las funciones anteriores (con firma DATE)
DROP FUNCTION IF EXISTS atomic_transfer(UUID, UUID, DECIMAL, TEXT, DATE, TEXT);
DROP FUNCTION IF EXISTS atomic_movement_with_balance(UUID, VARCHAR, VARCHAR, DECIMAL, TEXT, TEXT, TEXT, DATE);

-- 2. Recrear atomic_transfer con TIMESTAMPTZ
CREATE OR REPLACE FUNCTION atomic_transfer(
    p_from_account_id UUID,
    p_to_account_id UUID,
    p_amount DECIMAL(12,2),
    p_description TEXT,
    p_date TIMESTAMPTZ DEFAULT NOW(),
    p_reference TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_from_balance DECIMAL(12,2);
    v_to_balance DECIMAL(12,2);
    v_transfer_id TEXT;
    v_out_id UUID;
    v_in_id UUID;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a 0';
    END IF;
    IF p_from_account_id = p_to_account_id THEN
        RAISE EXCEPTION 'No se puede transferir a la misma cuenta';
    END IF;

    SELECT balance INTO v_from_balance 
    FROM accounts WHERE id = LEAST(p_from_account_id, p_to_account_id)
    FOR UPDATE;
    
    SELECT balance INTO v_to_balance 
    FROM accounts WHERE id = GREATEST(p_from_account_id, p_to_account_id)
    FOR UPDATE;

    SELECT balance INTO v_from_balance FROM accounts WHERE id = p_from_account_id;
    SELECT balance INTO v_to_balance FROM accounts WHERE id = p_to_account_id;

    IF v_from_balance < p_amount THEN
        RAISE EXCEPTION 'Saldo insuficiente: disponible %, requerido %', v_from_balance, p_amount;
    END IF;

    v_transfer_id := extract(epoch from now())::TEXT;

    INSERT INTO cash_movements (
        account_id, to_account_id, type, category, amount,
        description, reference, date, linked_transfer_id
    ) VALUES (
        p_from_account_id, p_to_account_id, 'transfer', 'transfer_out', p_amount,
        'Traslado: ' || p_description, p_reference, p_date, v_transfer_id
    ) RETURNING id INTO v_out_id;

    INSERT INTO cash_movements (
        account_id, to_account_id, type, category, amount,
        description, reference, date, linked_transfer_id
    ) VALUES (
        p_to_account_id, p_from_account_id, 'transfer', 'transfer_in', p_amount,
        'Traslado: ' || p_description, p_reference, p_date, v_transfer_id
    ) RETURNING id INTO v_in_id;

    UPDATE accounts SET balance = balance - p_amount, updated_at = NOW()
    WHERE id = p_from_account_id;
    
    UPDATE accounts SET balance = balance + p_amount, updated_at = NOW()
    WHERE id = p_to_account_id;

    RETURN jsonb_build_object(
        'success', true,
        'out_movement_id', v_out_id,
        'in_movement_id', v_in_id,
        'from_new_balance', v_from_balance - p_amount,
        'to_new_balance', v_to_balance + p_amount
    );
END;
$$ LANGUAGE plpgsql;

-- 3. Recrear atomic_movement_with_balance con TIMESTAMPTZ
CREATE OR REPLACE FUNCTION atomic_movement_with_balance(
    p_account_id UUID,
    p_type VARCHAR(20),
    p_category VARCHAR(50),
    p_amount DECIMAL(12,2),
    p_description TEXT,
    p_reference TEXT DEFAULT NULL,
    p_person_name TEXT DEFAULT NULL,
    p_date TIMESTAMPTZ DEFAULT NOW()
) RETURNS JSONB AS $$
DECLARE
    v_balance DECIMAL(12,2);
    v_new_balance DECIMAL(12,2);
    v_movement_id UUID;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a 0';
    END IF;
    IF p_type NOT IN ('income', 'expense') THEN
        RAISE EXCEPTION 'Tipo inválido: %. Use income o expense', p_type;
    END IF;

    SELECT balance INTO v_balance
    FROM accounts WHERE id = p_account_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RAISE EXCEPTION 'Cuenta no encontrada: %', p_account_id;
    END IF;

    IF p_type = 'income' THEN
        v_new_balance := v_balance + p_amount;
    ELSE
        v_new_balance := v_balance - p_amount;
    END IF;

    INSERT INTO cash_movements (
        account_id, type, category, amount,
        description, reference, person_name, date
    ) VALUES (
        p_account_id, p_type, p_category, p_amount,
        p_description, p_reference, p_person_name, p_date
    ) RETURNING id INTO v_movement_id;

    UPDATE accounts SET balance = v_new_balance, updated_at = NOW()
    WHERE id = p_account_id;

    RETURN jsonb_build_object(
        'success', true,
        'movement_id', v_movement_id,
        'previous_balance', v_balance,
        'new_balance', v_new_balance
    );
END;
$$ LANGUAGE plpgsql;

-- 4. Corregir movimientos existentes que tienen hora 00:00:00 UTC
-- Estos fueron creados por las RPCs con tipo DATE, que Postgres convirtió a midnight UTC.
-- Los ajustamos sumando 5 horas para que queden a medianoche Colombia (05:00 UTC).
-- Solo afecta movimientos que están exactamente a medianoche UTC (los creados por RPC con DATE).
UPDATE cash_movements
SET date = (date::date::text || 'T05:00:00+00')::timestamptz
WHERE EXTRACT(HOUR FROM date AT TIME ZONE 'UTC') = 0
  AND EXTRACT(MINUTE FROM date AT TIME ZONE 'UTC') = 0
  AND EXTRACT(SECOND FROM date AT TIME ZONE 'UTC') = 0;

-- 5. Permisos
GRANT EXECUTE ON FUNCTION atomic_transfer(UUID, UUID, DECIMAL, TEXT, TIMESTAMPTZ, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION atomic_movement_with_balance(UUID, VARCHAR, VARCHAR, DECIMAL, TEXT, TEXT, TEXT, TIMESTAMPTZ) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

SELECT '✅ Funciones atómicas actualizadas: p_date cambiado de DATE a TIMESTAMPTZ. Movimientos existentes corregidos.' AS resultado;
