-- =====================================================
-- INDUSTRIAL DE MOLINOS - ESQUEMA DE BASE DE DATOS
-- Supabase PostgreSQL
-- Fecha: 9 de Diciembre, 2025
-- Versión: 1.0
-- =====================================================

-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- TABLAS DE CONFIGURACIÓN
-- =====================================================

-- Tabla: company_settings (Configuración de la empresa)
CREATE TABLE IF NOT EXISTS company_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL DEFAULT 'Industrial de Molinos',
    trade_name VARCHAR(255),
    ruc VARCHAR(11),
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    logo_url TEXT,
    currency VARCHAR(10) DEFAULT 'PEN',
    tax_rate DECIMAL(5,2) DEFAULT 18.00,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla: operational_costs (Costos operativos)
CREATE TABLE IF NOT EXISTS operational_costs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    labor_rate_per_hour DECIMAL(10,2) DEFAULT 25.00,
    energy_rate_per_kwh DECIMAL(10,4) DEFAULT 0.50,
    gas_rate_per_m3 DECIMAL(10,4) DEFAULT 2.00,
    default_profit_margin DECIMAL(5,2) DEFAULT 20.00,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- TABLAS DE CATÁLOGOS
-- =====================================================

-- Tabla: categories (Categorías de productos)
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla: material_prices (Precios de materiales)
CREATE TABLE IF NOT EXISTS material_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL, -- lamina, tubo, eje, etc.
    type VARCHAR(50), -- A36, Inox 304, SAE 1045, etc.
    thickness DECIMAL(10,2) DEFAULT 0, -- Espesor en mm
    price_per_kg DECIMAL(10,2) NOT NULL,
    density DECIMAL(10,4) DEFAULT 7.85, -- Densidad en kg/dm³
    unit VARCHAR(10) DEFAULT 'kg',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para búsquedas por categoría de material
CREATE INDEX IF NOT EXISTS idx_material_prices_category ON material_prices(category);

-- =====================================================
-- TABLAS DE CLIENTES
-- =====================================================

-- Enum para tipo de cliente
DO $$ BEGIN
    CREATE TYPE customer_type AS ENUM ('individual', 'business');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE document_type AS ENUM ('dni', 'ruc', 'ce', 'passport');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Tabla: customers (Clientes)
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type customer_type NOT NULL DEFAULT 'business',
    document_type document_type NOT NULL DEFAULT 'ruc',
    document_number VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    credit_limit DECIMAL(12,2) DEFAULT 0,
    current_balance DECIMAL(12,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para búsquedas frecuentes
CREATE INDEX IF NOT EXISTS idx_customers_document ON customers(document_number);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);
CREATE INDEX IF NOT EXISTS idx_customers_active ON customers(is_active);

-- =====================================================
-- TABLAS DE PRODUCTOS
-- =====================================================

-- Tabla: products (Productos)
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    unit_price DECIMAL(12,2) NOT NULL DEFAULT 0,
    cost_price DECIMAL(12,2) NOT NULL DEFAULT 0,
    stock DECIMAL(12,3) DEFAULT 0,
    min_stock DECIMAL(12,3) DEFAULT 0,
    unit VARCHAR(20) DEFAULT 'UND',
    is_active BOOLEAN DEFAULT TRUE,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_products_code ON products(code);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active);

-- Enum para tipo de movimiento de stock
DO $$ BEGIN
    CREATE TYPE stock_movement_type AS ENUM ('incoming', 'outgoing', 'adjustment');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Tabla: stock_movements (Movimientos de stock)
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    type stock_movement_type NOT NULL,
    quantity DECIMAL(12,3) NOT NULL,
    previous_stock DECIMAL(12,3),
    new_stock DECIMAL(12,3),
    reason TEXT,
    reference VARCHAR(100), -- Número de factura, orden, etc.
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para búsquedas por producto
CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(created_at);

-- =====================================================
-- TABLAS DE COTIZACIONES
-- =====================================================

-- Enum para estado de cotización
DO $$ BEGIN
    CREATE TYPE quotation_status AS ENUM ('Borrador', 'Enviada', 'Aprobada', 'Rechazada', 'Vencida');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Tabla: quotations (Cotizaciones)
