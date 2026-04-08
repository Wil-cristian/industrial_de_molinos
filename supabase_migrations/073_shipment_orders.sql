-- ============================================================
-- 073: Sistema de Remisiones y Órdenes de Envío
-- Tablas: shipment_orders, shipment_order_items, shipment_order_sequence
-- Vinculación: production_orders.invoice_id
-- ============================================================

-- 1. Vincular OP con factura para rastrear entregas futuras
ALTER TABLE production_orders
    ADD COLUMN IF NOT EXISTS invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_production_orders_invoice ON production_orders(invoice_id);

-- 2. Tabla principal de remisiones / órdenes de envío
CREATE TABLE IF NOT EXISTS shipment_orders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(20) NOT NULL UNIQUE,
    invoice_id      UUID REFERENCES invoices(id) ON DELETE SET NULL,
    production_order_id UUID REFERENCES production_orders(id) ON DELETE SET NULL,
    customer_id     UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name   VARCHAR(200) NOT NULL,
    customer_address TEXT,

    -- Transporte
    carrier_name    VARCHAR(200),
    carrier_document VARCHAR(50),
    vehicle_plate   VARCHAR(20),
    driver_name     VARCHAR(200),
    driver_document VARCHAR(50),

    -- Fechas
    dispatch_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    delivery_date   DATE,
    delivered_at    TIMESTAMPTZ,

    -- Estado
    status          VARCHAR(20) NOT NULL DEFAULT 'borrador',

    -- Observaciones
    notes           TEXT,
    internal_notes  TEXT,

    -- Firmas
    prepared_by     VARCHAR(200),
    approved_by     VARCHAR(200),
    received_by     VARCHAR(200),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT shipment_orders_status_check
        CHECK (status IN ('borrador', 'despachada', 'en_transito', 'entregada', 'anulada'))
);

CREATE INDEX IF NOT EXISTS idx_shipment_orders_status ON shipment_orders(status);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_invoice ON shipment_orders(invoice_id);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_production ON shipment_orders(production_order_id);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_customer ON shipment_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_shipment_orders_dispatch ON shipment_orders(dispatch_date);

-- 3. Ítems de cada remisión
CREATE TABLE IF NOT EXISTS shipment_order_items (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_order_id   UUID NOT NULL REFERENCES shipment_orders(id) ON DELETE CASCADE,

    item_type           VARCHAR(20) NOT NULL DEFAULT 'producto',
    product_id          UUID REFERENCES products(id) ON DELETE SET NULL,
    material_id         UUID REFERENCES materials(id) ON DELETE SET NULL,

    description         VARCHAR(500) NOT NULL,
    code                VARCHAR(100),
    quantity            DECIMAL(12,3) NOT NULL DEFAULT 1,
    unit                VARCHAR(20) NOT NULL DEFAULT 'UND',
    weight_kg           DECIMAL(10,3),
    dimensions          VARCHAR(100),

    notes               TEXT,
    sequence_order      INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT shipment_items_type_check
        CHECK (item_type IN ('producto', 'material', 'pieza', 'herramienta', 'otro'))
);

CREATE INDEX IF NOT EXISTS idx_shipment_items_order ON shipment_order_items(shipment_order_id);
CREATE INDEX IF NOT EXISTS idx_shipment_items_product ON shipment_order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_shipment_items_material ON shipment_order_items(material_id);

-- 4. Consecutivo para código de remisión
CREATE TABLE IF NOT EXISTS shipment_order_sequence (
    id          INTEGER PRIMARY KEY DEFAULT 1,
    last_number INTEGER NOT NULL DEFAULT 0,
    prefix      VARCHAR(10) NOT NULL DEFAULT 'REM',
    CONSTRAINT shipment_sequence_single_row CHECK (id = 1)
);

INSERT INTO shipment_order_sequence (id, last_number, prefix)
VALUES (1, 0, 'REM')
ON CONFLICT (id) DO NOTHING;

-- Función para obtener siguiente número
CREATE OR REPLACE FUNCTION next_shipment_number()
RETURNS VARCHAR AS $$
DECLARE
    new_number INTEGER;
    prefix_val VARCHAR;
BEGIN
    UPDATE shipment_order_sequence
    SET last_number = last_number + 1
    WHERE id = 1
    RETURNING last_number, prefix INTO new_number, prefix_val;

    RETURN prefix_val || '-' || LPAD(new_number::TEXT, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger updated_at
DROP TRIGGER IF EXISTS trigger_update_shipment_orders_updated_at ON shipment_orders;
CREATE TRIGGER trigger_update_shipment_orders_updated_at
    BEFORE UPDATE ON shipment_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 6. RLS básico (authenticated full access)
ALTER TABLE shipment_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_order_sequence ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shipment_orders_all" ON shipment_orders
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "shipment_order_items_all" ON shipment_order_items
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "shipment_order_sequence_all" ON shipment_order_sequence
    FOR ALL TO authenticated USING (true) WITH CHECK (true);

COMMENT ON TABLE shipment_orders IS 'Remisiones / órdenes de envío';
COMMENT ON TABLE shipment_order_items IS 'Ítems de cada remisión';
COMMENT ON COLUMN shipment_orders.code IS 'Número consecutivo REM-XXXXX';
COMMENT ON COLUMN shipment_orders.status IS 'borrador, despachada, en_transito, entregada, anulada';
COMMENT ON COLUMN shipment_order_items.item_type IS 'producto, material, pieza, herramienta, otro';
