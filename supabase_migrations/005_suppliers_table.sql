-- =====================================================
-- TABLA DE PROVEEDORES
-- Industrial de Molinos
-- =====================================================

-- Crear tabla proveedores (en español para mantener consistencia)
CREATE TABLE IF NOT EXISTS proveedores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    type VARCHAR(20) DEFAULT 'business' CHECK (type IN ('individual', 'business')),
    document_type VARCHAR(20) DEFAULT 'RUC',
    document_number VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    address TEXT,
    phone VARCHAR(50),
    email VARCHAR(255),
    contact_person VARCHAR(255),
    bank_account VARCHAR(100),
    bank_name VARCHAR(100),
    current_debt DECIMAL(15, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_proveedores_name ON proveedores(name);
CREATE INDEX IF NOT EXISTS idx_proveedores_document ON proveedores(document_number);
CREATE INDEX IF NOT EXISTS idx_proveedores_active ON proveedores(is_active);

-- Habilitar RLS
ALTER TABLE proveedores ENABLE ROW LEVEL SECURITY;

-- Política para permitir todas las operaciones (ajustar según necesidad)
DROP POLICY IF EXISTS "Allow all operations on proveedores" ON proveedores;
CREATE POLICY "Allow all operations on proveedores" ON proveedores
    FOR ALL USING (true) WITH CHECK (true);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_proveedores_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_proveedores_updated_at ON proveedores;
CREATE TRIGGER trigger_update_proveedores_updated_at
    BEFORE UPDATE ON proveedores
    FOR EACH ROW
    EXECUTE FUNCTION update_proveedores_updated_at();

-- =====================================================
-- PROVEEDORES INICIALES DE EJEMPLO (opcional)
-- =====================================================

-- INSERT INTO suppliers (type, document_type, document_number, name, trade_name, phone)
-- VALUES 
--     ('business', 'RUC', '20123456789', 'Distribuidora ABC S.A.C.', 'ABC Distribuidora', '01-234-5678'),
--     ('business', 'RUC', '20987654321', 'Insumos Industriales S.R.L.', 'Insumos Industriales', '01-876-5432'),
--     ('individual', 'DNI', '12345678', 'Juan Pérez', NULL, '999-888-777');

-- =====================================================
-- VERIFICACIÓN
-- =====================================================
-- SELECT * FROM suppliers;
