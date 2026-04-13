-- 089: Agregar teléfono del cliente a remisiones de envío
ALTER TABLE shipment_orders ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(50);
