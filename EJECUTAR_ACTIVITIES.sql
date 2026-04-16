-- =====================================================
-- CREAR TABLA DE ACTIVIDADES
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- Tabla principal de actividades
CREATE TABLE IF NOT EXISTS activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Tipo de actividad
    activity_type VARCHAR(50) NOT NULL DEFAULT 'general',
    
    -- Fechas
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    due_date DATE,
    
    -- Estado
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    
    -- Prioridad
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    
    -- Relaciones opcionales
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    quotation_id UUID REFERENCES quotations(id) ON DELETE SET NULL,
    
    -- Recordatorios
    reminder_enabled BOOLEAN DEFAULT false,
    reminder_date TIMESTAMP WITH TIME ZONE,
    reminder_sent BOOLEAN DEFAULT false,
    
    -- Monto asociado
    amount DECIMAL(12,2),
    
    -- Metadata
    color VARCHAR(20) DEFAULT '#2196F3',
    icon VARCHAR(50),
    notes TEXT,
    
    -- Auditoría
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    
    -- Constraints
    CONSTRAINT valid_activity_type CHECK (
        activity_type IN ('payment', 'delivery', 'project_start', 'project_end', 'collection', 'meeting', 'reminder', 'general', 'stock_alert', 'maintenance')
    ),
    CONSTRAINT valid_status CHECK (
        status IN ('pending', 'in_progress', 'completed', 'cancelled', 'overdue')
    ),
    CONSTRAINT valid_priority CHECK (
        priority IN ('low', 'medium', 'high', 'urgent')
    )
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_activities_start_date ON activities(start_date);
CREATE INDEX IF NOT EXISTS idx_activities_due_date ON activities(due_date);
CREATE INDEX IF NOT EXISTS idx_activities_status ON activities(status);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_customer ON activities(customer_id);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_activities_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_activities_updated_at ON activities;
CREATE TRIGGER trigger_update_activities_updated_at
    BEFORE UPDATE ON activities
    FOR EACH ROW
    EXECUTE FUNCTION update_activities_updated_at();

-- Habilitar RLS
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- Política para permitir todo (ajustar según necesidad)
DROP POLICY IF EXISTS "Allow all operations on activities" ON activities;
CREATE POLICY "Allow all operations on activities" ON activities
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Verificar creación
SELECT 'Tabla activities creada correctamente' as resultado;
