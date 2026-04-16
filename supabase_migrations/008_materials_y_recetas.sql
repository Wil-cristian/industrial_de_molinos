-- =====================================================
-- MATERIALES (Inventario) Y RECETAS (Productos)
-- Industrial de Molinos
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- MODELO SIMPLE:
-- 
-- materials (inventario)     = Materia prima con stock real
--                              (tubería, tornillos, rodamientos, etc.)
-- 
-- products (recetas)         = Productos terminados/plantillas
--                              (Molino 44", Molino 36")
-- 
-- product_components         = Items de cada receta
--                              (Molino 44" usa: 150kg tubo + 48 tornillos...)
-- =====================================================

-- =====================================================
-- 1. TABLA DE MATERIALES (Inventario/Materia Prima)
-- =====================================================
CREATE TABLE IF NOT EXISTS materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Clasificación
    category VARCHAR(50) DEFAULT 'general',  -- tubo, lamina, eje, tornilleria, rodamiento, etc.
    shape VARCHAR(30) DEFAULT 'custom',      -- cylinder, plate, solid_cylinder, bearing, custom
    
    -- Precios
    price_per_kg DECIMAL(12,2) DEFAULT 0,    -- Para materiales por peso
    unit_price DECIMAL(12,2) DEFAULT 0,      -- Para materiales por unidad (rodamientos, tornillos)
    cost_price DECIMAL(12,2) DEFAULT 0,      -- Costo de compra
    
    -- Stock
    stock DECIMAL(12,2) DEFAULT 0,           -- Cantidad actual
    min_stock DECIMAL(12,2) DEFAULT 0,       -- Stock mínimo (alerta)
    unit VARCHAR(20) DEFAULT 'KG',           -- KG, UND, M, L, etc.
    
    -- Propiedades físicas (para cálculo de peso)
    density DECIMAL(8,2) DEFAULT 7850,       -- kg/m³ (acero = 7850)
    default_thickness DECIMAL(8,2),          -- Espesor por defecto (mm)
    fixed_weight DECIMAL(8,4),               -- Peso fijo por unidad (kg) - para rodamientos
    
    -- Metadata
    supplier VARCHAR(200),
    location VARCHAR(100),                   -- Ubicación en almacén
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_materials_code ON materials(code);
CREATE INDEX IF NOT EXISTS idx_materials_category ON materials(category);
CREATE INDEX IF NOT EXISTS idx_materials_active ON materials(is_active);

-- =====================================================
-- 2. ACTUALIZAR TABLA PRODUCTS (Para ser Recetas)
-- =====================================================
-- Agregar campos para que products sea una "receta"
DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS is_recipe BOOLEAN DEFAULT false;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS recipe_description TEXT;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS total_weight DECIMAL(12,2) DEFAULT 0;
EXCEPTION WHEN others THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE products ADD COLUMN IF NOT EXISTS total_cost DECIMAL(12,2) DEFAULT 0;
EXCEPTION WHEN others THEN null;
END $$;

-- =====================================================
-- 3. TABLA DE COMPONENTES DE RECETA (product_components)
-- =====================================================
CREATE TABLE IF NOT EXISTS product_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    material_id UUID REFERENCES materials(id) ON DELETE SET NULL,
    
    -- Información del componente
    name VARCHAR(200) NOT NULL,              -- Nombre (se copia del material o es manual)
    description TEXT,
    
    -- Cantidades
    quantity DECIMAL(12,4) NOT NULL DEFAULT 1,
    unit VARCHAR(20) DEFAULT 'KG',           -- KG, UND, M, etc.
    
    -- Dimensiones (para cálculo de peso en tubos/láminas)
    outer_diameter DECIMAL(10,2),            -- Diámetro exterior (mm)
    inner_diameter DECIMAL(10,2),            -- Diámetro interior (mm) - para tubos
    thickness DECIMAL(10,2),                 -- Espesor (mm)
    length DECIMAL(10,2),                    -- Largo (mm)
    width DECIMAL(10,2),                     -- Ancho (mm) - para láminas
    
    -- Peso calculado
    calculated_weight DECIMAL(12,4) DEFAULT 0,
    
    -- Costos
    unit_cost DECIMAL(12,2) DEFAULT 0,
    total_cost DECIMAL(12,2) DEFAULT 0,
    
    -- Orden
    sort_order INT DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_product_components_product ON product_components(product_id);
CREATE INDEX IF NOT EXISTS idx_product_components_material ON product_components(material_id);

-- =====================================================
-- 4. FUNCIÓN: CALCULAR TOTALES DE LA RECETA
-- =====================================================
CREATE OR REPLACE FUNCTION update_product_totals(p_product_id UUID)
RETURNS VOID AS $$
DECLARE
    v_total_weight DECIMAL;
    v_total_cost DECIMAL;
BEGIN
    SELECT 
        COALESCE(SUM(calculated_weight), 0),
        COALESCE(SUM(total_cost), 0)
    INTO v_total_weight, v_total_cost
    FROM product_components
    WHERE product_id = p_product_id;
    
    UPDATE products 
    SET total_weight = v_total_weight,
        total_cost = v_total_cost,
        updated_at = NOW()
    WHERE id = p_product_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. FUNCIÓN: VERIFICAR STOCK PARA UNA RECETA
-- =====================================================
CREATE OR REPLACE FUNCTION check_recipe_stock(p_product_id UUID, p_quantity INT DEFAULT 1)
RETURNS TABLE (
    component_name VARCHAR,
    material_code VARCHAR,
    required_qty DECIMAL,
    available_stock DECIMAL,
    unit VARCHAR,
    has_stock BOOLEAN,
    shortage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pc.name::VARCHAR,
        m.code::VARCHAR,
        (pc.quantity * p_quantity)::DECIMAL as required,
        COALESCE(m.stock, 0)::DECIMAL,
        pc.unit::VARCHAR,
        COALESCE(m.stock, 0) >= (pc.quantity * p_quantity),
        GREATEST(0, (pc.quantity * p_quantity) - COALESCE(m.stock, 0))::DECIMAL
    FROM product_components pc
    LEFT JOIN materials m ON m.id = pc.material_id
    WHERE pc.product_id = p_product_id
    ORDER BY pc.sort_order;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. FUNCIÓN: CARGAR RECETA A COTIZACIÓN
-- =====================================================
CREATE OR REPLACE FUNCTION add_recipe_to_quotation(
    p_quotation_id UUID,
    p_product_id UUID,
    p_quantity INT DEFAULT 1
)
RETURNS VOID AS $$
DECLARE
    v_component RECORD;
    v_sort INT;
BEGIN
    -- Obtener último sort_order
    SELECT COALESCE(MAX(sort_order), 0) INTO v_sort 
    FROM quotation_items WHERE quotation_id = p_quotation_id;
    
    -- Insertar cada componente
    FOR v_component IN 
        SELECT pc.*, m.code as material_code, m.price_per_kg
        FROM product_components pc
        LEFT JOIN materials m ON m.id = pc.material_id
        WHERE pc.product_id = p_product_id
        ORDER BY pc.sort_order
    LOOP
        v_sort := v_sort + 1;
        
        INSERT INTO quotation_items (
            quotation_id,
            material_id,
            material_name,
            name,
            description,
            quantity,
            unit_weight,
            price_per_kg,
            unit_price,
            total_price,
            sort_order
        ) VALUES (
            p_quotation_id,
            v_component.material_id,
            v_component.material_code,
            v_component.name,
            v_component.description,
            v_component.quantity * p_quantity,
            v_component.calculated_weight,
            COALESCE(v_component.price_per_kg, 0),
            v_component.unit_cost,
            v_component.total_cost * p_quantity,
            v_sort
        );
    END LOOP;
    
    -- Recalcular total de cotización
    UPDATE quotations q
    SET subtotal = (SELECT COALESCE(SUM(total_price), 0) FROM quotation_items WHERE quotation_id = q.id),
        total = (SELECT COALESCE(SUM(total_price), 0) FROM quotation_items WHERE quotation_id = q.id),
        updated_at = NOW()
    WHERE q.id = p_quotation_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. PERMISOS
-- =====================================================
GRANT ALL ON materials TO anon, authenticated, service_role;
GRANT ALL ON product_components TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_product_totals TO anon, authenticated;
GRANT EXECUTE ON FUNCTION check_recipe_stock TO anon, authenticated;
GRANT EXECUTE ON FUNCTION add_recipe_to_quotation TO anon, authenticated;

-- =====================================================
-- 8. DATOS DE EJEMPLO - MATERIALES DE INVENTARIO
-- =====================================================
INSERT INTO materials (code, name, category, shape, unit, price_per_kg, unit_price, density, stock, min_stock, default_thickness)
VALUES 
    -- Tubos
    ('TUB-A36-001', 'Tubo Acero A36', 'tubo', 'cylinder', 'KG', 5.00, 0, 7850, 1500, 200, 12),
    ('TUB-INOX-304', 'Tubo Acero Inoxidable 304', 'tubo', 'cylinder', 'KG', 12.00, 0, 8000, 800, 100, NULL),
    
    -- Láminas
    ('LAM-A36-3MM', 'Lámina Acero A36 3mm', 'lamina', 'plate', 'KG', 4.50, 0, 7850, 2500, 500, 3),
    ('LAM-A36-6MM', 'Lámina Acero A36 6mm', 'lamina', 'plate', 'KG', 4.50, 0, 7850, 1800, 400, 6),
    ('LAM-A36-12MM', 'Lámina Acero A36 12mm', 'lamina', 'plate', 'KG', 4.50, 0, 7850, 1200, 300, 12),
    ('LAM-INOX-304-2MM', 'Lámina Inoxidable 304 2mm', 'lamina', 'plate', 'KG', 12.00, 0, 8000, 600, 100, 2),
    
    -- Ejes
    ('EJE-SAE1045', 'Eje SAE 1045', 'eje', 'solid_cylinder', 'KG', 6.50, 0, 7850, 450, 100, NULL),
    ('EJE-SAE4140', 'Eje SAE 4140', 'eje', 'solid_cylinder', 'KG', 8.00, 0, 7850, 280, 50, NULL),
    
    -- Rodamientos (precio por unidad)
    ('ROD-6310', 'Rodamiento SKF 6310', 'rodamiento', 'bearing', 'UND', 0, 85.00, 7800, 20, 5, NULL),
    ('ROD-6312', 'Rodamiento SKF 6312', 'rodamiento', 'bearing', 'UND', 0, 120.00, 7800, 15, 4, NULL),
    ('ROD-6314', 'Rodamiento SKF 6314', 'rodamiento', 'bearing', 'UND', 0, 180.00, 7800, 10, 3, NULL),
    
    -- Tornillería (precio por unidad)
    ('TORN-HEX-1/2', 'Tornillo Hex 1/2" x 2"', 'tornilleria', 'custom', 'UND', 0, 0.80, 7850, 1000, 200, NULL),
    ('TORN-HEX-5/8', 'Tornillo Hex 5/8" x 3"', 'tornilleria', 'custom', 'UND', 0, 1.20, 7850, 800, 150, NULL),
    ('TORN-HEX-3/4', 'Tornillo Hex 3/4" x 4"', 'tornilleria', 'custom', 'UND', 0, 2.50, 7850, 500, 100, NULL),
    ('TUERCA-1/2', 'Tuerca Hex 1/2"', 'tornilleria', 'custom', 'UND', 0, 0.30, 7850, 1000, 200, NULL),
    ('TUERCA-5/8', 'Tuerca Hex 5/8"', 'tornilleria', 'custom', 'UND', 0, 0.50, 7850, 800, 150, NULL),
    
    -- Soldadura y consumibles
    ('SOLD-7018', 'Electrodo E7018 3/32"', 'consumible', 'custom', 'KG', 8.50, 0, 7850, 100, 20, NULL),
    ('SOLD-6011', 'Electrodo E6011 1/8"', 'consumible', 'custom', 'KG', 6.00, 0, 7850, 80, 15, NULL),
    
    -- Pintura
    ('PINT-EPOX-GRIS', 'Pintura Epóxica Gris', 'pintura', 'custom', 'L', 0, 45.00, 1200, 50, 10, NULL),
    ('PINT-ANTICORR', 'Anticorrosivo Rojo', 'pintura', 'custom', 'L', 0, 35.00, 1200, 40, 10, NULL)
ON CONFLICT (code) DO UPDATE SET 
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    price_per_kg = EXCLUDED.price_per_kg,
    unit_price = EXCLUDED.unit_price,
    stock = EXCLUDED.stock;

-- =====================================================
-- 9. DATOS DE EJEMPLO - RECETA MOLINO 44"
-- =====================================================
-- Crear el producto/receta
INSERT INTO products (code, name, description, is_recipe, recipe_description, unit_price, unit)
VALUES (
    'MOL-44',
    'Molino de Martillos 44"',
    'Molino de martillos industrial de 44 pulgadas',
    true,
    'Incluye: cilindro principal, tapas, eje de transmisión, base, rodamientos, tornillería completa y pintura de acabado',
    15000.00,
    'UND'
)
ON CONFLICT (code) DO UPDATE SET 
    is_recipe = true,
    recipe_description = EXCLUDED.recipe_description;

-- Insertar componentes de la receta
DO $$
DECLARE
    v_product_id UUID;
    v_mat_tubo UUID;
    v_mat_lamina UUID;
    v_mat_eje UUID;
    v_mat_rod UUID;
    v_mat_torn UUID;
    v_mat_sold UUID;
    v_mat_pint UUID;
BEGIN
    -- Obtener IDs
    SELECT id INTO v_product_id FROM products WHERE code = 'MOL-44';
    SELECT id INTO v_mat_tubo FROM materials WHERE code = 'TUB-A36-001';
    SELECT id INTO v_mat_lamina FROM materials WHERE code = 'LAM-A36-12MM';
    SELECT id INTO v_mat_eje FROM materials WHERE code = 'EJE-SAE4140';
    SELECT id INTO v_mat_rod FROM materials WHERE code = 'ROD-6310';
    SELECT id INTO v_mat_torn FROM materials WHERE code = 'TORN-HEX-5/8';
    SELECT id INTO v_mat_sold FROM materials WHERE code = 'SOLD-7018';
    SELECT id INTO v_mat_pint FROM materials WHERE code = 'PINT-EPOX-GRIS';
    
    IF v_product_id IS NOT NULL THEN
        -- Limpiar componentes existentes
        DELETE FROM product_components WHERE product_id = v_product_id;
        
        -- Componentes del Molino 44"
        INSERT INTO product_components (product_id, material_id, name, description, quantity, unit, outer_diameter, thickness, length, calculated_weight, unit_cost, total_cost, sort_order)
        VALUES 
            -- Cilindro principal (tubo): Ø508mm × 12mm × 1000mm ≈ 150 kg
            (v_product_id, v_mat_tubo, 'Cilindro Principal', 'Tubo Ø508mm × 12mm × 1000mm', 150.00, 'KG', 508, 12, 1000, 150.00, 5.00, 750.00, 1),
            
            -- Tapas (lámina): 2 tapas Ø508mm × 12mm ≈ 37 kg cada una
            (v_product_id, v_mat_lamina, 'Tapa Frontal', 'Lámina Ø508mm × 12mm', 37.00, 'KG', 508, 12, NULL, 37.00, 4.50, 166.50, 2),
            (v_product_id, v_mat_lamina, 'Tapa Posterior', 'Lámina Ø508mm × 12mm', 37.00, 'KG', 508, 12, NULL, 37.00, 4.50, 166.50, 3),
            
            -- Eje de transmisión: Ø100mm × 1200mm ≈ 74 kg
            (v_product_id, v_mat_eje, 'Eje de Transmisión', 'Eje SAE 4140 Ø100mm × 1200mm', 74.00, 'KG', 100, NULL, 1200, 74.00, 8.00, 592.00, 4),
            
            -- Base metálica (lámina): 1500×800×10mm ≈ 94 kg
            (v_product_id, v_mat_lamina, 'Base Metálica', 'Lámina 1500×800×10mm', 94.00, 'KG', NULL, 10, 1500, 94.00, 4.50, 423.00, 5),
            
            -- Rodamientos: 2 unidades
            (v_product_id, v_mat_rod, 'Rodamientos', 'SKF 6310 × 2 unidades', 2.00, 'UND', NULL, NULL, NULL, 2.40, 85.00, 170.00, 6),
            
            -- Tornillería: 48 tornillos
            (v_product_id, v_mat_torn, 'Tornillería', 'Tornillos 5/8" × 48 unidades', 48.00, 'UND', NULL, NULL, NULL, 3.60, 1.20, 57.60, 7),
            
            -- Soldadura: 15 kg
            (v_product_id, v_mat_sold, 'Soldadura', 'Electrodo E7018 para estructura', 15.00, 'KG', NULL, NULL, NULL, 15.00, 8.50, 127.50, 8),
            
            -- Pintura: 8 litros
            (v_product_id, v_mat_pint, 'Pintura Acabado', 'Epóxica Gris - 8 litros', 8.00, 'L', NULL, NULL, NULL, 9.60, 45.00, 360.00, 9);
        
        -- Actualizar totales del producto
        PERFORM update_product_totals(v_product_id);
    END IF;
END $$;

-- Reload schema
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- 10. VERIFICACIÓN
-- =====================================================
SELECT '✅ Materiales y Recetas configurado!' as resultado;

SELECT '--- MATERIALES EN INVENTARIO ---' as info;
SELECT code, name, category, stock, unit, 
       CASE WHEN unit_price > 0 THEN unit_price ELSE price_per_kg END as precio
FROM materials 
ORDER BY category, code;

SELECT '--- RECETAS/PRODUCTOS ---' as info;
SELECT code, name, is_recipe, total_weight, total_cost, unit_price 
FROM products 
WHERE is_recipe = true;

SELECT '--- COMPONENTES MOLINO 44" ---' as info;
SELECT pc.sort_order, pc.name, pc.quantity, pc.unit, pc.calculated_weight as peso_kg, pc.total_cost
FROM product_components pc
JOIN products p ON p.id = pc.product_id
WHERE p.code = 'MOL-44'
ORDER BY pc.sort_order;