CREATE TABLE IF NOT EXISTS quotations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    number VARCHAR(20) NOT NULL UNIQUE, -- COT-2024-001
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE NOT NULL,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_document VARCHAR(20),
    status quotation_status DEFAULT 'Borrador',
    -- Costos
    materials_cost DECIMAL(12,2) DEFAULT 0,
    labor_cost DECIMAL(12,2) DEFAULT 0,
    labor_hours DECIMAL(8,2) DEFAULT 0,
    labor_rate DECIMAL(10,2) DEFAULT 25.00,
    energy_cost DECIMAL(12,2) DEFAULT 0,
    gas_cost DECIMAL(12,2) DEFAULT 0,
    supplies_cost DECIMAL(12,2) DEFAULT 0,
    other_costs DECIMAL(12,2) DEFAULT 0,
    -- Totales
    subtotal DECIMAL(12,2) DEFAULT 0,
    profit_margin DECIMAL(5,2) DEFAULT 20.00,
    profit_amount DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) DEFAULT 0,
    total_weight DECIMAL(12,3) DEFAULT 0, -- Peso total en kg
    -- Otros
    notes TEXT,
    terms TEXT, -- Condiciones de pago, garantías, etc.
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_quotations_number ON quotations(number);
CREATE INDEX IF NOT EXISTS idx_quotations_customer ON quotations(customer_id);
CREATE INDEX IF NOT EXISTS idx_quotations_status ON quotations(status);
CREATE INDEX IF NOT EXISTS idx_quotations_date ON quotations(date);

-- Enum para tipo de componente
DO $$ BEGIN
    CREATE TYPE component_type AS ENUM ('cylinder', 'circular_plate', 'rectangular_plate', 'shaft', 'ring', 'custom', 'product');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Tabla: quotation_items (Items de cotización)
CREATE TABLE IF NOT EXISTS quotation_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    quotation_id UUID NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    type component_type NOT NULL DEFAULT 'custom',
    -- Material
    material_id UUID REFERENCES material_prices(id) ON DELETE SET NULL,
    material_name VARCHAR(100),
    material_type VARCHAR(50),
    -- Dimensiones (almacenadas como JSON para flexibilidad)
    dimensions JSONB DEFAULT '{}',
    dimensions_text VARCHAR(255), -- Representación legible: Ø1000mm × 12mm × 2000mm
    -- Cantidades y pesos
    quantity INTEGER DEFAULT 1,
    unit_weight DECIMAL(12,3) DEFAULT 0, -- Peso unitario en kg
    total_weight DECIMAL(12,3) DEFAULT 0, -- Peso total en kg
    -- Precios
    price_per_kg DECIMAL(10,2) DEFAULT 0,
    unit_price DECIMAL(12,2) DEFAULT 0,
    total_price DECIMAL(12,2) DEFAULT 0,
    -- Orden
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para obtener items por cotización
CREATE INDEX IF NOT EXISTS idx_quotation_items_quotation ON quotation_items(quotation_id);

-- =====================================================
-- TABLAS DE FACTURACIÓN
-- =====================================================

-- Enums para facturas
DO $$ BEGIN
    CREATE TYPE invoice_type AS ENUM ('invoice', 'receipt', 'credit_note', 'debit_note');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE invoice_status AS ENUM ('draft', 'issued', 'paid', 'partial', 'cancelled', 'overdue');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE payment_method AS ENUM ('cash', 'card', 'transfer', 'credit', 'check');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- Tabla: invoices (Facturas/Comprobantes)
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type invoice_type NOT NULL DEFAULT 'invoice',
    series VARCHAR(10) NOT NULL, -- F001, B001
    number VARCHAR(20) NOT NULL,
    full_number VARCHAR(30) GENERATED ALWAYS AS (series || '-' || number) STORED,
    -- Cliente
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_document VARCHAR(20),
    customer_address TEXT,
    -- Fechas
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    -- Montos
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax_rate DECIMAL(5,2) DEFAULT 18.00,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    discount DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) NOT NULL DEFAULT 0,
    paid_amount DECIMAL(12,2) DEFAULT 0,
    pending_amount DECIMAL(12,2) GENERATED ALWAYS AS (total - paid_amount) STORED,
    -- Estado
    status invoice_status DEFAULT 'draft',
    payment_method payment_method,
    -- Referencias
    quotation_id UUID REFERENCES quotations(id) ON DELETE SET NULL,
    notes TEXT,
    -- Auditoría
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Restricción única para serie-número
    UNIQUE(series, number)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_invoices_full_number ON invoices(full_number);
CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(issue_date);
CREATE INDEX IF NOT EXISTS idx_invoices_due_date ON invoices(due_date);

-- Tabla: invoice_items (Items de factura)
CREATE TABLE IF NOT EXISTS invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    product_code VARCHAR(50),
    product_name VARCHAR(255) NOT NULL,
    description TEXT,
    quantity DECIMAL(12,3) NOT NULL,
    unit VARCHAR(20) DEFAULT 'UND',
    unit_price DECIMAL(12,2) NOT NULL,
    discount DECIMAL(12,2) DEFAULT 0,
    tax_rate DECIMAL(5,2) DEFAULT 18.00,
    subtotal DECIMAL(12,2) NOT NULL,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) NOT NULL,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para obtener items por factura
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);

-- Tabla: payments (Pagos)
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    amount DECIMAL(12,2) NOT NULL,
    method payment_method NOT NULL,
    reference VARCHAR(100), -- Número de operación, cheque, etc.
    notes TEXT,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice
CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date);

-- =====================================================
-- TABLAS DE CONTABILIDAD
-- =====================================================

-- Tabla: chart_of_accounts (Plan de cuentas)
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL, -- asset, liability, equity, income, expense
    parent_code VARCHAR(20),
    level INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    accepts_entries BOOLEAN DEFAULT TRUE, -- Solo cuentas de detalle
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla: journal_entries (Asientos contables)
CREATE TABLE IF NOT EXISTS journal_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_number VARCHAR(20) NOT NULL UNIQUE,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    description TEXT NOT NULL,
    reference VARCHAR(100), -- Factura, recibo, etc.
    reference_id UUID, -- ID de factura, pago, etc.
    total_debit DECIMAL(12,2) DEFAULT 0,
    total_credit DECIMAL(12,2) DEFAULT 0,
    is_balanced BOOLEAN GENERATED ALWAYS AS (total_debit = total_credit) STORED,
    status VARCHAR(20) DEFAULT 'draft', -- draft, posted, cancelled
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    posted_at TIMESTAMPTZ
);

-- Tabla: journal_entry_lines (Líneas de asiento)
CREATE TABLE IF NOT EXISTS journal_entry_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES chart_of_accounts(id),
    account_code VARCHAR(20) NOT NULL,
    description TEXT,
    debit DECIMAL(12,2) DEFAULT 0,
    credit DECIMAL(12,2) DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_journal_entry_lines_entry ON journal_entry_lines(entry_id);
CREATE INDEX IF NOT EXISTS idx_journal_entry_lines_account ON journal_entry_lines(account_id);

-- =====================================================
-- TABLAS DE PLANTILLAS (Templates de productos frecuentes)
-- =====================================================

-- Tabla: product_templates (Plantillas de productos/molinos)
CREATE TABLE IF NOT EXISTS product_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL, -- Molino 4x6 pies, Molino 3x4 pies
    description TEXT,
    category VARCHAR(100), -- molino_bolas, chancadora, etc.
    -- Valores por defecto
    default_components JSONB DEFAULT '[]', -- Lista de componentes típicos
    estimated_weight DECIMAL(12,3) DEFAULT 0,
    estimated_hours DECIMAL(8,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- TABLAS DE AUDITORÍA Y SINCRONIZACIÓN
-- =====================================================

-- Tabla: sync_log (Log de sincronización)
CREATE TABLE IF NOT EXISTS sync_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    action VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
    old_data JSONB,
    new_data JSONB,
    synced_at TIMESTAMPTZ DEFAULT NOW(),
    device_id VARCHAR(100)
);

