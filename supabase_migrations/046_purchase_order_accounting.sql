-- ============================================
-- MIGRACIÓN 046: Contabilidad de Órdenes de Compra
-- ============================================
-- Fixes:
--   1. Al cancelar orden recibida → revertir deuda del proveedor
--   2. Al registrar pago → reducir deuda del proveedor
--   3. Trigger contable para pagos de órdenes de compra

-- ============================================
-- 1. TRIGGER: Al cancelar una orden recibida, revertir deuda
-- ============================================
CREATE OR REPLACE FUNCTION on_purchase_order_cancelled()
RETURNS TRIGGER AS $$
BEGIN
  -- Cuando se cancela una orden que estaba recibida
  IF NEW.status = 'cancelada' AND OLD.status = 'recibida' THEN
    -- Revertir stock
    UPDATE materials m
    SET stock = GREATEST(m.stock - poi.quantity, 0),
        updated_at = now()
    FROM purchase_order_items poi
    WHERE poi.order_id = NEW.id
      AND poi.material_id = m.id;

    -- Revertir deuda del proveedor (lo que quedaba pendiente)
    IF OLD.payment_status != 'pagada' THEN
      UPDATE proveedores
      SET current_debt = GREATEST(current_debt - (OLD.total - OLD.amount_paid), 0),
          updated_at = now()
      WHERE id = NEW.supplier_id;
    END IF;
  END IF;

  -- Cuando se cancela una orden que NO estaba recibida (no afectó stock ni deuda)
  -- No hacer nada extra

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Reemplazar el trigger existente para incluir cancelación
DROP TRIGGER IF EXISTS trg_purchase_order_received ON purchase_orders;

CREATE OR REPLACE FUNCTION on_purchase_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- ── RECIBIDA ──
  IF NEW.status = 'recibida' AND OLD.status != 'recibida' THEN
    -- Actualizar stock de cada material
    UPDATE materials m
    SET stock = m.stock + poi.quantity,
        cost_price = poi.unit_price,
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

  -- ── CANCELADA ──
  IF NEW.status = 'cancelada' AND OLD.status != 'cancelada' THEN
    -- Si estaba recibida, revertir stock
    IF OLD.status = 'recibida' THEN
      UPDATE materials m
      SET stock = GREATEST(m.stock - poi.quantity, 0),
          updated_at = now()
      FROM purchase_order_items poi
      WHERE poi.order_id = NEW.id
        AND poi.material_id = m.id;
    END IF;

    -- Revertir deuda del proveedor si tenía deuda
    IF OLD.payment_status != 'pagada' AND OLD.status = 'recibida' THEN
      UPDATE proveedores
      SET current_debt = GREATEST(current_debt - (OLD.total - OLD.amount_paid), 0),
          updated_at = now()
      WHERE id = NEW.supplier_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_purchase_order_status_change
  BEFORE UPDATE ON purchase_orders
  FOR EACH ROW EXECUTE FUNCTION on_purchase_order_status_change();

-- ============================================
-- 2. FUNCIÓN: Al pagar orden, reducir deuda del proveedor
-- ============================================
CREATE OR REPLACE FUNCTION on_purchase_order_payment()
RETURNS TRIGGER AS $$
DECLARE
  v_payment_diff DECIMAL(12,2);
BEGIN
  -- Solo si cambió el amount_paid y la orden está recibida
  IF NEW.amount_paid != OLD.amount_paid AND OLD.status = 'recibida' THEN
    v_payment_diff := NEW.amount_paid - OLD.amount_paid;
    
    -- Reducir deuda del proveedor por la diferencia pagada
    IF v_payment_diff > 0 THEN
      UPDATE proveedores
      SET current_debt = GREATEST(current_debt - v_payment_diff, 0),
          updated_at = now()
      WHERE id = NEW.supplier_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_purchase_order_payment
  AFTER UPDATE ON purchase_orders
  FOR EACH ROW
  WHEN (NEW.amount_paid IS DISTINCT FROM OLD.amount_paid)
  EXECUTE FUNCTION on_purchase_order_payment();
