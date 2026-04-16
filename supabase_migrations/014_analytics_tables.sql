-- =====================================================
-- TABLAS PARA ANALÍTICA Y REPORTES
-- Industrial de Molinos
-- Fecha: 23 de Diciembre, 2025
-- =====================================================

-- =====================================================
-- 1. TABLA DE EMPLEADOS
-- =====================================================
CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(20) UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    document_type VARCHAR(10) DEFAULT 'dni', -- dni, ce, passport
    document_number VARCHAR(20) UNIQUE,
    position VARCHAR(100), -- Cargo: Soldador, Tornero, Administrador, etc.
    department VARCHAR(50), -- Producción, Administración, Ventas
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE,
    termination_date DATE,
    salary DECIMAL(12,2) DEFAULT 0, -- Sueldo mensual base
    hourly_rate DECIMAL(10,2) DEFAULT 0, -- Tarifa por hora (si aplica)
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    emergency_contact VARCHAR(255),
    bank_name VARCHAR(100),
    bank_account VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_employees_active ON employees(is_active);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department);

-- =====================================================
-- 2. TABLA DE GASTOS FIJOS/OPERATIVOS MENSUALES
-- =====================================================
CREATE TABLE IF NOT EXISTS monthly_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    
    -- Servicios
    electricity_cost DECIMAL(12,2) DEFAULT 0, -- Luz
    gas_cost DECIMAL(12,2) DEFAULT 0, -- Gas
    water_cost DECIMAL(12,2) DEFAULT 0, -- Agua
    internet_cost DECIMAL(12,2) DEFAULT 0, -- Internet/Teléfono
    
    -- Local
    rent_cost DECIMAL(12,2) DEFAULT 0, -- Alquiler
    maintenance_cost DECIMAL(12,2) DEFAULT 0, -- Mantenimiento local
    
    -- Personal
    salaries_cost DECIMAL(12,2) DEFAULT 0, -- Total sueldos
    benefits_cost DECIMAL(12,2) DEFAULT 0, -- Beneficios (essalud, cts, etc)
    
    -- Otros
    supplies_cost DECIMAL(12,2) DEFAULT 0, -- Suministros de oficina
    transport_cost DECIMAL(12,2) DEFAULT 0, -- Transporte/Combustible
    insurance_cost DECIMAL(12,2) DEFAULT 0, -- Seguros
    taxes_cost DECIMAL(12,2) DEFAULT 0, -- Impuestos fijos
    other_cost DECIMAL(12,2) DEFAULT 0, -- Otros gastos
    other_description TEXT, -- Descripción de otros gastos
    
    -- Totales calculados
    total_fixed DECIMAL(12,2) GENERATED ALWAYS AS (
        electricity_cost + gas_cost + water_cost + internet_cost +
        rent_cost + maintenance_cost + salaries_cost + benefits_cost +
        supplies_cost + transport_cost + insurance_cost + taxes_cost + other_cost
    ) STORED,
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Solo un registro por mes/año
    UNIQUE(year, month)
);

-- Índice
CREATE INDEX IF NOT EXISTS idx_monthly_expenses_period ON monthly_expenses(year, month);

-- =====================================================
-- 3. TABLA DE PROVEEDORES (mejorada)
-- =====================================================
-- Verificar si existe y agregar campos faltantes
DO $$ 
BEGIN
    -- Crear tabla si no existe
    CREATE TABLE IF NOT EXISTS suppliers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        code VARCHAR(20) UNIQUE,
        name VARCHAR(255) NOT NULL,
        trade_name VARCHAR(255),
        ruc VARCHAR(11) UNIQUE,
        address TEXT,
        phone VARCHAR(20),
        email VARCHAR(255),
        contact_person VARCHAR(100),
        category VARCHAR(50), -- Acero, Tornillería, Servicios, etc.
        payment_terms VARCHAR(100), -- Contado, Crédito 30 días, etc.
        credit_limit DECIMAL(12,2) DEFAULT 0,
        current_debt DECIMAL(12,2) DEFAULT 0,
        bank_name VARCHAR(100),
        bank_account VARCHAR(50),
        is_active BOOLEAN DEFAULT TRUE,
        rating INTEGER CHECK (rating >= 1 AND rating <= 5), -- Calificación 1-5
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );
EXCEPTION WHEN duplicate_table THEN
    NULL;
