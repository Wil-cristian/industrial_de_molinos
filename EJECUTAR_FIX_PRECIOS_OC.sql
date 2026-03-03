-- =====================================================
-- FIX: Corregir precios de órdenes de compra existentes
-- =====================================================
-- PROBLEMA: Las OC creadas automáticamente usaban 
-- supplier_materials.unit_price ($2,000 y $4,000) 
-- en vez de materials.cost_price ($0.50)
--
-- SOLUCIÓN: Actualizar los precios de TODOS los items
-- de OC en estado 'borrador' para usar materials.cost_price
-- =====================================================

-- 1. Actualizar unit_price de items usando materials.cost_price
UPDATE purchase_order_items poi
SET 
    unit_price = COALESCE(m.cost_price, poi.unit_price),
    subtotal = poi.quantity * COALESCE(m.cost_price, poi.unit_price)
FROM materials m
WHERE m.id = poi.material_id
AND m.cost_price > 0
AND EXISTS (
    SELECT 1 FROM purchase_orders po 
    WHERE po.id = poi.order_id 
    AND po.status = 'borrador'
);

-- 2. Recalcular subtotal y total de las órdenes afectadas
UPDATE purchase_orders po
SET 
    subtotal = sub.total_amount,
    total = sub.total_amount,
    updated_at = NOW()
FROM (
    SELECT order_id, SUM(subtotal) as total_amount
    FROM purchase_order_items
    GROUP BY order_id
) sub
WHERE po.id = sub.order_id
AND po.status = 'borrador';

-- 3. También corregir supplier_materials para futuras referencias
UPDATE supplier_materials sm
SET 
    unit_price = m.cost_price,
    updated_at = NOW()
FROM materials m
WHERE m.id = sm.material_id
AND m.cost_price > 0
AND sm.unit_price != m.cost_price;

-- Verificar
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM purchase_order_items poi
    JOIN purchase_orders po ON po.id = poi.order_id
    WHERE po.status = 'borrador';
    
    RAISE NOTICE '✅ Precios corregidos en % items de OC en borrador', v_count;
    RAISE NOTICE '   → Ahora usan materials.cost_price';
    RAISE NOTICE '   → supplier_materials también actualizado';
END $$;
