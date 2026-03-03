-- =====================================================
-- MIGRACIÓN 027: Consolidar proveedores y suppliers
-- =====================================================
-- Problema: Dos tablas duplicadas — 'proveedores' (usada por Dart) y 'suppliers' (FK desde purchases).
-- Solución: Agregar columnas faltantes a 'proveedores', migrar FK de purchases, eliminar 'suppliers'.
-- =====================================================

-- 1. Agregar columnas que existen en suppliers pero no en proveedores
ALTER TABLE proveedores ADD COLUMN IF NOT EXISTS code VARCHAR(20) UNIQUE;
ALTER TABLE proveedores ADD COLUMN IF NOT EXISTS category VARCHAR(50);
ALTER TABLE proveedores ADD COLUMN IF NOT EXISTS payment_terms VARCHAR(100);
ALTER TABLE proveedores ADD COLUMN IF NOT EXISTS credit_limit DECIMAL(12,2) DEFAULT 0;
ALTER TABLE proveedores ADD COLUMN IF NOT EXISTS rating INTEGER DEFAULT 3 CHECK (rating BETWEEN 1 AND 5);
ALTER TABLE proveedores ADD COLUMN IF NOT EXISTS notes TEXT;

-- 2. Migrar datos de suppliers a proveedores (solo los que no existan)
INSERT INTO proveedores (
    id, code, name, trade_name, document_type, document_number,
    address, phone, email, contact_person,
    category, payment_terms, credit_limit, rating, notes,
    bank_name, bank_account, current_debt, is_active,
    created_at, updated_at
)
SELECT
    s.id,
    s.code,
    s.name,
    s.trade_name,
    'nit',  -- document_type por defecto
    COALESCE(s.ruc, ''),  -- ruc → document_number
    s.address,
    s.phone,
    s.email,
    s.contact_person,
    s.category,
    s.payment_terms,
    s.credit_limit,
    s.rating,
    s.notes,
    s.bank_name,
    s.bank_account,
    s.current_debt,
    s.is_active,
    s.created_at,
    s.updated_at
FROM suppliers s
WHERE NOT EXISTS (
    SELECT 1 FROM proveedores p
    WHERE p.id = s.id OR p.name = s.name
)
ON CONFLICT (id) DO NOTHING;

-- 3. Actualizar FK de purchases para apuntar a proveedores
-- Primero eliminar la FK vieja (si existe)
ALTER TABLE purchases DROP CONSTRAINT IF EXISTS purchases_supplier_id_fkey;
ALTER TABLE purchases DROP CONSTRAINT IF EXISTS fk_purchases_supplier;

-- Agregar nueva FK apuntando a proveedores
ALTER TABLE purchases
    ADD CONSTRAINT fk_purchases_proveedor
    FOREIGN KEY (supplier_id) REFERENCES proveedores(id)
    ON DELETE SET NULL;

-- 4. Eliminar tabla suppliers
DROP TABLE IF EXISTS suppliers CASCADE;

-- 5. Crear vista compatible para código que use nombre 'suppliers'
CREATE OR REPLACE VIEW suppliers AS SELECT * FROM proveedores;

-- 6. Generar códigos para proveedores que no tengan
UPDATE proveedores
SET code = 'PROV-' || LPAD(
    ROW_NUMBER() OVER (ORDER BY created_at)::TEXT, 4, '0'
)
WHERE code IS NULL;

COMMENT ON TABLE proveedores IS 'Tabla unificada de proveedores (consolidada de proveedores + suppliers)';