END $$;

-- Índices para proveedores
CREATE INDEX IF NOT EXISTS idx_suppliers_active ON suppliers(is_active);
CREATE INDEX IF NOT EXISTS idx_suppliers_category ON suppliers(category);

-- =====================================================
-- 4. TABLA DE COMPRAS (ÓRDENES DE COMPRA)
-- =====================================================
CREATE TABLE IF NOT EXISTS purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    number VARCHAR(20) NOT NULL UNIQUE, -- OC-2024-001
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
    supplier_name VARCHAR(255) NOT NULL,
    supplier_ruc VARCHAR(11),
    
    -- Montos
    subtotal DECIMAL(12,2) DEFAULT 0,
    tax_rate DECIMAL(5,2) DEFAULT 18.00,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    discount DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) DEFAULT 0,
    
    -- Estado
    status VARCHAR(20) DEFAULT 'pending', -- pending, received, partial, cancelled
    
    -- Pago
    payment_status VARCHAR(20) DEFAULT 'pending', -- pending, partial, paid
    paid_amount DECIMAL(12,2) DEFAULT 0,
    payment_method VARCHAR(20), -- cash, transfer, credit
    payment_date DATE,
    
    -- Referencias
    invoice_number VARCHAR(50), -- Número de factura del proveedor
    delivery_date DATE,
    received_date DATE,
    
    notes TEXT,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_purchases_date ON purchases(date);
CREATE INDEX IF NOT EXISTS idx_purchases_supplier ON purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchases_status ON purchases(status);

