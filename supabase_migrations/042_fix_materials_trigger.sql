-- =====================================================
-- MIGRACIÓN 042: Corregir trigger dimensional residual
-- =====================================================
-- La migración 040 usó nombres incorrectos al eliminar
-- el trigger y función de cálculo dimensional.
-- Trigger real: trg_materials_calc_weight (no trg_calculate_weight_per_meter)
-- Función real: trg_calculate_weight_per_meter() (no calculate_weight_per_meter())
-- Esto causa: record "new" has no field "tracking_mode"
-- =====================================================

-- 1. Eliminar el trigger correcto
DROP TRIGGER IF EXISTS trg_materials_calc_weight ON materials;

-- 2. Eliminar la función correcta
DROP FUNCTION IF EXISTS trg_calculate_weight_per_meter() CASCADE;

-- 3. También limpiar columnas de quotation_items que quedaron de migración 037
ALTER TABLE quotation_items DROP COLUMN IF EXISTS cut_length;
ALTER TABLE quotation_items DROP COLUMN IF EXISTS cut_width;
ALTER TABLE quotation_items DROP COLUMN IF EXISTS tracking_mode;

-- Listo: el error "record new has no field tracking_mode" queda resuelto
