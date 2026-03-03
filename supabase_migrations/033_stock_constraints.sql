-- =====================================================
-- MIGRACIÓN 033: Restricciones de Stock No Negativo
-- =====================================================
-- Problema: No hay protección a nivel DB contra stock negativo.
--           Cualquier UPDATE directo puede dejar stock < 0.
-- Solución: CHECK constraints + trigger de validación.
-- =====================================================

-- =====================================================
-- 1. CHECK CONSTRAINT en tabla products
-- =====================================================
DO $$
BEGIN
    -- Primero corregir datos existentes con stock negativo
    UPDATE products SET stock = 0 WHERE stock < 0;
    
    -- Agregar constraint si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'chk_products_stock_non_negative'
    ) THEN
        ALTER TABLE products 
        ADD CONSTRAINT chk_products_stock_non_negative 
        CHECK (stock >= 0);
    END IF;
END $$;

-- =====================================================
-- 2. CHECK CONSTRAINT en tabla materials
-- =====================================================
DO $$
BEGIN
    -- Corregir datos existentes
    UPDATE materials SET stock = 0 WHERE stock IS NOT NULL AND stock < 0;
    
    -- Agregar constraint si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints 
        WHERE constraint_name = 'chk_materials_stock_non_negative'
    ) THEN
        ALTER TABLE materials 
        ADD CONSTRAINT chk_materials_stock_non_negative 
        CHECK (stock >= 0 OR stock IS NULL);
    END IF;
END $$;

-- =====================================================
-- 3. Trigger para validar stock antes de descontar
-- =====================================================
-- Da un mensaje de error legible cuando se intenta llevar stock a negativo
CREATE OR REPLACE FUNCTION validate_stock_before_update()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'products' AND NEW.stock < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para producto "%". Stock actual: %, intento de establecer: %',
            COALESCE(NEW.name, NEW.id::TEXT), OLD.stock, NEW.stock;
    END IF;
    
    IF TG_TABLE_NAME = 'materials' AND NEW.stock IS NOT NULL AND NEW.stock < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente para material "%". Stock actual: %, intento de establecer: %',
            COALESCE(NEW.name, NEW.id::TEXT), COALESCE(OLD.stock, 0), NEW.stock;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger en products
DROP TRIGGER IF EXISTS trg_validate_product_stock ON products;
CREATE TRIGGER trg_validate_product_stock
    BEFORE UPDATE OF stock ON products
    FOR EACH ROW
    EXECUTE FUNCTION validate_stock_before_update();

-- Trigger en materials
DROP TRIGGER IF EXISTS trg_validate_material_stock ON materials;
CREATE TRIGGER trg_validate_material_stock
    BEFORE UPDATE OF stock ON materials
    FOR EACH ROW
    EXECUTE FUNCTION validate_stock_before_update();

-- =====================================================
-- 4. Actualizar deduct_inventory_item para mensaje claro
-- =====================================================
CREATE OR REPLACE FUNCTION deduct_inventory_item(
    p_product_id UUID,
    p_quantity DECIMAL(10,2)
) RETURNS BOOLEAN AS $$
DECLARE
    v_current_stock DECIMAL(10,2);
    v_product_name TEXT;
BEGIN
    SELECT stock, name INTO v_current_stock, v_product_name
    FROM products WHERE id = p_product_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto no encontrado: %', p_product_id;
    END IF;
    
    IF v_current_stock < p_quantity THEN
        RAISE EXCEPTION 'Stock insuficiente para "%" — disponible: %, solicitado: %',
            v_product_name, v_current_stock, p_quantity;
    END IF;
    
    UPDATE products 
    SET stock = stock - p_quantity, updated_at = NOW()
    WHERE id = p_product_id;
    
    -- Registrar movimiento
    INSERT INTO material_movements (
        material_id, product_id, movement_type, quantity,
        notes, created_at
    ) VALUES (
        NULL, p_product_id, 'salida', p_quantity,
        'Descuento automático por venta', NOW()
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. Permisos
-- =====================================================
GRANT EXECUTE ON FUNCTION validate_stock_before_update() TO authenticated;
GRANT EXECUTE ON FUNCTION deduct_inventory_item(UUID, DECIMAL) TO authenticated;
