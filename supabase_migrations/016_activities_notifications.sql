-- =====================================================
-- TABLA DE ACTIVIDADES/ORGANIZADOR
-- Industrial de Molinos
-- Fecha: 24 de Diciembre, 2025
-- =====================================================

-- Tabla principal de actividades
CREATE TABLE IF NOT EXISTS activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Tipo de actividad
    activity_type VARCHAR(50) NOT NULL DEFAULT 'general',
    -- Tipos: payment, delivery, project_start, project_end, collection, meeting, reminder, general
    
    -- Fechas
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    due_date DATE, -- Fecha límite si aplica
    
    -- Estado
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    -- Estados: pending, in_progress, completed, cancelled, overdue
    
    -- Prioridad
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    -- Prioridades: low, medium, high, urgent
    
    -- Relaciones opcionales
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    quotation_id UUID REFERENCES quotations(id) ON DELETE SET NULL,
    
    -- Recordatorios
    reminder_enabled BOOLEAN DEFAULT false,
    reminder_date TIMESTAMP WITH TIME ZONE,
    reminder_sent BOOLEAN DEFAULT false,
    
    -- Monto asociado (para pagos, cobros)
    amount DECIMAL(12,2),
    
    -- Metadata
    color VARCHAR(20) DEFAULT '#2196F3', -- Color para mostrar en calendario
    icon VARCHAR(50), -- Icono opcional
    notes TEXT,
    
    -- Auditoría
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    
    -- Índices para búsqueda rápida
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

-- Índices para mejorar rendimiento
CREATE INDEX IF NOT EXISTS idx_activities_start_date ON activities(start_date);
CREATE INDEX IF NOT EXISTS idx_activities_due_date ON activities(due_date);
CREATE INDEX IF NOT EXISTS idx_activities_status ON activities(status);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_customer ON activities(customer_id);
CREATE INDEX IF NOT EXISTS idx_activities_reminder ON activities(reminder_enabled, reminder_date) WHERE reminder_enabled = true;

-- Trigger para actualizar updated_at
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

-- Trigger para marcar actividades vencidas
CREATE OR REPLACE FUNCTION check_overdue_activities()
RETURNS void AS $$
BEGIN
    UPDATE activities
    SET status = 'overdue'
    WHERE status = 'pending'
    AND due_date < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- TABLA DE NOTIFICACIONES
-- =====================================================

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tipo de notificación
    notification_type VARCHAR(50) NOT NULL,
    -- Tipos: low_stock, overdue_invoice, upcoming_delivery, activity_reminder, payment_due, general
    
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    
    -- Estado
    is_read BOOLEAN DEFAULT false,
    is_dismissed BOOLEAN DEFAULT false,
    
    -- Prioridad/Severidad
    severity VARCHAR(20) NOT NULL DEFAULT 'info',
    -- info, warning, error, success
    
    -- Relaciones
    activity_id UUID REFERENCES activities(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    material_id UUID REFERENCES materials(id) ON DELETE SET NULL,
    
    -- Metadata
    action_url VARCHAR(255), -- URL para navegar al hacer click
    icon VARCHAR(50),
    data JSONB, -- Datos adicionales
    
    -- Fechas
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT valid_notification_type CHECK (
        notification_type IN ('low_stock', 'overdue_invoice', 'upcoming_delivery', 'activity_reminder', 'payment_due', 'collection_due', 'general', 'project_update')
    ),
    CONSTRAINT valid_severity CHECK (
        severity IN ('info', 'warning', 'error', 'success')
    )
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(notification_type);

-- =====================================================
-- VISTAS ÚTILES
-- =====================================================

-- Vista: Actividades de hoy
CREATE OR REPLACE VIEW v_today_activities AS
SELECT 
    a.*,
    c.name as customer_name
FROM activities a
LEFT JOIN customers c ON a.customer_id = c.id
WHERE DATE(a.start_date) = CURRENT_DATE
   OR DATE(a.due_date) = CURRENT_DATE
ORDER BY a.start_date;

-- Vista: Actividades de la semana
CREATE OR REPLACE VIEW v_week_activities AS
SELECT 
    a.*,
    c.name as customer_name
FROM activities a
LEFT JOIN customers c ON a.customer_id = c.id
WHERE a.start_date >= DATE_TRUNC('week', CURRENT_DATE)
  AND a.start_date < DATE_TRUNC('week', CURRENT_DATE) + INTERVAL '7 days'
ORDER BY a.start_date;

-- Vista: Próximos recordatorios
CREATE OR REPLACE VIEW v_upcoming_reminders AS
SELECT 
    a.*,
    c.name as customer_name
FROM activities a
LEFT JOIN customers c ON a.customer_id = c.id
WHERE a.reminder_enabled = true
  AND a.reminder_date <= NOW() + INTERVAL '1 day'
  AND a.reminder_sent = false
  AND a.status NOT IN ('completed', 'cancelled')
ORDER BY a.reminder_date;

-- Vista: Notificaciones no leídas
CREATE OR REPLACE VIEW v_unread_notifications AS
SELECT 
    n.*,
    c.name as customer_name,
    m.name as material_name
FROM notifications n
LEFT JOIN customers c ON n.customer_id = c.id
LEFT JOIN materials m ON n.material_id = m.id
WHERE n.is_read = false
  AND n.is_dismissed = false
  AND (n.expires_at IS NULL OR n.expires_at > NOW())
ORDER BY 
    CASE n.severity 
        WHEN 'error' THEN 1 
        WHEN 'warning' THEN 2 
        WHEN 'success' THEN 3 
        ELSE 4 
    END,
    n.created_at DESC;

-- Vista: Resumen de actividades pendientes
CREATE OR REPLACE VIEW v_activities_summary AS
SELECT 
    COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE status = 'overdue') as overdue_count,
    COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_count,
    COUNT(*) FILTER (WHERE DATE(due_date) = CURRENT_DATE) as due_today_count,
    COUNT(*) FILTER (WHERE activity_type = 'payment') as payments_count,
    COUNT(*) FILTER (WHERE activity_type = 'delivery') as deliveries_count,
    COUNT(*) FILTER (WHERE activity_type = 'collection') as collections_count
