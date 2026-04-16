-- ============================================
-- MIGRACIÓN 045: Sistema de Órdenes de Compra
-- ============================================
-- Tablas:
--   1. supplier_materials: Relación proveedor↔material con precio de compra
--   2. purchase_orders: Órdenes de compra a proveedores
--   3. purchase_order_items: Ítems de cada orden

-- ============================================
-- 1. TABLA: supplier_materials (Precios de compra por proveedor)
-- ============================================
CREATE TABLE IF NOT EXISTS supplier_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id UUID NOT NULL REFERENCES proveedores(id) ON DELETE CASCADE,
  material_id UUID NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
  unit_price DECIMAL(12,2) NOT NULL DEFAULT 0,         -- Precio unitario de compra
  last_purchase_price DECIMAL(12,2),                     -- Último precio pagado
  last_purchase_date TIMESTAMPTZ,                        -- Fecha última compra
  min_order_quantity DECIMAL(12,2) DEFAULT 1,            -- Cantidad mínima de pedido
  lead_time_days INTEGER DEFAULT 0,                      -- Tiempo de entrega en días
  notes TEXT,
  is_preferred BOOLEAN DEFAULT false,                    -- Proveedor preferido para este material
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(supplier_id, material_id)
);

CREATE INDEX IF NOT EXISTS idx_supplier_materials_supplier ON supplier_materials(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_materials_material ON supplier_materials(material_id);

-- Trigger updated_at
CREATE OR REPLACE TRIGGER trg_supplier_materials_updated
  BEFORE UPDATE ON supplier_materials
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE supplier_materials ENABLE ROW LEVEL SECURITY;
CREATE POLICY "supplier_materials_all" ON supplier_materials FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE supplier_materials IS 'Relación proveedor↔material con precios de compra';

-- ============================================
-- 2. TABLA: purchase_orders (Órdenes de compra)
-- ============================================
CREATE TABLE IF NOT EXISTS purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number VARCHAR(20) NOT NULL UNIQUE,              -- Número de orden (OC-001, OC-002...)
  supplier_id UUID NOT NULL REFERENCES proveedores(id) ON DELETE RESTRICT,
  status VARCHAR(20) NOT NULL DEFAULT 'borrador'         -- borrador, enviada, parcial, recibida, cancelada
    CHECK (status IN ('borrador', 'enviada', 'parcial', 'recibida', 'cancelada')),
  payment_status VARCHAR(20) NOT NULL DEFAULT 'pendiente' -- pendiente, parcial, pagada
    CHECK (payment_status IN ('pendiente', 'parcial', 'pagada')),
  payment_method VARCHAR(20),                             -- efectivo, transferencia, credito
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(12,2) NOT NULL DEFAULT 0,            -- IVA u otros impuestos
  discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  total DECIMAL(12,2) NOT NULL DEFAULT 0,
  amount_paid DECIMAL(12,2) NOT NULL DEFAULT 0,           -- Lo que ya se pagó
  notes TEXT,
  expected_date DATE,                                     -- Fecha esperada de entrega
  received_date DATE,                                     -- Fecha real de recepción
  created_by VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier ON purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status ON purchase_orders(status);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_date ON purchase_orders(created_at DESC);

-- Trigger updated_at
CREATE OR REPLACE TRIGGER trg_purchase_orders_updated
  BEFORE UPDATE ON purchase_orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "purchase_orders_all" ON purchase_orders FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE purchase_orders IS 'Órdenes de compra a proveedores';

-- ============================================
-- 3. TABLA: purchase_order_items (Ítems de orden)
-- ============================================
CREATE TABLE IF NOT EXISTS purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  material_id UUID NOT NULL REFERENCES materials(id) ON DELETE RESTRICT,
  quantity DECIMAL(12,2) NOT NULL DEFAULT 1,
  unit VARCHAR(10) NOT NULL DEFAULT 'UND',
  unit_price DECIMAL(12,2) NOT NULL DEFAULT 0,           -- Precio unitario en esta orden
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,             -- quantity * unit_price
  quantity_received DECIMAL(12,2) NOT NULL DEFAULT 0,    -- Cantidad ya recibida
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_order ON purchase_order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_material ON purchase_order_items(material_id);

-- Trigger updated_at
CREATE OR REPLACE TRIGGER trg_purchase_order_items_updated
  BEFORE UPDATE ON purchase_order_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "purchase_order_items_all" ON purchase_order_items FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE purchase_order_items IS 'Ítems detallados de cada orden de compra';

-- ============================================
-- 4. FUNCIÓN: Generar número de orden secuencial
-- ============================================
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
  next_num INTEGER;
  result TEXT;
BEGIN
  SELECT COALESCE(MAX(
    CAST(REGEXP_REPLACE(order_number, '[^0-9]', '', 'g') AS INTEGER)
  ), 0) + 1
  INTO next_num
  FROM purchase_orders;
  
  result := 'OC-' || LPAD(next_num::TEXT, 4, '0');
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. FUNCIÓN: Recalcular totales de orden
-- ============================================
CREATE OR REPLACE FUNCTION recalc_purchase_order_total()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE purchase_orders
  SET subtotal = (
    SELECT COALESCE(SUM(subtotal), 0) FROM purchase_order_items WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
  ),
  total = (
    SELECT COALESCE(SUM(subtotal), 0) FROM purchase_order_items WHERE order_id = COALESCE(NEW.order_id, OLD.order_id)
  ) + tax_amount - discount_amount,
  updated_at = now()
  WHERE id = COALESCE(NEW.order_id, OLD.order_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_recalc_order_total
  AFTER INSERT OR UPDATE OR DELETE ON purchase_order_items
  FOR EACH ROW EXECUTE FUNCTION recalc_purchase_order_total();

-- ============================================
-- 6. FUNCIÓN: Al recibir orden, actualizar stock y precios
-- ============================================
CREATE OR REPLACE FUNCTION on_purchase_order_received()
RETURNS TRIGGER AS $$
BEGIN
  -- Solo cuando el status cambia a 'recibida'
  IF NEW.status = 'recibida' AND OLD.status != 'recibida' THEN
    -- Actualizar stock de cada material
    UPDATE materials m
    SET stock = m.stock + poi.quantity,
        cost_price = poi.unit_price,  -- Actualizar precio de costo
        updated_at = now()
    FROM purchase_order_items poi
    WHERE poi.order_id = NEW.id
      AND poi.material_id = m.id;
    
    -- Actualizar precios en supplier_materials
    INSERT INTO supplier_materials (supplier_id, material_id, unit_price, last_purchase_price, last_purchase_date, is_preferred)
    SELECT NEW.supplier_id, poi.material_id, poi.unit_price, poi.unit_price, now(), true
    FROM purchase_order_items poi
    WHERE poi.order_id = NEW.id
    ON CONFLICT (supplier_id, material_id) DO UPDATE SET
      last_purchase_price = EXCLUDED.last_purchase_price,
      last_purchase_date = now(),
      unit_price = EXCLUDED.unit_price,
      updated_at = now();
    
    -- Actualizar deuda del proveedor si no está pagada
    IF NEW.payment_status != 'pagada' THEN
      UPDATE proveedores
      SET current_debt = current_debt + (NEW.total - NEW.amount_paid),
          updated_at = now()
      WHERE id = NEW.supplier_id;
    END IF;
    
    -- Guardar fecha de recepción
    NEW.received_date := CURRENT_DATE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_purchase_order_received
  BEFORE UPDATE ON purchase_orders
  FOR EACH ROW EXECUTE FUNCTION on_purchase_order_received();
