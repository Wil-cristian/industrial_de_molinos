-- =============================================
-- 063: Subcategorías de materiales
-- Agrega soporte para subcategorías dentro de cada categoría
-- Ejemplo: Categoría "Rodamientos" → Subcategorías "6313", "6205", "6308"
-- =============================================

-- Tabla de subcategorías de materiales
CREATE TABLE IF NOT EXISTS material_subcategories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL REFERENCES material_categories(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(category_id, slug)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_material_subcategories_category ON material_subcategories(category_id);
CREATE INDEX IF NOT EXISTS idx_material_subcategories_active ON material_subcategories(is_active);
CREATE INDEX IF NOT EXISTS idx_material_subcategories_slug ON material_subcategories(category_id, slug);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_material_subcategories_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_material_subcategories_updated ON material_subcategories;
CREATE TRIGGER trg_material_subcategories_updated
    BEFORE UPDATE ON material_subcategories
    FOR EACH ROW
    EXECUTE FUNCTION update_material_subcategories_timestamp();

-- Agregar columna subcategory_id a la tabla materials
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'materials' AND column_name = 'subcategory_id'
    ) THEN
        ALTER TABLE materials ADD COLUMN subcategory_id UUID REFERENCES material_subcategories(id) ON DELETE SET NULL;
        CREATE INDEX idx_materials_subcategory ON materials(subcategory_id);
    END IF;
END $$;

-- =============================================
-- RLS Policies
-- =============================================
ALTER TABLE material_subcategories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "material_subcategories_select" ON material_subcategories
    FOR SELECT USING (true);

CREATE POLICY "material_subcategories_insert" ON material_subcategories
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "material_subcategories_update" ON material_subcategories
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "material_subcategories_delete" ON material_subcategories
    FOR DELETE USING (auth.role() = 'authenticated');