-- =====================================================
-- 5. TABLA DE ITEMS DE COMPRA
-- =====================================================
CREATE TABLE IF NOT EXISTS purchase_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    material_id UUID REFERENCES materials(id) ON DELETE SET NULL,
    
    -- Descripción
    code VARCHAR(50),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    
    -- Cantidades
    quantity DECIMAL(12,3) NOT NULL,
    unit VARCHAR(20) DEFAULT 'UND',
    received_quantity DECIMAL(12,3) DEFAULT 0,
    
    -- Precios
    unit_price DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON purchase_items(purchase_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_material ON purchase_items(material_id);

-- =====================================================
-- 6. TABLA DE PAGOS A EMPLEADOS
-- =====================================================
CREATE TABLE IF NOT EXISTS employee_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Período
    year INTEGER NOT NULL,
    month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
    payment_type VARCHAR(30) NOT NULL, -- salary, bonus, overtime, advance, cts, gratification
    
    -- Montos
    base_amount DECIMAL(12,2) DEFAULT 0, -- Monto base
    overtime_hours DECIMAL(8,2) DEFAULT 0,
    overtime_amount DECIMAL(12,2) DEFAULT 0,
    bonus_amount DECIMAL(12,2) DEFAULT 0,
    deductions DECIMAL(12,2) DEFAULT 0, -- AFP, ONP, préstamos, etc.
    net_amount DECIMAL(12,2) DEFAULT 0, -- Neto a pagar
    
    -- Pago
    payment_date DATE,
    payment_method VARCHAR(20), -- cash, transfer
    account_id UUID REFERENCES accounts(id), -- Cuenta de donde salió
    reference VARCHAR(100),
    
    status VARCHAR(20) DEFAULT 'pending', -- pending, paid
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_employee_payments_employee ON employee_payments(employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_payments_period ON employee_payments(year, month);

-- =====================================================
-- 7. TABLA DE HISTORIAL DE PRECIOS DE MATERIALES
-- =====================================================
CREATE TABLE IF NOT EXISTS material_price_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    old_price DECIMAL(12,2),
    new_price DECIMAL(12,2),
    old_cost DECIMAL(12,2),
    new_cost DECIMAL(12,2),
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    changed_by UUID,
    reason TEXT
);

-- Índice
CREATE INDEX IF NOT EXISTS idx_material_price_history ON material_price_history(material_id, changed_at);

-- =====================================================
-- 8. VISTAS ANALÍTICAS
-- =====================================================

-- Vista: Historial de compras por cliente
CREATE OR REPLACE VIEW v_customer_purchase_history AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.document_number,
    c.type AS customer_type,
    i.id AS invoice_id,
    i.full_number AS invoice_number,
    i.issue_date,
    i.total AS invoice_total,
    i.status AS invoice_status,
    ii.product_name,
    ii.product_code,
    ii.quantity,
    ii.unit_price,
    ii.total AS item_total
FROM customers c
LEFT JOIN invoices i ON c.id = i.customer_id
LEFT JOIN invoice_items ii ON i.id = ii.invoice_id
WHERE i.status != 'cancelled'
ORDER BY c.id, i.issue_date DESC;

-- Vista: Resumen de cliente con métricas
CREATE OR REPLACE VIEW v_customer_metrics AS
SELECT 
    c.id,
    c.name,
    c.document_number,
    c.type,
    c.current_balance AS debt,
    c.credit_limit,
    c.created_at AS customer_since,
    COUNT(DISTINCT i.id) AS total_purchases,
    COALESCE(SUM(i.total), 0) AS total_spent,
    COALESCE(AVG(i.total), 0) AS average_ticket,
    MAX(i.issue_date) AS last_purchase_date,
    MIN(i.issue_date) AS first_purchase_date,
    EXTRACT(DAY FROM NOW() - MAX(i.issue_date))::INTEGER AS days_since_last_purchase
FROM customers c
LEFT JOIN invoices i ON c.id = i.customer_id AND i.status != 'cancelled'
GROUP BY c.id, c.name, c.document_number, c.type, c.current_balance, c.credit_limit, c.created_at;

-- Vista: Productos más vendidos
CREATE OR REPLACE VIEW v_top_selling_products AS
SELECT 
    COALESCE(ii.product_id::TEXT, ii.material_id::TEXT, ii.product_code) AS product_key,
    ii.product_name,
    ii.product_code,
    SUM(ii.quantity) AS total_quantity,
    COUNT(DISTINCT ii.invoice_id) AS times_sold,
    SUM(ii.total) AS total_revenue,
    AVG(ii.unit_price) AS avg_price
FROM invoice_items ii
JOIN invoices i ON ii.invoice_id = i.id
WHERE i.status != 'cancelled'
GROUP BY product_key, ii.product_name, ii.product_code
ORDER BY total_revenue DESC;

-- Vista: Consumo de materiales por mes
CREATE OR REPLACE VIEW v_material_consumption_monthly AS
SELECT 
    DATE_TRUNC('month', mm.created_at) AS month,
    m.id AS material_id,
    m.name AS material_name,
    m.code AS material_code,
    m.category,
    SUM(CASE WHEN mm.type = 'outgoing' THEN mm.quantity ELSE 0 END) AS consumed,
    SUM(CASE WHEN mm.type = 'incoming' THEN mm.quantity ELSE 0 END) AS received,
    COUNT(*) AS movements
FROM material_movements mm
JOIN materials m ON mm.material_id = m.id
GROUP BY DATE_TRUNC('month', mm.created_at), m.id, m.name, m.code, m.category
ORDER BY month DESC, consumed DESC;

-- Vista: Ventas por período
CREATE OR REPLACE VIEW v_sales_by_period AS
SELECT 
    DATE_TRUNC('day', issue_date) AS day,
    DATE_TRUNC('week', issue_date) AS week,
    DATE_TRUNC('month', issue_date) AS month,
    DATE_TRUNC('year', issue_date) AS year,
    COUNT(*) AS num_invoices,
    SUM(subtotal) AS subtotal,
    SUM(tax_amount) AS tax,
    SUM(total) AS total,
    SUM(paid_amount) AS collected,
    SUM(total - paid_amount) AS pending,
    AVG(total) AS avg_ticket
FROM invoices
WHERE status != 'cancelled'
GROUP BY day, week, month, year
ORDER BY day DESC;

-- Vista: Gastos vs Ingresos por mes
CREATE OR REPLACE VIEW v_profit_loss_monthly AS
WITH monthly_sales AS (
    SELECT 
        EXTRACT(YEAR FROM issue_date)::INTEGER AS year,
        EXTRACT(MONTH FROM issue_date)::INTEGER AS month,
        COALESCE(SUM(total), 0) AS revenue
    FROM invoices
    WHERE status != 'cancelled'
    GROUP BY EXTRACT(YEAR FROM issue_date), EXTRACT(MONTH FROM issue_date)
),
monthly_variable_expenses AS (
    SELECT 
        EXTRACT(YEAR FROM date)::INTEGER AS year,
        EXTRACT(MONTH FROM date)::INTEGER AS month,
        COALESCE(SUM(amount), 0) AS variable_expenses
    FROM cash_movements
    WHERE type = 'expense'
    GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)
)
SELECT 
    ms.year,
    ms.month,
    ms.revenue,
    COALESCE(me.total_fixed, 0) AS fixed_expenses,
    COALESCE(mve.variable_expenses, 0) AS variable_expenses,
    ms.revenue - COALESCE(me.total_fixed, 0) - COALESCE(mve.variable_expenses, 0) AS gross_profit
