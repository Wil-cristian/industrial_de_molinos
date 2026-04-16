-- =====================================================
-- FIX: RLS en material_price_history
-- =====================================================
-- PROBLEMA: Al actualizar precio de un material, el trigger 
-- log_material_price_change() intenta insertar en material_price_history
-- pero RLS bloquea la inserción (code: 42501 Forbidden).
--
-- SOLUCIÓN: Hacer la función SECURITY DEFINER para que el trigger
-- ejecute con permisos del owner (bypassing RLS).
-- =====================================================

-- Recrear la función con SECURITY DEFINER
CREATE OR REPLACE FUNCTION log_material_price_change()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF OLD.price_per_kg IS DISTINCT FROM NEW.price_per_kg 
       OR OLD.cost_price IS DISTINCT FROM NEW.cost_price THEN
        INSERT INTO material_price_history (material_id, old_price, new_price, old_cost, new_cost)
        VALUES (NEW.id, OLD.price_per_kg, NEW.price_per_kg, OLD.cost_price, NEW.cost_price);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- El trigger ya existe, no hay que recrearlo (usa la misma función)

-- Verificar
DO $$
BEGIN
    RAISE NOTICE '✅ Función log_material_price_change ahora es SECURITY DEFINER';
    RAISE NOTICE '   → Los cambios de precio se guardarán en material_price_history sin error RLS';
END $$;