-- Índice
CREATE INDEX IF NOT EXISTS idx_sync_log_table ON sync_log(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_sync_log_date ON sync_log(synced_at);

-- =====================================================
-- VISTAS ÚTILES
-- =====================================================

-- Vista: Productos con stock bajo
CREATE OR REPLACE VIEW v_low_stock_products AS
SELECT 
    id,
    code,
    name,
    stock,
    min_stock,
    unit,
    (min_stock - stock) AS units_needed
FROM products
WHERE stock <= min_stock AND is_active = TRUE;

-- Vista: Clientes con deuda
CREATE OR REPLACE VIEW v_customers_with_debt AS
SELECT 
    id,
    name,
    trade_name,
    document_number,
    current_balance,
    credit_limit,
    (credit_limit - current_balance) AS available_credit
FROM customers
WHERE current_balance > 0 AND is_active = TRUE
ORDER BY current_balance DESC;

-- Vista: Cotizaciones pendientes
CREATE OR REPLACE VIEW v_pending_quotations AS
SELECT 
    q.*,
    c.name AS customer_full_name,
    c.phone AS customer_phone,
    c.email AS customer_email,
    (q.valid_until < CURRENT_DATE) AS is_expired
FROM quotations q
LEFT JOIN customers c ON q.customer_id = c.id
WHERE q.status IN ('Borrador', 'Enviada')
ORDER BY q.valid_until ASC;

-- Vista: Facturas vencidas
CREATE OR REPLACE VIEW v_overdue_invoices AS
SELECT 
    i.*,
    c.name AS customer_full_name,
    c.phone AS customer_phone,
    (CURRENT_DATE - i.due_date) AS days_overdue
FROM invoices i
LEFT JOIN customers c ON i.customer_id = c.id
WHERE i.due_date < CURRENT_DATE 
  AND i.status NOT IN ('paid', 'cancelled')
ORDER BY i.due_date ASC;

-- Vista: Resumen de ventas del mes
CREATE OR REPLACE VIEW v_monthly_sales_summary AS
SELECT 
    DATE_TRUNC('month', issue_date) AS month,
    COUNT(*) AS total_invoices,
    SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) AS paid_count,
    SUM(total) AS total_amount,
    SUM(paid_amount) AS paid_amount,
    SUM(total - paid_amount) AS pending_amount
FROM invoices
WHERE type = 'invoice' AND status != 'cancelled'
GROUP BY DATE_TRUNC('month', issue_date)
ORDER BY month DESC;

-- =====================================================
-- FUNCIONES Y TRIGGERS
-- =====================================================

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a tablas principales
CREATE TRIGGER update_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_quotations_updated_at
    BEFORE UPDATE ON quotations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_invoices_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_material_prices_updated_at
    BEFORE UPDATE ON material_prices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Función para generar número de cotización
CREATE OR REPLACE FUNCTION generate_quotation_number()
RETURNS TEXT AS $$
DECLARE
    year_part TEXT;
    seq_num INTEGER;
    new_number TEXT;
BEGIN
    year_part := TO_CHAR(CURRENT_DATE, 'YYYY');
    
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(number FROM 10 FOR 4) AS INTEGER)
    ), 0) + 1 INTO seq_num
    FROM quotations
    WHERE number LIKE 'COT-' || year_part || '-%';
    
    new_number := 'COT-' || year_part || '-' || LPAD(seq_num::TEXT, 4, '0');
    RETURN new_number;
END;
$$ LANGUAGE plpgsql;

-- Función para generar número de factura
CREATE OR REPLACE FUNCTION generate_invoice_number(p_series TEXT)
RETURNS TEXT AS $$
DECLARE
    seq_num INTEGER;
BEGIN
    SELECT COALESCE(MAX(CAST(number AS INTEGER)), 0) + 1 INTO seq_num
    FROM invoices
    WHERE series = p_series;
    
    RETURN LPAD(seq_num::TEXT, 8, '0');
END;
$$ LANGUAGE plpgsql;

-- Función para recalcular totales de cotización
CREATE OR REPLACE FUNCTION recalculate_quotation_totals(p_quotation_id UUID)
RETURNS VOID AS $$
DECLARE
    v_materials_cost DECIMAL(12,2);
    v_total_weight DECIMAL(12,3);
    v_subtotal DECIMAL(12,2);
    v_profit_amount DECIMAL(12,2);
    v_total DECIMAL(12,2);
    v_profit_margin DECIMAL(5,2);
    v_labor_cost DECIMAL(12,2);
    v_energy_cost DECIMAL(12,2);
    v_gas_cost DECIMAL(12,2);
    v_supplies_cost DECIMAL(12,2);
    v_other_costs DECIMAL(12,2);
