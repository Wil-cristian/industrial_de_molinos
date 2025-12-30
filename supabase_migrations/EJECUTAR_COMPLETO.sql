-- =====================================================
-- SCRIPT COMPLETO PARA CAJA DIARIA Y PROVEEDORES
-- Industrial de Molinos
-- Ejecutar este script completo en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- 1. TABLA DE CUENTAS (accounts)
-- =====================================================
CREATE TABLE IF NOT EXISTS accounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(20) NOT NULL DEFAULT 'cash',
  balance DECIMAL(12, 2) NOT NULL DEFAULT 0,
  bank_name VARCHAR(100),
  account_number VARCHAR(50),
  color VARCHAR(10),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. TABLA DE MOVIMIENTOS (cash_movements)
-- =====================================================
CREATE TABLE IF NOT EXISTS cash_movements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id),
  to_account_id UUID REFERENCES accounts(id),
  type VARCHAR(20) NOT NULL,
  category VARCHAR(30) NOT NULL,
  amount DECIMAL(12, 2) NOT NULL,
  description VARCHAR(255) NOT NULL,
  reference VARCHAR(100),
  person_name VARCHAR(100),
  date TIMESTAMP WITH TIME ZONE NOT NULL,
  linked_transfer_id VARCHAR(50),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 3. TABLA DE PROVEEDORES (proveedores)
-- =====================================================
CREATE TABLE IF NOT EXISTS proveedores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    type VARCHAR(20) DEFAULT 'business',
    document_type VARCHAR(20) DEFAULT 'nit',
    document_number VARCHAR(50) NOT NULL DEFAULT '',
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

-- =====================================================
-- 4. ÍNDICES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_movements_account ON cash_movements(account_id);
CREATE INDEX IF NOT EXISTS idx_movements_date ON cash_movements(date);
CREATE INDEX IF NOT EXISTS idx_movements_type ON cash_movements(type);
CREATE INDEX IF NOT EXISTS idx_proveedores_name ON proveedores(name);

-- =====================================================
-- 5. HABILITAR RLS
-- =====================================================
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE proveedores ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 6. POLÍTICAS DE ACCESO (permitir todo por ahora)
-- =====================================================
DROP POLICY IF EXISTS "Allow all on accounts" ON accounts;
CREATE POLICY "Allow all on accounts" ON accounts FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on cash_movements" ON cash_movements;
CREATE POLICY "Allow all on cash_movements" ON cash_movements FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all on proveedores" ON proveedores;
CREATE POLICY "Allow all on proveedores" ON proveedores FOR ALL USING (true) WITH CHECK (true);

-- =====================================================
-- 7. CUENTAS INICIALES (3 cuentas por defecto)
-- =====================================================
INSERT INTO accounts (name, type, balance, color, is_active)
SELECT 'Caja', 'cash', 0, '#4CAF50', true
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name = 'Caja');

INSERT INTO accounts (name, type, balance, bank_name, color, is_active)
SELECT 'Cuenta Daniela', 'bank', 0, 'Banco', '#2196F3', true
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name = 'Cuenta Daniela');

INSERT INTO accounts (name, type, balance, bank_name, color, is_active)
SELECT 'Cuenta Industrial de Molinos', 'bank', 0, 'Banco', '#9C27B0', true
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name = 'Cuenta Industrial de Molinos');

-- =====================================================
-- 8. VERIFICACIÓN
-- =====================================================
SELECT 'Cuentas creadas:' as info;
SELECT id, name, type, balance FROM accounts;

SELECT 'Tablas listas!' as resultado;
