-- =============================================
-- 040: Tabla de categorías de materiales
-- Permite al usuario crear categorías personalizadas
-- =============================================

-- Tabla para almacenar categorías de materiales
CREATE TABLE IF NOT EXISTS material_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,              -- Nombre para mostrar (ej: "Tubos")
    slug VARCHAR(50) UNIQUE NOT NULL,        -- Clave interna (ej: "tubo")
    description TEXT,                        -- Descripción opcional
    default_unit VARCHAR(20) DEFAULT 'KG',   -- Unidad por defecto: KG, UND, M, L
    color VARCHAR(7) DEFAULT '#607D8B',      -- Color hex para identif. visual
    icon_name VARCHAR(50) DEFAULT 'category',-- Nombre del ícono Material Icons
    has_dimensions BOOLEAN DEFAULT false,    -- Si los materiales tienen dimensiones
    dimension_type VARCHAR(30),              -- cylinder, plate, solid_cylinder, etc.
    is_system BOOLEAN DEFAULT false,         -- Categorías del sistema (no se pueden eliminar)
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_material_categories_slug ON material_categories(slug);
CREATE INDEX IF NOT EXISTS idx_material_categories_active ON material_categories(is_active);
CREATE INDEX IF NOT EXISTS idx_material_categories_sort ON material_categories(sort_order, name);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_material_categories_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_material_categories_updated ON material_categories;
CREATE TRIGGER trg_material_categories_updated
    BEFORE UPDATE ON material_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_material_categories_timestamp();

-- =============================================
-- Insertar categorías predefinidas del sistema
-- =============================================
INSERT INTO material_categories (name, slug, description, default_unit, color, icon_name, has_dimensions, dimension_type, is_system, sort_order)
VALUES
    ('General',     'general',     'Materiales generales',                         'KG',  '#607D8B', 'category',            false, NULL,             true, 0),
    ('Tubos',       'tubo',        'Tubos y cilindros huecos',                     'KG',  '#2196F3', 'circle_outlined',     true,  'cylinder',       true, 1),
    ('Láminas',     'lamina',      'Láminas, placas y chapas metálicas',           'KG',  '#4CAF50', 'crop_square',         true,  'plate',          true, 2),
    ('Ejes',        'eje',         'Ejes sólidos y barras cilíndricas',            'KG',  '#9C27B0', 'minimize',            true,  'solid_cylinder', true, 3),
    ('Rodamientos', 'rodamiento',  'Rodamientos, cojinetes y bujes',               'UND', '#FF9800', 'settings',            false, NULL,             true, 4),
    ('Tornillería', 'tornilleria', 'Tornillos, tuercas, arandelas y pernos',       'UND', '#009688', 'build',               false, NULL,             true, 5),
    ('Consumibles', 'consumible',  'Materiales consumibles varios',                'UND', '#795548', 'local_fire_department',false, NULL,             true, 6),
    ('Soldadura',   'soldadura',   'Electrodos, alambre MIG y materiales de soldar','KG', '#F44336', 'flash_on',            false, NULL,             true, 7),
    ('Pintura',     'pintura',     'Pinturas, esmaltes y recubrimientos',           'L',  '#E91E63', 'format_paint',        false, NULL,             true, 8),
    ('Perfiles',    'perfil',      'Perfiles metálicos (ángulo, canal, etc.)',      'KG',  '#3F51B5', 'view_column',         true,  'cylinder',       true, 9)
ON CONFLICT (slug) DO NOTHING;

-- =============================================
-- RLS Policies
-- =============================================
ALTER TABLE material_categories ENABLE ROW LEVEL SECURITY;

-- Política de lectura: todos los usuarios autenticados
CREATE POLICY "material_categories_select" ON material_categories
    FOR SELECT USING (true);

-- Política de insercion: usuarios autenticados
CREATE POLICY "material_categories_insert" ON material_categories
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Política de actualización: usuarios autenticados
CREATE POLICY "material_categories_update" ON material_categories
    FOR UPDATE USING (auth.role() = 'authenticated');

-- Política de eliminación: solo categorías no del sistema
CREATE POLICY "material_categories_delete" ON material_categories
    FOR DELETE USING (auth.role() = 'authenticated' AND is_system = false);