BEGIN
    -- Obtener suma de items
    SELECT 
        COALESCE(SUM(total_price), 0),
        COALESCE(SUM(total_weight), 0)
    INTO v_materials_cost, v_total_weight
    FROM quotation_items
    WHERE quotation_id = p_quotation_id;
    
    -- Obtener otros valores de la cotización
    SELECT 
        profit_margin,
        labor_cost,
        energy_cost,
        gas_cost,
        supplies_cost,
        other_costs
    INTO v_profit_margin, v_labor_cost, v_energy_cost, v_gas_cost, v_supplies_cost, v_other_costs
    FROM quotations
    WHERE id = p_quotation_id;
    
    -- Calcular subtotal
    v_subtotal := v_materials_cost + v_labor_cost + v_energy_cost + v_gas_cost + v_supplies_cost + v_other_costs;
    
    -- Calcular ganancia
    v_profit_amount := v_subtotal * (v_profit_margin / 100);
    
    -- Calcular total
    v_total := v_subtotal + v_profit_amount;
    
    -- Actualizar cotización
    UPDATE quotations
    SET 
        materials_cost = v_materials_cost,
        total_weight = v_total_weight,
        subtotal = v_subtotal,
        profit_amount = v_profit_amount,
        total = v_total,
        updated_at = NOW()
    WHERE id = p_quotation_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger para recalcular cuando cambian items
CREATE OR REPLACE FUNCTION trigger_recalculate_quotation()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM recalculate_quotation_totals(OLD.quotation_id);
        RETURN OLD;
    ELSE
        PERFORM recalculate_quotation_totals(NEW.quotation_id);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER recalculate_quotation_on_item_change
    AFTER INSERT OR UPDATE OR DELETE ON quotation_items
    FOR EACH ROW EXECUTE FUNCTION trigger_recalculate_quotation();

-- =====================================================
-- DATOS INICIALES
-- =====================================================

-- Insertar configuración de empresa por defecto
INSERT INTO company_settings (name, trade_name, currency, tax_rate) 
VALUES ('Industrial de Molinos', 'Industrial de Molinos S.A.C.', 'PEN', 18.00)
ON CONFLICT DO NOTHING;

-- Insertar costos operativos por defecto
INSERT INTO operational_costs (labor_rate_per_hour, energy_rate_per_kwh, gas_rate_per_m3, default_profit_margin)
VALUES (25.00, 0.50, 2.00, 20.00)
ON CONFLICT DO NOTHING;

-- Insertar categorías de productos
INSERT INTO categories (id, name, description) VALUES
    (uuid_generate_v4(), 'Molinos de Bolas', 'Molinos de bolas industriales'),
    (uuid_generate_v4(), 'Repuestos', 'Repuestos y partes de molinos'),
    (uuid_generate_v4(), 'Servicios', 'Servicios de mantenimiento y reparación'),
    (uuid_generate_v4(), 'Materiales', 'Materiales para fabricación')
ON CONFLICT DO NOTHING;

-- Insertar precios de materiales comunes
INSERT INTO material_prices (name, category, type, thickness, price_per_kg, density) VALUES
    ('Acero A36', 'lamina', 'A36', 0, 4.50, 7.85),
    ('Acero A36 - 6mm', 'lamina', 'A36', 6, 4.60, 7.85),
    ('Acero A36 - 9mm', 'lamina', 'A36', 9, 4.70, 7.85),
    ('Acero A36 - 12mm', 'lamina', 'A36', 12, 4.80, 7.85),
    ('Acero A36 - 19mm', 'lamina', 'A36', 19, 5.00, 7.85),
    ('Acero A36 - 25mm', 'lamina', 'A36', 25, 5.20, 7.85),
    ('Acero Inoxidable 304', 'lamina', 'INOX 304', 0, 12.00, 8.00),
    ('Acero Inoxidable 316', 'lamina', 'INOX 316', 0, 15.00, 8.00),
    ('Acero al Carbono para Tubos', 'tubo', 'Carbono', 0, 5.00, 7.85),
    ('Acero SAE 1045', 'eje', 'SAE 1045', 0, 6.50, 7.85),
    ('Acero SAE 4140', 'eje', 'SAE 4140', 0, 8.00, 7.85),
    ('Acero SAE 4340', 'eje', 'SAE 4340', 0, 10.00, 7.85),
    ('Fundición Gris', 'fundicion', 'Gris', 0, 3.50, 7.20),
    ('Fundición Nodular', 'fundicion', 'Nodular', 0, 4.50, 7.10),
    ('Bronce SAE 40', 'bronce', 'SAE 40', 0, 25.00, 8.80),
    ('Bronce SAE 64', 'bronce', 'SAE 64', 0, 28.00, 8.80)
ON CONFLICT DO NOTHING;

