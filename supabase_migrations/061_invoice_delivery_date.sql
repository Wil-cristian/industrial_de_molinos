-- ============================================================
-- 061: Agregar columnas para entregas pendientes en facturas
-- delivery_date: Fecha de entrega pactada
-- sale_payment_type: Tipo de venta (cash, credit, advance)
-- material_cost_total: Costo total de materiales (IF NOT EXISTS)
-- material_cost_pending: Costo de materiales por comprar (IF NOT EXISTS)
-- ============================================================

-- Fecha de entrega pactada con el cliente
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS delivery_date DATE;

-- Tipo de venta para distinguir adelantos de contado/crédito
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS sale_payment_type TEXT DEFAULT 'cash';

-- Costo de materiales (pueden ya existir si se agregaron manualmente)
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS material_cost_total NUMERIC(12,2) DEFAULT 0;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS material_cost_pending NUMERIC(12,2) DEFAULT 0;

-- Índice para consultar entregas pendientes rápidamente
CREATE INDEX IF NOT EXISTS idx_invoices_delivery_pending
  ON invoices (delivery_date, status)
  WHERE sale_payment_type = 'advance' AND status IN ('partial', 'issued');

COMMENT ON COLUMN invoices.delivery_date IS 'Fecha pactada de entrega al cliente';
COMMENT ON COLUMN invoices.sale_payment_type IS 'Tipo de venta: cash, credit, advance';
COMMENT ON COLUMN invoices.material_cost_total IS 'Costo total estimado de materiales para fabricación';
COMMENT ON COLUMN invoices.material_cost_pending IS 'Costo de materiales que faltan por comprar';
