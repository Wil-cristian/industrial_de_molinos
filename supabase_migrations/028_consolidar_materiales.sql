-- =====================================================
-- MIGRACIÓN 028: Consolidar materiales e inventario
-- =====================================================
-- Problema: 'material_prices' (catálogo de precios) y 'materials' (inventario) coexisten.
--           'quotation_items.material_id' apunta a material_prices, 'inv_material_id' apunta a materials.
--           'stock_movements' (productos) y 'material_movements' (materiales) son paralelas.
-- Solución: Migrar data de material_prices a materials, unificar FK, deprecar tabla vieja.
-- =====================================================

-- 1. Migrar materiales de material_prices que no existan en materials
INSERT INTO materials (
    code, name, category, price_per_kg, density, unit, is_active,
    created_at, updated_at
)
SELECT
    'MP-' || LPAD(ROW_NUMBER() OVER (ORDER BY mp.created_at)::TEXT, 4, '0'),
    mp.name,
    mp.category,
    mp.price_per_kg,
    mp.density,
    COALESCE(mp.unit, 'kg'),
    COALESCE(mp.is_active, true),
    COALESCE(mp.created_at, NOW()),
    COALESCE(mp.updated_at, NOW())
FROM material_prices mp
WHERE NOT EXISTS (
    SELECT 1 FROM materials m
    WHERE LOWER(m.name) = LOWER(mp.name)
    AND LOWER(COALESCE(m.category, '')) = LOWER(COALESCE(mp.category, ''))
)
ON CONFLICT (code) DO NOTHING;

-- 2. Crear tabla de mapeo temporal old_id → new_id
CREATE TEMP TABLE material_id_mapping AS
SELECT
    mp.id AS old_id,
    m.id AS new_id
FROM material_prices mp
JOIN materials m ON LOWER(m.name) = LOWER(mp.name)
    AND LOWER(COALESCE(m.category, '')) = LOWER(COALESCE(mp.category, ''));

-- 3. Actualizar quotation_items: copiar material_id mapeado a inv_material_id donde falta
UPDATE quotation_items qi
SET inv_material_id = map.new_id
FROM material_id_mapping map
WHERE qi.material_id = map.old_id
AND qi.inv_material_id IS NULL;

-- 4. Ahora reapuntar material_id para que también use materials
-- Primero eliminar FK vieja
ALTER TABLE quotation_items DROP CONSTRAINT IF EXISTS quotation_items_material_id_fkey;
ALTER TABLE quotation_items DROP CONSTRAINT IF EXISTS fk_quotation_items_material;

-- Copiar inv_material_id a material_id donde hay mapeo
UPDATE quotation_items
SET material_id = inv_material_id
WHERE inv_material_id IS NOT NULL;

-- Agregar nueva FK a materials
ALTER TABLE quotation_items
    ADD CONSTRAINT fk_quotation_items_material
    FOREIGN KEY (material_id) REFERENCES materials(id)
    ON DELETE SET NULL;

-- 5. Eliminar columna redundante inv_material_id
ALTER TABLE quotation_items DROP COLUMN IF EXISTS inv_material_id;

-- 6. También actualizar invoice_items si tiene referencia a material_prices
ALTER TABLE invoice_items DROP CONSTRAINT IF EXISTS invoice_items_material_id_fkey;
ALTER TABLE invoice_items DROP CONSTRAINT IF EXISTS fk_invoice_items_material;

UPDATE invoice_items ii
SET material_id = map.new_id
FROM material_id_mapping map
WHERE ii.material_id = map.old_id;

ALTER TABLE invoice_items
    ADD CONSTRAINT fk_invoice_items_material
    FOREIGN KEY (material_id) REFERENCES materials(id)
    ON DELETE SET NULL;

-- 7. Renombrar material_prices → material_prices_deprecated
ALTER TABLE IF EXISTS material_prices RENAME TO material_prices_deprecated;
COMMENT ON TABLE material_prices_deprecated IS 'DEPRECADA: Usar tabla "materials" en su lugar. Mantenida temporalmente para referencia.';

-- 8. Crear vista compatible para código legacy
CREATE OR REPLACE VIEW material_prices AS
SELECT
    id,
    name,
    category,
    NULL::VARCHAR(50) AS type,
    default_thickness AS thickness,
    price_per_kg,
    density,
    unit,
    is_active,
    created_at,
    updated_at
FROM materials;

-- 9. Limpiar tabla temporal
DROP TABLE IF EXISTS material_id_mapping;

COMMENT ON VIEW material_prices IS 'Vista de compatibilidad — apunta a tabla materials';

-- NOTA: stock_movements y material_movements se mantienen separadas
-- porque rastrean entidades distintas (products vs materials).
-- Ambas son funcionales y tienen FK diferentes.