-- Insertar plan de cuentas básico
INSERT INTO chart_of_accounts (code, name, type, parent_code, level, accepts_entries) VALUES
    -- ACTIVOS
    ('1', 'ACTIVO', 'asset', NULL, 1, FALSE),
    ('10', 'EFECTIVO Y EQUIVALENTES', 'asset', '1', 2, FALSE),
    ('101', 'Caja', 'asset', '10', 3, TRUE),
    ('102', 'Bancos', 'asset', '10', 3, TRUE),
    ('12', 'CUENTAS POR COBRAR', 'asset', '1', 2, FALSE),
    ('121', 'Clientes', 'asset', '12', 3, TRUE),
    ('20', 'INVENTARIOS', 'asset', '1', 2, FALSE),
    ('201', 'Mercaderías', 'asset', '20', 3, TRUE),
    ('202', 'Materias Primas', 'asset', '20', 3, TRUE),
    ('33', 'ACTIVO FIJO', 'asset', '1', 2, FALSE),
    ('331', 'Maquinaria y Equipo', 'asset', '33', 3, TRUE),
    
    -- PASIVOS
    ('4', 'PASIVO', 'liability', NULL, 1, FALSE),
    ('40', 'TRIBUTOS POR PAGAR', 'liability', '4', 2, FALSE),
    ('401', 'IGV por Pagar', 'liability', '40', 3, TRUE),
    ('42', 'CUENTAS POR PAGAR', 'liability', '4', 2, FALSE),
    ('421', 'Proveedores', 'liability', '42', 3, TRUE),
    
    -- PATRIMONIO
    ('5', 'PATRIMONIO', 'equity', NULL, 1, FALSE),
    ('50', 'CAPITAL', 'equity', '5', 2, FALSE),
    ('501', 'Capital Social', 'equity', '50', 3, TRUE),
    ('59', 'RESULTADOS', 'equity', '5', 2, FALSE),
    ('591', 'Resultado del Ejercicio', 'equity', '59', 3, TRUE),
    
    -- INGRESOS
    ('7', 'INGRESOS', 'income', NULL, 1, FALSE),
    ('70', 'VENTAS', 'income', '7', 2, FALSE),
    ('701', 'Ventas de Productos', 'income', '70', 3, TRUE),
    ('702', 'Ventas de Servicios', 'income', '70', 3, TRUE),
    
    -- GASTOS
    ('6', 'GASTOS', 'expense', NULL, 1, FALSE),
    ('60', 'COSTO DE VENTAS', 'expense', '6', 2, FALSE),
    ('601', 'Costo de Productos Vendidos', 'expense', '60', 3, TRUE),
    ('62', 'GASTOS DE PERSONAL', 'expense', '6', 2, FALSE),
    ('621', 'Sueldos y Salarios', 'expense', '62', 3, TRUE),
    ('63', 'SERVICIOS', 'expense', '6', 2, FALSE),
    ('631', 'Energía Eléctrica', 'expense', '63', 3, TRUE),
    ('632', 'Gas', 'expense', '63', 3, TRUE),
    ('633', 'Agua', 'expense', '63', 3, TRUE)
ON CONFLICT (code) DO NOTHING;

-- Insertar plantillas de molinos frecuentes
INSERT INTO product_templates (name, description, category, default_components, estimated_weight, estimated_hours) VALUES
    ('Molino de Bolas 3x4 pies', 'Molino de bolas pequeño para laboratorio o pequeña producción', 'molino_bolas', 
     '[{"type": "cylinder", "name": "Cilindro principal", "diameter": 914, "length": 1219, "thickness": 12},
       {"type": "circular_plate", "name": "Tapa frontal", "diameter": 914, "thickness": 19, "quantity": 2},
       {"type": "shaft", "name": "Eje principal", "diameter": 100, "length": 1800}]'::jsonb,
     1500, 80),
    ('Molino de Bolas 4x6 pies', 'Molino de bolas mediano para producción industrial', 'molino_bolas',
     '[{"type": "cylinder", "name": "Cilindro principal", "diameter": 1219, "length": 1829, "thickness": 16},
       {"type": "circular_plate", "name": "Tapa frontal", "diameter": 1219, "thickness": 25, "quantity": 2},
       {"type": "shaft", "name": "Eje principal", "diameter": 150, "length": 2500}]'::jsonb,
     3000, 120),
    ('Molino de Bolas 5x8 pies', 'Molino de bolas grande para alta producción', 'molino_bolas',
     '[{"type": "cylinder", "name": "Cilindro principal", "diameter": 1524, "length": 2438, "thickness": 19},
       {"type": "circular_plate", "name": "Tapa frontal", "diameter": 1524, "thickness": 32, "quantity": 2},
       {"type": "shaft", "name": "Eje principal", "diameter": 200, "length": 3200}]'::jsonb,
     5500, 200),
    ('Molino de Bolas 6x10 pies', 'Molino de bolas industrial de alta capacidad', 'molino_bolas',
     '[{"type": "cylinder", "name": "Cilindro principal", "diameter": 1829, "length": 3048, "thickness": 25},
       {"type": "circular_plate", "name": "Tapa frontal", "diameter": 1829, "thickness": 38, "quantity": 2},
       {"type": "shaft", "name": "Eje principal", "diameter": 250, "length": 4000}]'::jsonb,
     8500, 300)