FROM monthly_sales ms
LEFT JOIN monthly_expenses me ON ms.year = me.year AND ms.month = me.month
LEFT JOIN monthly_variable_expenses mve ON ms.year = mve.year AND ms.month = mve.month
ORDER BY ms.year DESC, ms.month DESC;

-- Vista: Análisis de productos por cliente (para predicción)
CREATE OR REPLACE VIEW v_customer_product_analysis AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    ii.product_name,
    ii.product_code,
    COUNT(*) AS purchase_count,
    SUM(ii.quantity) AS total_quantity,
    SUM(ii.total) AS total_spent,
    MIN(i.issue_date) AS first_purchase,
    MAX(i.issue_date) AS last_purchase,
    AVG(ii.quantity) AS avg_quantity_per_purchase
FROM customers c
JOIN invoices i ON c.id = i.customer_id
JOIN invoice_items ii ON i.id = ii.invoice_id
WHERE i.status != 'cancelled'
GROUP BY c.id, c.name, ii.product_name, ii.product_code
ORDER BY c.name, purchase_count DESC;

-- Vista: Cuentas por cobrar con antigüedad
CREATE OR REPLACE VIEW v_accounts_receivable_aging AS
SELECT 
    c.id AS customer_id,
    c.name AS customer_name,
    c.document_number,
    i.id AS invoice_id,
    i.full_number,
    i.issue_date,
    i.due_date,
    i.total,
    i.paid_amount,
    (i.total - i.paid_amount) AS pending_amount,
    CASE 
        WHEN i.due_date >= CURRENT_DATE THEN 'current'
        WHEN CURRENT_DATE - i.due_date <= 30 THEN '1-30 days'
        WHEN CURRENT_DATE - i.due_date <= 60 THEN '31-60 days'
        WHEN CURRENT_DATE - i.due_date <= 90 THEN '61-90 days'
        ELSE 'over 90 days'
    END AS aging_bucket,
    (CURRENT_DATE - i.due_date) AS days_overdue
FROM invoices i
JOIN customers c ON i.customer_id = c.id
WHERE i.status NOT IN ('paid', 'cancelled')
AND (i.total - i.paid_amount) > 0
ORDER BY days_overdue DESC;

-- =====================================================
-- 9. FUNCIONES ÚTILES
-- =====================================================

-- Función: Generar número de compra
CREATE OR REPLACE FUNCTION generate_purchase_number()
RETURNS VARCHAR AS $$
DECLARE
    v_year VARCHAR;
    v_number INTEGER;
    v_result VARCHAR;
