-- =====================================================
-- AGREGAR COLUMNAS FALTANTES A EMPLOYEE_TASKS
-- estimated_time, actual_time, activity_id
-- =====================================================

-- Agregar columna estimated_time (tiempo estimado en minutos)
ALTER TABLE employee_tasks 
ADD COLUMN IF NOT EXISTS estimated_time INTEGER;

-- Agregar columna actual_time (tiempo real en minutos)
ALTER TABLE employee_tasks 
ADD COLUMN IF NOT EXISTS actual_time INTEGER;

-- Agregar columna activity_id (relación con actividades)
ALTER TABLE employee_tasks 
ADD COLUMN IF NOT EXISTS activity_id UUID REFERENCES activities(id) ON DELETE SET NULL;

-- Comentarios descriptivos
COMMENT ON COLUMN employee_tasks.estimated_time IS 'Tiempo estimado para completar la tarea en minutos';
COMMENT ON COLUMN employee_tasks.actual_time IS 'Tiempo real que tomó completar la tarea en minutos';
COMMENT ON COLUMN employee_tasks.activity_id IS 'ID de la actividad relacionada (opcional)';

-- Crear índice para activity_id
CREATE INDEX IF NOT EXISTS idx_employee_tasks_activity ON employee_tasks(activity_id);
