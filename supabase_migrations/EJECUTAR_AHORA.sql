-- =====================================================
-- SCRIPT PARA CAJA DIARIA - EJECUTAR EN SUPABASE
-- Industrial de Molinos
-- 
-- INSTRUCCIONES:
-- 1. Ve a Supabase Dashboard
-- 2. SQL Editor (icono de base de datos a la izquierda)
-- 3. New Query
-- 4. Pega TODO este código
-- 5. Click en "RUN" (o Ctrl+Enter)
-- 6. Verifica que no haya errores en rojo
-- =====================================================

-- Primero, verificamos qué tablas ya existen
DO $$
BEGIN
    RAISE NOTICE '=== VERIFICANDO TABLAS EXISTENTES ===';
END $$;

-- =====================================================
-- 1. TABLA DE CUENTAS DE CAJA (accounts)
-- Esta es DIFERENTE de chart_of_accounts (contabilidad)
-- =====================================================
DROP TABLE IF EXISTS cash_movements CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;

CREATE TABLE accounts (
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

-- Verificar creación
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'accounts' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ Tabla accounts creada correctamente';
    ELSE
        RAISE EXCEPTION '❌ Error: No se pudo crear la tabla accounts';
    END IF;
END $$;

-- =====================================================
-- 2. TABLA DE MOVIMIENTOS DE CAJA (cash_movements)
-- =====================================================
CREATE TABLE cash_movements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
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

-- Verificar creación
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'cash_movements' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ Tabla cash_movements creada correctamente';
    ELSE
        RAISE EXCEPTION '❌ Error: No se pudo crear la tabla cash_movements';
    END IF;
END $$;

-- =====================================================
-- 3. TABLA DE PROVEEDORES (proveedores)
-- =====================================================
DROP TABLE IF EXISTS proveedores CASCADE;

CREATE TABLE proveedores (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    type VARCHAR(20) DEFAULT 'business',
    document_type VARCHAR(20) DEFAULT 'RUC',
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

-- Verificar creación
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'proveedores' AND table_schema = 'public') THEN
        RAISE NOTICE '✅ Tabla proveedores creada correctamente';
    ELSE
        RAISE EXCEPTION '❌ Error: No se pudo crear la tabla proveedores';
    END IF;
END $$;

-- =====================================================
-- 4. ÍNDICES PARA MEJOR RENDIMIENTO
-- =====================================================
CREATE INDEX idx_cash_movements_account ON cash_movements(account_id);
CREATE INDEX idx_cash_movements_date ON cash_movements(date);
CREATE INDEX idx_cash_movements_type ON cash_movements(type);
CREATE INDEX idx_proveedores_name ON proveedores(name);
CREATE INDEX idx_proveedores_document ON proveedores(document_number);

-- =====================================================
-- 5. HABILITAR ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE proveedores ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 6. POLÍTICAS DE ACCESO (permitir todo)
-- =====================================================
CREATE POLICY "accounts_policy" ON accounts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "cash_movements_policy" ON cash_movements FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "proveedores_policy" ON proveedores FOR ALL USING (true) WITH CHECK (true);

-- =====================================================
-- 7. INSERTAR CUENTAS INICIALES
-- =====================================================
INSERT INTO accounts (name, type, balance, color, is_active) VALUES
('Caja', 'cash', 0, '#4CAF50', true),
('Cuenta Daniela', 'bank', 0, '#2196F3', true),
('Cuenta Industrial de Molinos', 'bank', 0, '#9C27B0', true);

-- =====================================================
-- 8. FORZAR ACTUALIZACIÓN DEL SCHEMA CACHE
-- =====================================================
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- 9. VERIFICACIÓN FINAL
-- =====================================================
SELECT '=== VERIFICACIÓN FINAL ===' as info;

SELECT 'ACCOUNTS:' as tabla, count(*) as registros FROM accounts
UNION ALL
SELECT 'CASH_MOVEMENTS:', count(*) FROM cash_movements
UNION ALL
SELECT 'PROVEEDORES:', count(*) FROM proveedores;

SELECT '=== CUENTAS CREADAS ===' as info;
SELECT id, name, type, balance FROM accounts;

SELECT '🎉 ¡TODO LISTO! Reinicia tu app Flutter.' as resultado;