BEGIN
    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(CAST(SUBSTRING(number FROM 9) AS INTEGER)), 0) + 1
    INTO v_number
    FROM purchases
    WHERE number LIKE 'OC-' || v_year || '-%';
    
    v_result := 'OC-' || v_year || '-' || LPAD(v_number::TEXT, 4, '0');
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Función: Calcular CLV (Customer Lifetime Value) de un cliente
CREATE OR REPLACE FUNCTION calculate_customer_clv(p_customer_id UUID)
RETURNS TABLE (
    total_revenue DECIMAL,
    total_purchases INTEGER,
    avg_purchase_value DECIMAL,
    months_as_customer INTEGER,
    monthly_revenue DECIMAL,
    estimated_annual_value DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(i.total), 0)::DECIMAL AS total_revenue,
        COUNT(i.id)::INTEGER AS total_purchases,
        COALESCE(AVG(i.total), 0)::DECIMAL AS avg_purchase_value,
        GREATEST(1, EXTRACT(MONTH FROM AGE(NOW(), MIN(i.issue_date))))::INTEGER AS months_as_customer,
        (COALESCE(SUM(i.total), 0) / GREATEST(1, EXTRACT(MONTH FROM AGE(NOW(), MIN(i.issue_date)))))::DECIMAL AS monthly_revenue,
        (COALESCE(SUM(i.total), 0) / GREATEST(1, EXTRACT(MONTH FROM AGE(NOW(), MIN(i.issue_date)))) * 12)::DECIMAL AS estimated_annual_value
    FROM invoices i
    WHERE i.customer_id = p_customer_id
    AND i.status != 'cancelled';
END;
$$ LANGUAGE plpgsql;

