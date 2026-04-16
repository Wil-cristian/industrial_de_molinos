-- =====================================================
-- TABLA DE TAREAS DE EMPLEADOS
-- Sistema de asignación y seguimiento de tareas
-- =====================================================

-- Tabla de tareas asignadas a empleados
CREATE TABLE IF NOT EXISTS employee_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Información de la tarea
    title VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Fechas
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    completed_date DATE,
    
    -- Prioridad y estado
    priority VARCHAR(20) DEFAULT 'normal', -- 'baja', 'normal', 'alta', 'urgente'
    status VARCHAR(20) DEFAULT 'pendiente', -- 'pendiente', 'en_progreso', 'completada', 'cancelada'
    
    -- Categoría
    category VARCHAR(50), -- 'produccion', 'mantenimiento', 'limpieza', 'inventario', 'otro'
    
    -- Relaciones opcionales
    production_order_id UUID, -- Si está relacionada con una orden de producción
    
    -- Notas y seguimiento
    notes TEXT,
    completion_notes TEXT,
    
    -- Auditoría
    assigned_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_employee_tasks_employee ON employee_tasks(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_date ON employee_tasks(assigned_date);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_status ON employee_tasks(status);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_due_date ON employee_tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_employee_tasks_priority ON employee_tasks(priority);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_employee_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_employee_tasks_updated_at ON employee_tasks;
CREATE TRIGGER trigger_update_employee_tasks_updated_at
    BEFORE UPDATE ON employee_tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_employee_tasks_updated_at();

-- RLS
ALTER TABLE employee_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_all_employee_tasks" ON employee_tasks;
CREATE POLICY "allow_all_employee_tasks" ON employee_tasks FOR ALL USING (true);

-- Grants
GRANT ALL ON employee_tasks TO anon, authenticated;

-- Comentario
COMMENT ON TABLE employee_tasks IS 'Tareas asignadas a empleados con seguimiento de estado';

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================
SELECT 'Tabla employee_tasks creada exitosamente' AS resultado;
