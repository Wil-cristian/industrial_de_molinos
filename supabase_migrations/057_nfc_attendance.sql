-- =====================================================
-- MIGRACIÓN 057: NFC Attendance System
-- =====================================================
-- Agrega soporte de tarjetas NFC para control de asistencia:
--   1. Campo nfc_card_id en employees
--   2. Tabla nfc_attendance_log para historial de escaneos
--   3. Función RPC para registrar entrada/salida por NFC
--   4. Actualiza CHECK en source para incluir 'nfc'
-- =====================================================

-- 1. Agregar campo NFC a empleados
ALTER TABLE employees ADD COLUMN IF NOT EXISTS nfc_card_id VARCHAR(100) UNIQUE;

CREATE INDEX IF NOT EXISTS idx_employees_nfc_card ON employees(nfc_card_id) WHERE nfc_card_id IS NOT NULL;

-- 2. Tabla de log de escaneos NFC (auditoría)
CREATE TABLE IF NOT EXISTS nfc_attendance_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    nfc_card_id VARCHAR(100) NOT NULL,
    scan_type VARCHAR(10) NOT NULL CHECK (scan_type IN ('entrada', 'salida')),
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    device_name VARCHAR(100),
    time_entry_id UUID REFERENCES employee_time_entries(id),
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_nfc_log_employee ON nfc_attendance_log(employee_id);
CREATE INDEX IF NOT EXISTS idx_nfc_log_card ON nfc_attendance_log(nfc_card_id);
CREATE INDEX IF NOT EXISTS idx_nfc_log_date ON nfc_attendance_log(scanned_at);