ON CONFLICT DO NOTHING;

-- =====================================================
-- POLÍTICAS DE SEGURIDAD (Row Level Security)
-- =====================================================

-- Habilitar RLS en todas las tablas
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE material_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE operational_costs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;

-- Políticas permisivas para desarrollo (ajustar para producción)
-- CATEGORIES
CREATE POLICY "Allow all for authenticated users" ON categories FOR ALL USING (true) WITH CHECK (true);

-- CHART_OF_ACCOUNTS
CREATE POLICY "Allow all for authenticated users" ON chart_of_accounts FOR ALL USING (true) WITH CHECK (true);

-- COMPANY_SETTINGS
CREATE POLICY "Allow all for authenticated users" ON company_settings FOR ALL USING (true) WITH CHECK (true);

-- CUSTOMERS
CREATE POLICY "Allow all for authenticated users" ON customers FOR ALL USING (true) WITH CHECK (true);

-- INVOICE_ITEMS
CREATE POLICY "Allow all for authenticated users" ON invoice_items FOR ALL USING (true) WITH CHECK (true);

-- INVOICES
CREATE POLICY "Allow all for authenticated users" ON invoices FOR ALL USING (true) WITH CHECK (true);

-- JOURNAL_ENTRIES
CREATE POLICY "Allow all for authenticated users" ON journal_entries FOR ALL USING (true) WITH CHECK (true);

-- JOURNAL_ENTRY_LINES
CREATE POLICY "Allow all for authenticated users" ON journal_entry_lines FOR ALL USING (true) WITH CHECK (true);

-- MATERIAL_PRICES
CREATE POLICY "Allow all for authenticated users" ON material_prices FOR ALL USING (true) WITH CHECK (true);

-- OPERATIONAL_COSTS
CREATE POLICY "Allow all for authenticated users" ON operational_costs FOR ALL USING (true) WITH CHECK (true);

-- PAYMENTS
CREATE POLICY "Allow all for authenticated users" ON payments FOR ALL USING (true) WITH CHECK (true);

-- PRODUCT_TEMPLATES
CREATE POLICY "Allow all for authenticated users" ON product_templates FOR ALL USING (true) WITH CHECK (true);

-- PRODUCTS
CREATE POLICY "Allow all for authenticated users" ON products FOR ALL USING (true) WITH CHECK (true);

-- QUOTATION_ITEMS
CREATE POLICY "Allow all for authenticated users" ON quotation_items FOR ALL USING (true) WITH CHECK (true);

-- QUOTATIONS
CREATE POLICY "Allow all for authenticated users" ON quotations FOR ALL USING (true) WITH CHECK (true);

-- STOCK_MOVEMENTS
CREATE POLICY "Allow all for authenticated users" ON stock_movements FOR ALL USING (true) WITH CHECK (true);

-- SYNC_LOG
CREATE POLICY "Allow all for authenticated users" ON sync_log FOR ALL USING (true) WITH CHECK (true);

-- =====================================================
-- COMENTARIOS FINALES
-- =====================================================

COMMENT ON TABLE quotations IS 'Cotizaciones de productos y servicios, especialmente molinos de bolas';
COMMENT ON TABLE quotation_items IS 'Componentes individuales de cada cotización con cálculo de peso y precio';
COMMENT ON TABLE material_prices IS 'Catálogo de precios de materiales por kg';
COMMENT ON TABLE product_templates IS 'Plantillas predefinidas para molinos y productos frecuentes';
COMMENT ON FUNCTION recalculate_quotation_totals IS 'Recalcula automáticamente los totales de una cotización cuando cambian sus items';

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================
