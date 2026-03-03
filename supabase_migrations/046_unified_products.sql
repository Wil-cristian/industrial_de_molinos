-- ============================================
-- MIGRACIÓN 046: Unificar Productos Compuestos
-- ============================================
-- Agrega columnas faltantes a products y product_components
-- para soportar el modelo unificado CompositeProduct

-- ============================================
-- 1. Columnas nuevas en products
-- ============================================
DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS labor_hours DECIMAL(8,2) DEFAULT 0;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS labor_rate DECIMAL(10,2) DEFAULT 0;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS indirect_costs DECIMAL(12,2) DEFAULT 0;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS profit_margin DECIMAL(5,2) DEFAULT 0;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS product_type VARCHAR(50);
EXCEPTION WHEN others THEN null;
END $$;

-- ============================================
-- 2. Columnas nuevas en product_components
-- ============================================
DO $$ BEGIN
    ALTER TABLE product_components ADD COLUMN IF NOT EXISTS shape VARCHAR(30);
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE product_components ADD COLUMN IF NOT EXISTS height DECIMAL(10,2);
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE product_components ADD COLUMN IF NOT EXISTS weight_per_unit DECIMAL(12,4) DEFAULT 0;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE product_components ADD COLUMN IF NOT EXISTS price_per_unit DECIMAL(12,2) DEFAULT 0;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE product_components ADD COLUMN IF NOT EXISTS material_code VARCHAR(50);
EXCEPTION WHEN others THEN null;
END $$;

-- ============================================
-- 3. Función para recalcular totales del producto compuesto
-- ============================================
CREATE OR REPLACE FUNCTION recalc_composite_product_totals(p_product_id UUID)
RETURNS VOID AS $$
DECLARE
    v_total_weight DECIMAL;
    v_materials_cost DECIMAL;
    v_labor_hours DECIMAL;
    v_labor_rate DECIMAL;
    v_indirect_costs DECIMAL;
    v_profit_margin DECIMAL;
    v_subtotal DECIMAL;
    v_total DECIMAL;
BEGIN
    -- Sumar pesos y costos de componentes
    SELECT 
        COALESCE(SUM(weight_per_unit * quantity), 0),
        COALESCE(SUM(price_per_unit * quantity), 0)
    INTO v_total_weight, v_materials_cost
    FROM product_components
    WHERE product_id = p_product_id;

    -- Obtener costos adicionales del producto
    SELECT 
        COALESCE(labor_hours, 0),
        COALESCE(labor_rate, 0),
        COALESCE(indirect_costs, 0),
        COALESCE(profit_margin, 0)
    INTO v_labor_hours, v_labor_rate, v_indirect_costs, v_profit_margin
    FROM products
    WHERE id = p_product_id;

    v_subtotal := v_materials_cost + (v_labor_hours * v_labor_rate) + v_indirect_costs;
    v_total := v_subtotal + (v_subtotal * v_profit_margin / 100);

    -- Actualizar producto
    UPDATE products
    SET total_weight = v_total_weight,
        total_cost = v_materials_cost,
        unit_price = v_total,
        cost_price = v_subtotal,
        updated_at = NOW()
    WHERE id = p_product_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON COLUMN products.labor_hours IS 'Horas de mano de obra para producto compuesto';
COMMENT ON COLUMN products.labor_rate IS 'Tarifa por hora de mano de obra';
COMMENT ON COLUMN products.indirect_costs IS 'Costos indirectos del producto compuesto';
COMMENT ON COLUMN products.profit_margin IS 'Margen de ganancia (%)';
COMMENT ON COLUMN products.product_type IS 'Tipo de producto: molino, transportador, tanque, etc.';
