-- Agregar columnas para asociar materiales y activos a etapas de producción
ALTER TABLE production_stages
    ADD COLUMN IF NOT EXISTS material_ids UUID[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS asset_ids UUID[] NOT NULL DEFAULT '{}';

-- Índices GIN para búsquedas eficientes en arrays
CREATE INDEX IF NOT EXISTS idx_production_stages_material_ids
    ON production_stages USING GIN (material_ids);
CREATE INDEX IF NOT EXISTS idx_production_stages_asset_ids
    ON production_stages USING GIN (asset_ids);
