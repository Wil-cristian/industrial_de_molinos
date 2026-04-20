-- =====================================================
-- MIGRACION 058: NFC multi-entradas y minutos trabajados
-- =====================================================
-- Objetivos:
-- 1) Permitir multiples entradas/salidas por empleado en el mismo dia.
-- 2) Ajustar RPC NFC para alternar entre abrir y cerrar sesiones del dia.
-- 3) Corregir worked_minutes para evitar redondeo a 0 por segundos.
-- =====================================================

-- 1) Quitar restriccion de un solo registro por empleado/dia
DO $$
DECLARE
  v_constraint_name text;
BEGIN
  SELECT conname
  INTO v_constraint_name
  FROM pg_constraint
  WHERE conrelid = 'employee_time_entries'::regclass
    AND contype = 'u'
    AND conname IN (
      'employee_time_entries_employee_id_entry_date_key',
      'employee_time_entries_employee_id_entry_date_unique'
    )
  LIMIT 1;

  IF v_constraint_name IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE employee_time_entries DROP CONSTRAINT %I',
      v_constraint_name
    );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_time_entries_employee_date
  ON employee_time_entries(employee_id, entry_date);

-- 2) Recalculo robusto de minutos
CREATE OR REPLACE FUNCTION calculate_worked_minutes()
RETURNS TRIGGER AS $$
DECLARE
  v_raw_minutes INTEGER;
BEGIN
  IF NEW.check_in IS NOT NULL AND NEW.check_out IS NOT NULL THEN
    IF NEW.check_out > NEW.check_in THEN
      -- Redondeo hacia arriba: 1..60s => 1 minuto.
      v_raw_minutes := CEIL(EXTRACT(EPOCH FROM (NEW.check_out - NEW.check_in)) / 60.0)::INTEGER;
      NEW.worked_minutes := GREATEST(0, v_raw_minutes - COALESCE(NEW.break_minutes, 0));
    ELSE
      NEW.worked_minutes := 0;
    END IF;

    NEW.overtime_minutes := GREATEST(0, NEW.worked_minutes - COALESCE(NEW.scheduled_minutes, 480));
    NEW.deficit_minutes := GREATEST(0, COALESCE(NEW.scheduled_minutes, 480) - NEW.worked_minutes);
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3) RPC NFC con multiples ciclos entrada/salida por dia
CREATE OR REPLACE FUNCTION register_nfc_attendance(
  p_nfc_card_id VARCHAR DEFAULT NULL,
  p_device_name VARCHAR DEFAULT NULL,
  p_employee_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_employee RECORD;
  v_today DATE := (NOW() AT TIME ZONE 'America/Bogota')::DATE;
  v_now TIMESTAMP WITH TIME ZONE := NOW();
  v_open_entry RECORD;
  v_new_entry RECORD;
  v_scan_type VARCHAR(10);
  v_result JSONB;
  -- Calcular scheduled_minutes segun dia de la semana
  -- EXTRACT(DOW FROM date): 0=domingo, 1=lunes..5=viernes, 6=sabado
  v_day_of_week INTEGER;
  v_scheduled INTEGER;
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
    INSERT INTO nfc_attendance_log (nfc_card_id, scan_type, device_name, success, error_message)
    VALUES (COALESCE(v_card_id, 'unknown'), 'entrada', p_device_name, false, 'Empleado no encontrado');

    RETURN jsonb_build_object(
      'success', false,
      'error', 'EMPLOYEE_NOT_FOUND',
      'message', 'Empleado no encontrado en el sistema'
    );
  END IF;

  IF v_employee.is_active = false THEN
    INSERT INTO nfc_attendance_log (employee_id, nfc_card_id, scan_type, device_name, success, error_message)
    VALUES (v_employee.id, v_card_id, 'entrada', p_device_name, false, 'Empleado inactivo');

    RETURN jsonb_build_object(
      'success', false,
      'error', 'EMPLOYEE_INACTIVE',
      'message', 'Empleado inactivo: ' || v_employee.first_name || ' ' || v_employee.last_name
    );
  END IF;

  -- Calcular scheduled_minutes segun dia de la semana
  v_day_of_week := EXTRACT(DOW FROM v_today)::INTEGER;
  IF v_day_of_week = 6 THEN
    v_scheduled := 330;  -- Sabado: 5.5 horas
  ELSIF v_day_of_week = 0 THEN
    v_scheduled := 0;    -- Domingo: no laboral
  ELSE
    v_scheduled := 480;  -- Lunes a Viernes: 8 horas
  END IF;

  -- Buscar la ultima sesion abierta del dia (sin check_out)
  SELECT * INTO v_open_entry
  FROM employee_time_entries
  WHERE employee_id = v_employee.id
    AND entry_date = v_today
    AND check_in IS NOT NULL
    AND check_out IS NULL
  ORDER BY check_in DESC
  LIMIT 1;

  IF FOUND THEN
    -- Cerrar sesion abierta => CHECK_OUT
    v_scan_type := 'salida';

    UPDATE employee_time_entries
    SET check_out = v_now,
        source = 'nfc'
    WHERE id = v_open_entry.id
    RETURNING * INTO v_new_entry;

    INSERT INTO nfc_attendance_log (employee_id, nfc_card_id, scan_type, device_name, time_entry_id, success)
    VALUES (v_employee.id, v_card_id, v_scan_type, p_device_name, v_new_entry.id, true);

    v_result := jsonb_build_object(
      'success', true,
      'action', 'CHECK_OUT',
      'message', 'Salida registrada',
      'employee_id', v_employee.id,
      'employee_name', v_employee.first_name || ' ' || v_employee.last_name,
      'check_in', v_new_entry.check_in,
      'check_out', v_new_entry.check_out,
      'worked_minutes', v_new_entry.worked_minutes,
      'time_entry_id', v_new_entry.id
    );
  ELSE
    -- No hay sesion abierta => crear nueva entrada => CHECK_IN
    v_scan_type := 'entrada';

    INSERT INTO employee_time_entries (employee_id, entry_date, check_in, scheduled_minutes, status, source)
    VALUES (v_employee.id, v_today, v_now, v_scheduled, 'registrado', 'nfc')
    RETURNING * INTO v_new_entry;

    INSERT INTO nfc_attendance_log (employee_id, nfc_card_id, scan_type, device_name, time_entry_id, success)
    VALUES (v_employee.id, v_card_id, v_scan_type, p_device_name, v_new_entry.id, true);

    v_result := jsonb_build_object(
      'success', true,
      'action', 'CHECK_IN',
      'message', 'Entrada registrada',
      'employee_id', v_employee.id,
      'employee_name', v_employee.first_name || ' ' || v_employee.last_name,
      'check_in', v_new_entry.check_in,
      'time_entry_id', v_new_entry.id
    );
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
