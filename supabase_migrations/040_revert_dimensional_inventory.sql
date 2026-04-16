-- =====================================================
-- MIGRACIÓN 040: Revertir Inventario Dimensional
-- =====================================================
-- Elimina todo el sistema de tracking por largo/área/retazos.
-- El inventario queda solo con control por peso (kg).
-- =====================================================

-- 1. Eliminar vista dimensional
DROP VIEW IF EXISTS v_dimensional_inventory CASCADE;

-- 2. Eliminar triggers dimensionales
DROP TRIGGER IF EXISTS trg_calculate_weight_per_meter ON materials;

-- 3. Eliminar funciones dimensionales
DROP FUNCTION IF EXISTS cut_material_by_length CASCADE;
DROP FUNCTION IF EXISTS cut_material_by_area CASCADE;
DROP FUNCTION IF EXISTS use_remnant CASCADE;
DROP FUNCTION IF EXISTS calculate_weight_per_meter CASCADE;

-- 4. Eliminar tabla de retazos
DROP TABLE IF EXISTS material_remnants CASCADE;

-- 5. Eliminar columnas dimensionales de materials
ALTER TABLE materials DROP COLUMN IF EXISTS stock_length;
ALTER TABLE materials DROP COLUMN IF EXISTS min_stock_length;
ALTER TABLE materials DROP COLUMN IF EXISTS stock_area;
ALTER TABLE materials DROP COLUMN IF EXISTS min_stock_area;
ALTER TABLE materials DROP COLUMN IF EXISTS weight_per_meter;
ALTER TABLE materials DROP COLUMN IF EXISTS tracking_mode;

-- 6. Eliminar columnas dimensionales de material_movements
ALTER TABLE material_movements DROP COLUMN IF EXISTS length_deducted;
ALTER TABLE material_movements DROP COLUMN IF EXISTS area_deducted;
ALTER TABLE material_movements DROP COLUMN IF EXISTS remnant_id;
ALTER TABLE material_movements DROP COLUMN IF EXISTS dimensions;

-- Listo: inventario vuelve a solo peso (kg)
