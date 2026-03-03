-- =====================================================
-- MIGRACIÓN 031: Tablas de Time Tracking para Empleados
-- =====================================================
-- Crea las 4 tablas que las entidades Flutter esperan:
--   - employee_time_entries (registro diario check-in/check-out)
--   - employee_time_sheets (hojas semanales/quincenales)
--   - employee_time_adjustments (ajustes manuales de tiempo)
--   - employee_task_time_logs (registro de tiempo por tarea)
-- También crea vista employee_time_summary para resúmenes.
-- =====================================================

-- =====================================================
-- 1. TABLA: employee_time_entries
-- =====================================================
CREATE TABLE IF NOT EXISTS employee_time_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    entry_date DATE NOT NULL,
    scheduled_start VARCHAR(10),        -- HH:mm formato
    scheduled_end VARCHAR(10),          -- HH:mm formato
    scheduled_minutes INTEGER DEFAULT 0,
    check_in TIMESTAMP WITH TIME ZONE,
    check_out TIMESTAMP WITH TIME ZONE,
    break_minutes INTEGER DEFAULT 0,
    worked_minutes INTEGER DEFAULT 0,
    overtime_minutes INTEGER DEFAULT 0,
    deficit_minutes INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'registrado',  -- registrado, aprobado, rechazado
    source VARCHAR(20) DEFAULT 'manual',       -- manual, biometrico, app
    notes TEXT,
    approval_notes TEXT,
    approved_by UUID REFERENCES employees(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Evitar duplicados: un registro por empleado por día
    UNIQUE (employee_id, entry_date)
);

