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

-- Actualizar items existentes: calcular costo basado en el margen de la cotización
-- Fórmula: costo = venta / (1 + margen/100)
UPDATE quotation_items qi
SET 
    cost_per_kg = CASE 
        WHEN q.profit_margin > 0 THEN qi.price_per_kg / (1 + q.profit_margin / 100)
        ELSE qi.price_per_kg * 0.7 -- Default 30% margen si no hay margen definido
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
AND qi.cost_per_kg = 0;

-- Verificar los cambios
SELECT 
    qi.name,
    qi.price_per_kg as venta_kg,
    qi.cost_per_kg as costo_kg,
    qi.total_price as total_venta,
    qi.total_cost as total_costo,
    qi.total_price - qi.total_cost as ganancia,
    q.profit_margin as margen_cotizacion
FROM quotation_items qi
JOIN quotations q ON q.id = qi.quotation_id
ORDER BY q.created_at DESC
LIMIT 20;