-- 3. Función RPC: registrar entrada/salida por NFC
-- Lógica:
--   - Busca empleado por nfc_card_id O por employee_id directo
--   - Si no tiene entrada hoy → crea check-in
--   - Si tiene entrada sin salida → registra check-out
--   - Si ya tiene entrada y salida → error (ya completó jornada)
CREATE OR REPLACE FUNCTION register_nfc_attendance(
    p_nfc_card_id VARCHAR DEFAULT NULL,
    p_device_name VARCHAR DEFAULT NULL,
    p_employee_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_employee RECORD;
    v_today DATE := CURRENT_DATE;
    v_now TIMESTAMP WITH TIME ZONE := NOW();
    v_time_entry RECORD;
    v_new_entry RECORD;
    v_scan_type VARCHAR(10);
    v_result JSONB;
    v_card_id VARCHAR;
BEGIN
    -- Buscar empleado por ID directo o por NFC card
    IF p_employee_id IS NOT NULL THEN
        SELECT id, first_name, last_name, is_active, nfc_card_id
        INTO v_employee
        FROM employees
        WHERE id = p_employee_id;
        v_card_id := COALESCE(v_employee.nfc_card_id, p_employee_id::VARCHAR);
    ELSIF p_nfc_card_id IS NOT NULL THEN
        SELECT id, first_name, last_name, is_active, nfc_card_id
        INTO v_employee
        FROM employees
        WHERE nfc_card_id = p_nfc_card_id;
        v_card_id := p_nfc_card_id;
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'NO_IDENTIFIER',
            'message', 'Debe proporcionar nfc_card_id o employee_id'
        );
    END IF;

    IF NOT FOUND THEN
        -- Log intento fallido
        INSERT INTO nfc_attendance_log (nfc_card_id, scan_type, device_name, success, error_message)
        VALUES (COALESCE(v_card_id, 'unknown'), 'entrada', p_device_name, false, 'Empleado no encontrado');
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'EMPLOYEE_NOT_FOUND',
            'message', 'Empleado no encontrado en el sistema'
        );
    END IF;

    -- Verificar empleado activo
    IF v_employee.is_active = false THEN
        INSERT INTO nfc_attendance_log (employee_id, nfc_card_id, scan_type, device_name, success, error_message)
        VALUES (v_employee.id, v_card_id, 'entrada', p_device_name, false, 'Empleado inactivo');
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'EMPLOYEE_INACTIVE',
            'message', 'Empleado inactivo: ' || v_employee.first_name || ' ' || v_employee.last_name
        );
    END IF;

    -- Buscar entrada de hoy
    SELECT * INTO v_time_entry
    FROM employee_time_entries
    WHERE employee_id = v_employee.id AND entry_date = v_today;

    IF NOT FOUND THEN
        -- CASO 1: No hay entrada hoy → crear check-in
        v_scan_type := 'entrada';
        
        INSERT INTO employee_time_entries (employee_id, entry_date, check_in, status, source)
        VALUES (v_employee.id, v_today, v_now, 'registrado', 'nfc')
        RETURNING * INTO v_new_entry;

        -- Log exitoso
        INSERT INTO nfc_attendance_log (employee_id, nfc_card_id, scan_type, device_name, time_entry_id, success)
        VALUES (v_employee.id, v_card_id, v_scan_type, p_device_name, v_new_entry.id, true);

        v_result := jsonb_build_object(
            'success', true,
            'action', 'CHECK_IN',
            'message', '¡Entrada registrada!',
            'employee_id', v_employee.id,
            'employee_name', v_employee.first_name || ' ' || v_employee.last_name,
            'check_in', v_now,
            'time_entry_id', v_new_entry.id
        );

    ELSIF v_time_entry.check_out IS NULL THEN
        -- CASO 2: Tiene entrada sin salida → registrar check-out
        v_scan_type := 'salida';
        
        UPDATE employee_time_entries
        SET check_out = v_now, source = 'nfc'
        WHERE id = v_time_entry.id
        RETURNING * INTO v_new_entry;

        -- Log exitoso
        INSERT INTO nfc_attendance_log (employee_id, nfc_card_id, scan_type, device_name, time_entry_id, success)
        VALUES (v_employee.id, v_card_id, v_scan_type, p_device_name, v_new_entry.id, true);

        v_result := jsonb_build_object(
            'success', true,
            'action', 'CHECK_OUT',
            'message', '¡Salida registrada!',
            'employee_id', v_employee.id,
            'employee_name', v_employee.first_name || ' ' || v_employee.last_name,
            'check_in', v_time_entry.check_in,
            'check_out', v_now,
            'worked_minutes', v_new_entry.worked_minutes,
            'time_entry_id', v_new_entry.id
        );

    ELSE
        -- CASO 3: Ya tiene entrada y salida → jornada completada
        INSERT INTO nfc_attendance_log (employee_id, nfc_card_id, scan_type, device_name, success, error_message)
        VALUES (v_employee.id, v_card_id, 'entrada', p_device_name, false, 'Jornada ya registrada');

        v_result := jsonb_build_object(
            'success', false,
            'error', 'ALREADY_COMPLETED',
            'message', 'Jornada ya registrada para hoy',
            'employee_name', v_employee.first_name || ' ' || v_employee.last_name,
            'check_in', v_time_entry.check_in,
            'check_out', v_time_entry.check_out
        );
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RLS para nfc_attendance_log
ALTER TABLE nfc_attendance_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all for authenticated" ON nfc_attendance_log
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 5. Función auxiliar: buscar empleado por NFC
CREATE OR REPLACE FUNCTION get_employee_by_nfc(p_nfc_card_id VARCHAR)
RETURNS JSONB AS $$
DECLARE
    v_employee RECORD;
BEGIN
    SELECT id, first_name, last_name, position, department, is_active
    INTO v_employee
    FROM employees
    WHERE nfc_card_id = p_nfc_card_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('found', false);
    END IF;

    RETURN jsonb_build_object(
        'found', true,
        'id', v_employee.id,
        'first_name', v_employee.first_name,
        'last_name', v_employee.last_name,
        'position', v_employee.position,
        'department', v_employee.department,
        'is_active', v_employee.is_active
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
