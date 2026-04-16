-- =====================================================
-- CREAR TABLA DE ACTIVOS FIJOS / INVERSIONES
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- Tabla principal de activos fijos
CREATE TABLE IF NOT EXISTS assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Categoría del activo
    category VARCHAR(50) NOT NULL DEFAULT 'otros',
    -- Categorías: maquinaria, herramientas, equipos, vehiculos, mobiliario, otros
    
    -- Fechas
    purchase_date DATE NOT NULL,
    warranty_expiry DATE,
    
    -- Valores
    purchase_price DECIMAL(12,2) NOT NULL,
    current_value DECIMAL(12,2) NOT NULL,
    depreciation_rate DECIMAL(5,2) DEFAULT 10.00, -- % anual
    
    -- Estado
    status VARCHAR(30) NOT NULL DEFAULT 'activo',
    -- Estados: activo, mantenimiento, baja, vendido
    
    -- Ubicación e identificación
    location VARCHAR(100),
    serial_number VARCHAR(100),
    brand VARCHAR(100),
    model VARCHAR(100),
    
    -- Proveedor
    supplier_id UUID REFERENCES proveedores(id) ON DELETE SET NULL,
    supplier_name VARCHAR(255),
    invoice_number VARCHAR(50),
    
    -- Responsable
    assigned_to VARCHAR(255),
    
    -- Imagen
    image_url TEXT,
    
    -- Notas
    notes TEXT,
    
    -- Auditoría
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT valid_asset_category CHECK (
        category IN ('maquinaria', 'herramientas', 'equipos', 'vehiculos', 'mobiliario', 'otros')
    ),
    CONSTRAINT valid_asset_status CHECK (
        status IN ('activo', 'mantenimiento', 'baja', 'vendido')
    )
);

-- Tabla de historial de mantenimiento
CREATE TABLE IF NOT EXISTS asset_maintenance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_id UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    
    maintenance_date DATE NOT NULL,
    maintenance_type VARCHAR(50) NOT NULL DEFAULT 'preventivo',
    -- Tipos: preventivo, correctivo, emergencia
    
    description TEXT NOT NULL,
    cost DECIMAL(12,2) DEFAULT 0,
    
    performed_by VARCHAR(255),
    next_maintenance_date DATE,
    
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_assets_category ON assets(category);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
CREATE INDEX IF NOT EXISTS idx_assets_purchase_date ON assets(purchase_date);
CREATE INDEX IF NOT EXISTS idx_asset_maintenance_asset ON asset_maintenance(asset_id);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_assets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_assets_updated_at ON assets;
CREATE TRIGGER trigger_update_assets_updated_at
    BEFORE UPDATE ON assets
    FOR EACH ROW
    EXECUTE FUNCTION update_assets_updated_at();

-- Habilitar RLS
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE asset_maintenance ENABLE ROW LEVEL SECURITY;

-- Políticas para permitir todo
DROP POLICY IF EXISTS "Allow all operations on assets" ON assets;
CREATE POLICY "Allow all operations on assets" ON assets
    FOR ALL
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all operations on asset_maintenance" ON asset_maintenance;
CREATE POLICY "Allow all operations on asset_maintenance" ON asset_maintenance
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Verificar creación
SELECT 'Tablas de activos creadas correctamente' as resultado;
