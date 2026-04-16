-- =====================================================
-- FIX ENUM TYPES - Industrial de Molinos
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- PASO 0: ELIMINAR VISTAS DEPENDIENTES
-- =====================================================
DROP VIEW IF EXISTS v_customer_purchase_history CASCADE;
DROP VIEW IF EXISTS v_customer_metrics CASCADE;
DROP VIEW IF EXISTS v_customers_with_debt CASCADE;

-- =====================================================
-- OPCIÓN 1: RECREAR LOS ENUMS (Recomendado si la tabla customers está vacía)
-- =====================================================

-- Primero verificar si hay datos
SELECT COUNT(*) as total_customers FROM customers;

-- Si NO hay datos, ejecutar esto:

-- 1. Eliminar la columna que usa el ENUM
ALTER TABLE customers DROP COLUMN IF EXISTS document_type CASCADE;
ALTER TABLE customers DROP COLUMN IF EXISTS type CASCADE;

-- 2. Eliminar los tipos ENUM antiguos
DROP TYPE IF EXISTS document_type CASCADE;
DROP TYPE IF EXISTS customer_type CASCADE;

-- 3. Crear los tipos ENUM correctamente
CREATE TYPE customer_type AS ENUM ('individual', 'business');
CREATE TYPE document_type AS ENUM ('cc', 'nit', 'ce', 'pasaporte', 'ti');

-- 4. Agregar las columnas de nuevo
ALTER TABLE customers ADD COLUMN type customer_type NOT NULL DEFAULT 'business';
ALTER TABLE customers ADD COLUMN document_type document_type NOT NULL DEFAULT 'nit';

-- =====================================================
-- PASO 5: RECREAR LAS VISTAS
-- =====================================================

-- Vista: Clientes con deuda
CREATE OR REPLACE VIEW v_customers_with_debt AS
SELECT 
    id,
    name,
    document_number,
    phone,
    email,
    credit_limit,
    current_balance,
    CASE 
        WHEN current_balance > credit_limit THEN 'over_limit'
        WHEN current_balance > 0 THEN 'has_debt'
        ELSE 'no_debt'
    END as debt_status
FROM customers
WHERE is_active = true AND current_balance > 0
ORDER BY current_balance DESC;

-- =====================================================
-- DESHABILITAR RLS
-- =====================================================
ALTER TABLE customers DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- OPCIÓN 2: CONVERTIR A VARCHAR (Más seguro si hay datos)
-- =====================================================

-- Esta opción convierte los ENUMs a VARCHAR, lo cual es más flexible
-- y evita problemas de compatibilidad

-- Paso 1: Agregar columnas temporales VARCHAR
ALTER TABLE customers ADD COLUMN IF NOT EXISTS type_temp VARCHAR(20);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS document_type_temp VARCHAR(20);

-- Paso 2: Copiar datos existentes (si hay)
UPDATE customers SET type_temp = type::text WHERE type IS NOT NULL;
UPDATE customers SET document_type_temp = document_type::text WHERE document_type IS NOT NULL;

-- Paso 3: Eliminar columnas ENUM antiguas
ALTER TABLE customers DROP COLUMN IF EXISTS type;
ALTER TABLE customers DROP COLUMN IF EXISTS document_type;

-- Paso 4: Renombrar columnas temporales
ALTER TABLE customers RENAME COLUMN type_temp TO type;
ALTER TABLE customers RENAME COLUMN document_type_temp TO document_type;

-- Paso 5: Agregar valores por defecto
ALTER TABLE customers ALTER COLUMN type SET DEFAULT 'business';
ALTER TABLE customers ALTER COLUMN document_type SET DEFAULT 'nit';

-- Paso 6: Agregar NOT NULL constraint
ALTER TABLE customers ALTER COLUMN type SET NOT NULL;
ALTER TABLE customers ALTER COLUMN document_type SET NOT NULL;

-- =====================================================
-- OPCIÓN 3: SCRIPT SIMPLE PARA RECREAR TODO (Si customers está vacía)
-- =====================================================

-- ADVERTENCIA: Esto elimina TODOS los datos de customers

/*
-- Eliminar tabla
DROP TABLE IF EXISTS customers CASCADE;

-- Eliminar tipos
DROP TYPE IF EXISTS document_type CASCADE;
DROP TYPE IF EXISTS customer_type CASCADE;

-- Crear tipos
CREATE TYPE customer_type AS ENUM ('individual', 'business');
CREATE TYPE document_type AS ENUM ('cc', 'nit', 'ce', 'pasaporte', 'ti');

-- Crear tabla
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type customer_type NOT NULL DEFAULT 'business',
    document_type document_type NOT NULL DEFAULT 'nit',
    document_number VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    credit_limit DECIMAL(12,2) DEFAULT 0,
    current_balance DECIMAL(12,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_customers_document ON customers(document_number);
CREATE INDEX idx_customers_name ON customers(name);
CREATE INDEX idx_customers_active ON customers(is_active);

-- Deshabilitar RLS para desarrollo
ALTER TABLE customers DISABLE ROW LEVEL SECURITY;
*/

-- =====================================================
-- VERIFICACIÓN
-- =====================================================

-- Ver estructura actual de la tabla
SELECT column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'customers'
ORDER BY ordinal_position;

-- Ver tipos ENUM existentes
SELECT t.typname as enum_name, e.enumlabel as enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname IN ('customer_type', 'document_type')
ORDER BY t.typname, e.enumsortorder;

-- =====================================================
-- FIN DEL SCRIPT
-- =====================================================
