-- =====================================================
-- TABLA PARA TRACKING DE INTERESES EN FACTURAS
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- Tabla para registrar intereses aplicados
CREATE TABLE IF NOT EXISTS invoice_interests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    original_amount DECIMAL(12,2) NOT NULL,
    interest_rate DECIMAL(5,2) NOT NULL DEFAULT 2.0,
    interest_amount DECIMAL(12,2) NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL,
    days_overdue INTEGER NOT NULL DEFAULT 0,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    applied_by UUID REFERENCES auth.users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para búsqueda eficiente
CREATE INDEX IF NOT EXISTS idx_invoice_interests_invoice ON invoice_interests(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_interests_customer ON invoice_interests(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoice_interests_applied_at ON invoice_interests(applied_at);

-- Vista para deudas con intereses calculados
CREATE OR REPLACE VIEW v_debts_with_interest AS
SELECT 
    i.id AS invoice_id,
    i.full_number AS invoice_number,
    i.total AS original_total,
    i.paid_amount,
    (i.total - COALESCE(i.paid_amount, 0)) AS pending_amount,
    i.due_date,
    GREATEST(EXTRACT(DAY FROM NOW() - i.due_date), 0)::INTEGER AS days_overdue,
    c.id AS customer_id,
    COALESCE(c.trade_name, c.name) AS customer_name,
    c.phone AS contact_phone,
    c.email AS contact_email,
    -- Cálculo de intereses (2% mensual por defecto)
    CASE 
        WHEN NOW() > i.due_date THEN 
            (i.total - COALESCE(i.paid_amount, 0)) * 0.02 * (EXTRACT(DAY FROM NOW() - i.due_date) / 30)
        ELSE 0
    END AS calculated_interest,
    -- Total con intereses
    (i.total - COALESCE(i.paid_amount, 0)) + 
    CASE 
        WHEN NOW() > i.due_date THEN 
            (i.total - COALESCE(i.paid_amount, 0)) * 0.02 * (EXTRACT(DAY FROM NOW() - i.due_date) / 30)
        ELSE 0
    END AS total_with_interest,
    -- Estado de mora
    CASE 
        WHEN NOW() <= i.due_date THEN 'vigente'
        WHEN EXTRACT(DAY FROM NOW() - i.due_date) <= 30 THEN 'vencido'
        WHEN EXTRACT(DAY FROM NOW() - i.due_date) <= 60 THEN 'moroso'
        ELSE 'critico'
    END AS mora_status,
    -- Verificar si tiene interés aplicado
    EXISTS(SELECT 1 FROM invoice_interests ii WHERE ii.invoice_id = i.id) AS interest_applied
FROM invoices i
JOIN customers c ON i.customer_id = c.id
WHERE i.status IN ('draft', 'issued', 'partial', 'overdue')
  AND (i.total - COALESCE(i.paid_amount, 0)) > 0
ORDER BY days_overdue DESC;

-- Función para obtener resumen de mora por cliente
CREATE OR REPLACE FUNCTION get_customer_mora_summary(p_customer_id UUID DEFAULT NULL)
RETURNS TABLE (
    customer_id UUID,
    customer_name TEXT,
    total_debt DECIMAL,
    total_interest DECIMAL,
    total_with_interest DECIMAL,
    invoices_count INTEGER,
    max_days_overdue INTEGER,
    mora_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.customer_id,
        v.customer_name::TEXT,
        SUM(v.pending_amount)::DECIMAL AS total_debt,
        SUM(v.calculated_interest)::DECIMAL AS total_interest,
        SUM(v.total_with_interest)::DECIMAL AS total_with_interest,
        COUNT(*)::INTEGER AS invoices_count,
        MAX(v.days_overdue)::INTEGER AS max_days_overdue,
        CASE 
            WHEN MAX(v.days_overdue) <= 0 THEN 'vigente'
            WHEN MAX(v.days_overdue) <= 30 THEN 'vencido'
            WHEN MAX(v.days_overdue) <= 60 THEN 'moroso'
            ELSE 'critico'
        END::TEXT AS mora_status
    FROM v_debts_with_interest v
    WHERE (p_customer_id IS NULL OR v.customer_id = p_customer_id)
    GROUP BY v.customer_id, v.customer_name;
END;
$$ LANGUAGE plpgsql;

-- RLS Policies
ALTER TABLE invoice_interests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "invoice_interests_select_policy" ON invoice_interests
    FOR SELECT USING (true);

CREATE POLICY "invoice_interests_insert_policy" ON invoice_interests
    FOR INSERT WITH CHECK (true);

CREATE POLICY "invoice_interests_update_policy" ON invoice_interests
    FOR UPDATE USING (true);

CREATE POLICY "invoice_interests_delete_policy" ON invoice_interests
    FOR DELETE USING (true);

-- Comentarios
COMMENT ON TABLE invoice_interests IS 'Registro de intereses aplicados a facturas vencidas';
COMMENT ON VIEW v_debts_with_interest IS 'Vista de deudas con cálculo automático de intereses por mora';
COMMENT ON FUNCTION get_customer_mora_summary IS 'Obtiene resumen de mora e intereses por cliente';

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================