-- Función: Obtener productos relacionados (comprados juntos)
CREATE OR REPLACE FUNCTION get_related_products(p_product_code VARCHAR, p_limit INTEGER DEFAULT 5)
RETURNS TABLE (
    related_product_name VARCHAR,
    related_product_code VARCHAR,
    times_bought_together INTEGER,
    avg_quantity DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ii2.product_name::VARCHAR,
        ii2.product_code::VARCHAR,
        COUNT(*)::INTEGER AS times_bought_together,
        AVG(ii2.quantity)::DECIMAL AS avg_quantity
    FROM invoice_items ii1
    JOIN invoice_items ii2 ON ii1.invoice_id = ii2.invoice_id AND ii1.id != ii2.id
    WHERE ii1.product_code = p_product_code
    GROUP BY ii2.product_name, ii2.product_code
    ORDER BY times_bought_together DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 10. TRIGGERS
-- =====================================================

-- Trigger: Actualizar stock al recibir compra
CREATE OR REPLACE FUNCTION update_stock_on_purchase_received()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'received' AND OLD.status != 'received' THEN
        -- Actualizar stock de materiales
        UPDATE materials m
        SET stock = m.stock + pi.quantity,
            updated_at = NOW()
        FROM purchase_items pi
        WHERE pi.purchase_id = NEW.id
        AND pi.material_id = m.id;
        
        -- Registrar movimientos
        INSERT INTO material_movements (material_id, type, quantity, reason, reference)
        SELECT 
            pi.material_id,
            'incoming',
            pi.quantity,
            'Compra recibida',
            NEW.number
        FROM purchase_items pi
        WHERE pi.purchase_id = NEW.id
        AND pi.material_id IS NOT NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_purchase_received ON purchases;
CREATE TRIGGER trigger_purchase_received
    AFTER UPDATE ON purchases
    FOR EACH ROW
    EXECUTE FUNCTION update_stock_on_purchase_received();

-- Trigger: Registrar historial de precios
CREATE OR REPLACE FUNCTION log_material_price_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.price_per_kg != NEW.price_per_kg OR OLD.cost_price != NEW.cost_price THEN
        INSERT INTO material_price_history (material_id, old_price, new_price, old_cost, new_cost)
        VALUES (NEW.id, OLD.price_per_kg, NEW.price_per_kg, OLD.cost_price, NEW.cost_price);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_material_price_change ON materials;
CREATE TRIGGER trigger_material_price_change
    AFTER UPDATE ON materials
    FOR EACH ROW
    EXECUTE FUNCTION log_material_price_change();

-- =====================================================
-- 11. PERMISOS RLS
-- =====================================================
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE material_price_history ENABLE ROW LEVEL SECURITY;

-- Políticas permisivas (ajustar según necesidades de seguridad)
DROP POLICY IF EXISTS "Allow all on employees" ON employees;
DROP POLICY IF EXISTS "Allow all on monthly_expenses" ON monthly_expenses;
DROP POLICY IF EXISTS "Allow all on suppliers" ON suppliers;
DROP POLICY IF EXISTS "Allow all on purchases" ON purchases;
DROP POLICY IF EXISTS "Allow all on purchase_items" ON purchase_items;
DROP POLICY IF EXISTS "Allow all on employee_payments" ON employee_payments;
DROP POLICY IF EXISTS "Allow all on material_price_history" ON material_price_history;

CREATE POLICY "Allow all on employees" ON employees FOR ALL USING (true);
CREATE POLICY "Allow all on monthly_expenses" ON monthly_expenses FOR ALL USING (true);
CREATE POLICY "Allow all on suppliers" ON suppliers FOR ALL USING (true);
CREATE POLICY "Allow all on purchases" ON purchases FOR ALL USING (true);
CREATE POLICY "Allow all on purchase_items" ON purchase_items FOR ALL USING (true);
CREATE POLICY "Allow all on employee_payments" ON employee_payments FOR ALL USING (true);
CREATE POLICY "Allow all on material_price_history" ON material_price_history FOR ALL USING (true);

-- =====================================================
-- 12. GRANTS
-- =====================================================
GRANT ALL ON employees TO anon, authenticated;
GRANT ALL ON monthly_expenses TO anon, authenticated;
GRANT ALL ON suppliers TO anon, authenticated;
GRANT ALL ON purchases TO anon, authenticated;
GRANT ALL ON purchase_items TO anon, authenticated;
GRANT ALL ON employee_payments TO anon, authenticated;
GRANT ALL ON material_price_history TO anon, authenticated;

-- Grants para vistas
GRANT SELECT ON v_customer_purchase_history TO anon, authenticated;
GRANT SELECT ON v_customer_metrics TO anon, authenticated;
GRANT SELECT ON v_top_selling_products TO anon, authenticated;
GRANT SELECT ON v_material_consumption_monthly TO anon, authenticated;
GRANT SELECT ON v_sales_by_period TO anon, authenticated;
GRANT SELECT ON v_profit_loss_monthly TO anon, authenticated;
GRANT SELECT ON v_customer_product_analysis TO anon, authenticated;
GRANT SELECT ON v_accounts_receivable_aging TO anon, authenticated;

-- Grants para funciones
GRANT EXECUTE ON FUNCTION generate_purchase_number TO anon, authenticated;
GRANT EXECUTE ON FUNCTION calculate_customer_clv TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_related_products TO anon, authenticated;

-- =====================================================
-- RESUMEN DE LO CREADO
-- =====================================================
SELECT '✅ Tablas creadas:' AS info;
SELECT '   - employees (empleados)' AS tabla;
SELECT '   - monthly_expenses (gastos mensuales)' AS tabla;
SELECT '   - suppliers (proveedores)' AS tabla;
SELECT '   - purchases (compras)' AS tabla;
SELECT '   - purchase_items (items de compra)' AS tabla;
SELECT '   - employee_payments (pagos a empleados)' AS tabla;
SELECT '   - material_price_history (historial de precios)' AS tabla;
SELECT '' AS spacer;
SELECT '✅ Vistas analíticas:' AS info;
SELECT '   - v_customer_purchase_history' AS vista;
SELECT '   - v_customer_metrics' AS vista;
SELECT '   - v_top_selling_products' AS vista;
SELECT '   - v_material_consumption_monthly' AS vista;
SELECT '   - v_sales_by_period' AS vista;
SELECT '   - v_profit_loss_monthly' AS vista;
SELECT '   - v_customer_product_analysis' AS vista;
SELECT '   - v_accounts_receivable_aging' AS vista;
SELECT '' AS spacer;
SELECT '✅ Funciones:' AS info;
SELECT '   - generate_purchase_number()' AS funcion;
SELECT '   - calculate_customer_clv(customer_id)' AS funcion;
SELECT '   - get_related_products(product_code)' AS funcion;
