-- =====================================================
-- AGREGAR COLUMNAS DE COSTO A QUOTATION_ITEMS
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- Agregar columna de costo por kg
ALTER TABLE quotation_items 
ADD COLUMN IF NOT EXISTS cost_per_kg DECIMAL(12,2) DEFAULT 0;

-- Agregar columna de costo unitario (para productos)
ALTER TABLE quotation_items 
ADD COLUMN IF NOT EXISTS unit_cost DECIMAL(12,2) DEFAULT 0;

-- Agregar columna de costo total
ALTER TABLE quotation_items 
ADD COLUMN IF NOT EXISTS total_cost DECIMAL(12,2) DEFAULT 0;

-- Comentarios descriptivos
COMMENT ON COLUMN quotation_items.cost_per_kg IS 'Precio de compra por kg del material';
COMMENT ON COLUMN quotation_items.unit_cost IS 'Costo unitario para productos';
COMMENT ON COLUMN quotation_items.total_cost IS 'Costo total del item';

-- PRIMERO: Actualizar items que tienen material vinculado (usar precio real del material)
UPDATE quotation_items qi
SET 
    cost_per_kg = COALESCE(m.cost_price, m.price_per_kg, 0),
    total_cost = qi.total_weight * COALESCE(m.cost_price, m.price_per_kg, 0)
FROM materials m
WHERE qi.inv_material_id = m.id
AND (qi.cost_per_kg = 0 OR qi.cost_per_kg IS NULL);

-- SEGUNDO: Para items sin material vinculado, estimar con el margen
UPDATE quotation_items qi
SET 
    cost_per_kg = CASE 
        WHEN q.profit_margin > 0 THEN qi.price_per_kg / (1 + q.profit_margin / 100)
        ELSE qi.price_per_kg * 0.7
    END,
    unit_cost = CASE 
        WHEN q.profit_margin > 0 THEN qi.unit_price / (1 + q.profit_margin / 100)
        ELSE qi.unit_price * 0.7
    END,
    total_cost = CASE 
        WHEN q.profit_margin > 0 THEN qi.total_price / (1 + q.profit_margin / 100)
        ELSE qi.total_price * 0.7
    END
FROM quotations q
WHERE qi.quotation_id = q.id
AND qi.inv_material_id IS NULL
AND (qi.cost_per_kg = 0 OR qi.cost_per_kg IS NULL);

-- Verificar los cambios
SELECT 
    qi.name,
    qi.inv_material_id,
    m.name as material_name,
    m.cost_price as material_cost_real,
    qi.price_per_kg as venta_kg,
    qi.cost_per_kg as costo_kg,
    qi.total_price as total_venta,
    qi.total_cost as total_costo,
    qi.total_price - qi.total_cost as ganancia
FROM quotation_items qi
LEFT JOIN materials m ON m.id = qi.inv_material_id
JOIN quotations q ON q.id = qi.quotation_id
ORDER BY q.created_at DESC
LIMIT 20;
