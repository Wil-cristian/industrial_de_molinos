-- =====================================================
-- 084: Sistema de Comisiones por Ventas
-- =====================================================
-- Comisión por defecto: 1.6667% (100,000 / 6,000,000)
-- =====================================================

-- 1. Agregar columnas de vendedor y comisión a facturas
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS seller_id UUID REFERENCES employees(id);
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS has_commission BOOLEAN DEFAULT FALSE;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS commission_percentage DECIMAL(8,4) DEFAULT 0;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS commission_amount DECIMAL(12,2) DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_invoices_seller ON invoices(seller_id);
CREATE INDEX IF NOT EXISTS idx_invoices_commission ON invoices(has_commission) WHERE has_commission = TRUE;

-- 2. Tabla de comisiones por venta
CREATE TABLE IF NOT EXISTS sales_commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id),
    invoice_number VARCHAR(30),
    customer_name VARCHAR(255),
    invoice_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    commission_percentage DECIMAL(8,4) NOT NULL DEFAULT 1.6667,
    commission_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'pendiente',  -- pendiente, pagada, anulada
    payroll_id UUID REFERENCES payroll(id),
    paid_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_commission_status CHECK (status IN ('pendiente', 'pagada', 'anulada'))
);

CREATE INDEX IF NOT EXISTS idx_sales_commissions_employee ON sales_commissions(employee_id);
CREATE INDEX IF NOT EXISTS idx_sales_commissions_invoice ON sales_commissions(invoice_id);
CREATE INDEX IF NOT EXISTS idx_sales_commissions_status ON sales_commissions(status);
CREATE INDEX IF NOT EXISTS idx_sales_commissions_employee_status ON sales_commissions(employee_id, status);

-- 3. Configuración de comisiones por empleado (opcional, override del default)
CREATE TABLE IF NOT EXISTS commission_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID UNIQUE REFERENCES employees(id) ON DELETE CASCADE,
    commission_percentage DECIMAL(8,4) NOT NULL DEFAULT 1.6667,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_commission_settings_employee ON commission_settings(employee_id);

-- 4. RLS policies
ALTER TABLE sales_commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth_sales_commissions" ON sales_commissions;
CREATE POLICY "auth_sales_commissions" ON sales_commissions FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_commission_settings" ON commission_settings;
CREATE POLICY "auth_commission_settings" ON commission_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 5. Grants
GRANT ALL ON sales_commissions TO anon, authenticated;
GRANT ALL ON commission_settings TO anon, authenticated;

-- 6. Asegurar que el concepto COMISION existe en payroll_concepts
INSERT INTO payroll_concepts (code, name, type, category, is_percentage, default_value, description, is_active)
VALUES ('COMISION_VENTAS', 'Comisión por Ventas', 'ingreso', 'bonificacion', false, 0, 'Comisión acumulada por ventas del periodo', true)
ON CONFLICT (code) DO NOTHING;

-- 7. Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_sales_commissions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sales_commissions_updated_at ON sales_commissions;
CREATE TRIGGER trg_sales_commissions_updated_at
    BEFORE UPDATE ON sales_commissions
    FOR EACH ROW
    EXECUTE FUNCTION update_sales_commissions_updated_at();

-- 8. Función para obtener el total de comisiones pendientes de un empleado
CREATE OR REPLACE FUNCTION get_pending_commissions(p_employee_id UUID)
RETURNS TABLE (
    total_pending DECIMAL(12,2),
    commission_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(sc.commission_amount), 0)::DECIMAL(12,2) AS total_pending,
        COUNT(*)::BIGINT AS commission_count
    FROM sales_commissions sc
    WHERE sc.employee_id = p_employee_id
      AND sc.status = 'pendiente';
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION get_pending_commissions(UUID) TO authenticated;