CREATE INDEX IF NOT EXISTS idx_time_entries_employee ON employee_time_entries(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_date ON employee_time_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_time_entries_status ON employee_time_entries(status);

-- Trigger para actualizar minutos trabajados automáticamente
CREATE OR REPLACE FUNCTION calculate_worked_minutes()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.check_in IS NOT NULL AND NEW.check_out IS NOT NULL THEN
        NEW.worked_minutes := GREATEST(0, 
            EXTRACT(EPOCH FROM (NEW.check_out - NEW.check_in))::INTEGER / 60 - COALESCE(NEW.break_minutes, 0)
        );
        NEW.overtime_minutes := GREATEST(0, NEW.worked_minutes - COALESCE(NEW.scheduled_minutes, 480));
        NEW.deficit_minutes := GREATEST(0, COALESCE(NEW.scheduled_minutes, 480) - NEW.worked_minutes);
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calculate_worked_minutes ON employee_time_entries;
CREATE TRIGGER trg_calculate_worked_minutes
    BEFORE INSERT OR UPDATE ON employee_time_entries
    FOR EACH ROW EXECUTE FUNCTION calculate_worked_minutes();

-- =====================================================
-- 2. TABLA: employee_time_sheets
-- =====================================================
CREATE TABLE IF NOT EXISTS employee_time_sheets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    period_id UUID REFERENCES payroll_periods(id),
    week_start DATE NOT NULL,
    week_end DATE NOT NULL,
    scheduled_minutes INTEGER DEFAULT 2660,  -- ~44.33h/semana
    worked_minutes INTEGER DEFAULT 0,
    overtime_minutes INTEGER DEFAULT 0,
    deficit_minutes INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'abierto',  -- abierto, cerrado, aprobado
    notes TEXT,
    locked_by UUID REFERENCES employees(id),
    locked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Un timesheet por empleado por semana
    UNIQUE (employee_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_time_sheets_employee ON employee_time_sheets(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_sheets_period ON employee_time_sheets(period_id);
CREATE INDEX IF NOT EXISTS idx_time_sheets_dates ON employee_time_sheets(week_start, week_end);

-- =====================================================
-- 3. TABLA: employee_time_adjustments
-- =====================================================
CREATE TABLE IF NOT EXISTS employee_time_adjustments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    timesheet_id UUID REFERENCES employee_time_sheets(id) ON DELETE SET NULL,
    entry_id UUID REFERENCES employee_time_entries(id) ON DELETE SET NULL,
    period_id UUID REFERENCES payroll_periods(id),
    adjustment_date DATE NOT NULL,
    minutes INTEGER NOT NULL,             -- Positivo = agregar, negativo = restar
    type VARCHAR(30) NOT NULL,            -- bonus, descuento, correccion, permiso
    reason TEXT,
    status VARCHAR(20) DEFAULT 'pendiente',  -- pendiente, aprobado, rechazado
    notes TEXT,
    approved_by UUID REFERENCES employees(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_time_adjustments_employee ON employee_time_adjustments(employee_id);
CREATE INDEX IF NOT EXISTS idx_time_adjustments_timesheet ON employee_time_adjustments(timesheet_id);
CREATE INDEX IF NOT EXISTS idx_time_adjustments_date ON employee_time_adjustments(adjustment_date);

-- =====================================================
-- 4. TABLA: employee_task_time_logs
-- =====================================================
CREATE TABLE IF NOT EXISTS employee_task_time_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES employee_tasks(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    minutes INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'registrado',  -- registrado, aprobado
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_task_time_logs_task ON employee_task_time_logs(task_id);
CREATE INDEX IF NOT EXISTS idx_task_time_logs_employee ON employee_task_time_logs(employee_id);

-- Trigger para calcular minutos al hacer check-out
CREATE OR REPLACE FUNCTION calculate_task_minutes()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.start_time IS NOT NULL AND NEW.end_time IS NOT NULL THEN
        NEW.minutes := GREATEST(0, EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time))::INTEGER / 60);
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calculate_task_minutes ON employee_task_time_logs;
CREATE TRIGGER trg_calculate_task_minutes
    BEFORE INSERT OR UPDATE ON employee_task_time_logs
    FOR EACH ROW EXECUTE FUNCTION calculate_task_minutes();

-- =====================================================
-- 5. VISTA: employee_time_summary (para EmployeeTimeSummary en Dart)
-- =====================================================
CREATE OR REPLACE VIEW employee_time_summary AS
SELECT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    date_trunc('week', ete.entry_date)::DATE AS week_start,
    (date_trunc('week', ete.entry_date) + INTERVAL '6 days')::DATE AS week_end,
    COUNT(ete.id) AS days_worked,
    COALESCE(SUM(ete.worked_minutes), 0) AS total_worked_minutes,
    COALESCE(SUM(ete.overtime_minutes), 0) AS total_overtime_minutes,
    COALESCE(SUM(ete.deficit_minutes), 0) AS total_deficit_minutes,
    COALESCE(SUM(ete.break_minutes), 0) AS total_break_minutes,
    COALESCE(SUM(ete.scheduled_minutes), 0) AS total_scheduled_minutes,
    COALESCE(
        (SELECT SUM(adj.minutes) FROM employee_time_adjustments adj 
         WHERE adj.employee_id = e.id 
         AND adj.adjustment_date BETWEEN date_trunc('week', ete.entry_date)::DATE 
         AND (date_trunc('week', ete.entry_date) + INTERVAL '6 days')::DATE
         AND adj.status = 'aprobado'), 0
    ) AS adjustment_minutes
FROM employees e
LEFT JOIN employee_time_entries ete ON ete.employee_id = e.id
WHERE ete.entry_date IS NOT NULL
GROUP BY e.id, e.first_name, e.last_name, date_trunc('week', ete.entry_date)
ORDER BY week_start DESC, employee_name;

-- =====================================================
-- 6. FUNCIÓN: Recalcular timesheet desde entries
-- =====================================================
CREATE OR REPLACE FUNCTION recalculate_timesheet(p_timesheet_id UUID)
RETURNS VOID AS $$
DECLARE
    v_ts RECORD;
BEGIN
    SELECT * INTO v_ts FROM employee_time_sheets WHERE id = p_timesheet_id;
    IF v_ts IS NULL THEN RETURN; END IF;
    
    UPDATE employee_time_sheets
    SET 
        worked_minutes = COALESCE((
            SELECT SUM(worked_minutes) FROM employee_time_entries
            WHERE employee_id = v_ts.employee_id
            AND entry_date BETWEEN v_ts.week_start AND v_ts.week_end
        ), 0),
        overtime_minutes = COALESCE((
            SELECT SUM(overtime_minutes) FROM employee_time_entries
            WHERE employee_id = v_ts.employee_id
            AND entry_date BETWEEN v_ts.week_start AND v_ts.week_end
        ), 0),
        deficit_minutes = COALESCE((
            SELECT SUM(deficit_minutes) FROM employee_time_entries
            WHERE employee_id = v_ts.employee_id
            AND entry_date BETWEEN v_ts.week_start AND v_ts.week_end
        ), 0),
        updated_at = NOW()
    WHERE id = p_timesheet_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. RLS POLICIES
-- =====================================================
ALTER TABLE employee_time_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_time_sheets ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_time_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_task_time_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "auth_time_entries" ON employee_time_entries FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_time_sheets" ON employee_time_sheets FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_time_adjustments" ON employee_time_adjustments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_task_time_logs" ON employee_task_time_logs FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- =====================================================
-- 8. PERMISOS
-- =====================================================
GRANT ALL ON employee_time_entries TO authenticated;
GRANT ALL ON employee_time_sheets TO authenticated;
GRANT ALL ON employee_time_adjustments TO authenticated;
GRANT ALL ON employee_task_time_logs TO authenticated;
GRANT EXECUTE ON FUNCTION recalculate_timesheet TO authenticated;

COMMENT ON TABLE employee_time_entries IS 'Registros diarios de entrada/salida de empleados';
COMMENT ON TABLE employee_time_sheets IS 'Hojas de tiempo semanales/quincenales';
COMMENT ON TABLE employee_time_adjustments IS 'Ajustes manuales de tiempo (bonos, correcciones, permisos)';
COMMENT ON TABLE employee_task_time_logs IS 'Registro de tiempo por tarea asignada';