FROM activities
WHERE status NOT IN ('completed', 'cancelled');

-- =====================================================
-- FUNCIÓN: Generar notificaciones automáticas
-- =====================================================

CREATE OR REPLACE FUNCTION generate_stock_notifications()
RETURNS void AS $$
BEGIN
    -- Insertar notificaciones para materiales con stock bajo
    INSERT INTO notifications (notification_type, title, message, severity, material_id, action_url, icon)
    SELECT 
        'low_stock',
        'Stock Bajo: ' || m.name,
        'El material "' || m.name || '" tiene stock bajo. Actual: ' || m.stock || ' ' || m.unit || ', Mínimo: ' || m.min_stock || ' ' || m.unit,
        CASE WHEN m.stock = 0 THEN 'error' ELSE 'warning' END,
        m.id,
        '/materials',
        'inventory_2'
    FROM materials m
    WHERE m.is_active = true
      AND m.stock <= m.min_stock
      AND NOT EXISTS (
          SELECT 1 FROM notifications n 
          WHERE n.material_id = m.id 
            AND n.notification_type = 'low_stock'
            AND n.created_at > NOW() - INTERVAL '24 hours'
            AND n.is_dismissed = false
      );
END;
$$ LANGUAGE plpgsql;

-- Función: Generar notificaciones de facturas vencidas
CREATE OR REPLACE FUNCTION generate_overdue_invoice_notifications()
RETURNS void AS $$
BEGIN
    INSERT INTO notifications (notification_type, title, message, severity, invoice_id, customer_id, action_url, icon, data)
    SELECT 
        'overdue_invoice',
        'Factura Vencida: ' || i.full_number,
        'La factura ' || i.full_number || ' de ' || c.name || ' está vencida. Monto pendiente: S/ ' || ROUND((i.total - i.paid_amount)::NUMERIC, 2),
        CASE 
            WHEN CURRENT_DATE - i.due_date > 30 THEN 'error'
            ELSE 'warning'
        END,
        i.id,
        i.customer_id,
        '/invoices',
        'receipt_long',
        jsonb_build_object('days_overdue', CURRENT_DATE - i.due_date, 'pending_amount', i.total - i.paid_amount)
    FROM invoices i
    JOIN customers c ON i.customer_id = c.id
    WHERE i.status NOT IN ('paid', 'cancelled')
      AND i.due_date < CURRENT_DATE
      AND (i.total - i.paid_amount) > 0
      AND NOT EXISTS (
          SELECT 1 FROM notifications n 
          WHERE n.invoice_id = i.id 
            AND n.notification_type = 'overdue_invoice'
            AND n.created_at > NOW() - INTERVAL '24 hours'
            AND n.is_dismissed = false
      );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- PERMISOS
-- =====================================================

GRANT ALL ON activities TO anon, authenticated;
GRANT ALL ON notifications TO anon, authenticated;
GRANT SELECT ON v_today_activities TO anon, authenticated;
GRANT SELECT ON v_week_activities TO anon, authenticated;
GRANT SELECT ON v_upcoming_reminders TO anon, authenticated;
GRANT SELECT ON v_unread_notifications TO anon, authenticated;
GRANT SELECT ON v_activities_summary TO anon, authenticated;
GRANT EXECUTE ON FUNCTION generate_stock_notifications TO anon, authenticated;
GRANT EXECUTE ON FUNCTION generate_overdue_invoice_notifications TO anon, authenticated;
GRANT EXECUTE ON FUNCTION check_overdue_activities TO anon, authenticated;

-- =====================================================
-- DATOS DE EJEMPLO (opcional)
-- =====================================================

-- INSERT INTO activities (title, activity_type, start_date, due_date, priority, status, color)
-- VALUES 
--     ('Revisar inventario semanal', 'reminder', NOW(), CURRENT_DATE + 7, 'medium', 'pending', '#4CAF50'),
--     ('Cobro pendiente Cliente X', 'collection', NOW(), CURRENT_DATE + 3, 'high', 'pending', '#FF9800');

SELECT '✅ Tabla activities creada' AS resultado;
SELECT '✅ Tabla notifications creada' AS resultado;
SELECT '✅ Vistas de actividades creadas' AS resultado;
SELECT '✅ Funciones de notificaciones creadas' AS resultado;
