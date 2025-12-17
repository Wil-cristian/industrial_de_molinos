-- =====================================================
-- TABLAS PARA SISTEMA DE CAJA DIARIA
-- Industrial de Molinos
-- =====================================================

-- Tabla de Cuentas (accounts)
CREATE TABLE IF NOT EXISTS accounts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(20) NOT NULL DEFAULT 'cash', -- 'cash' o 'bank'
  balance DECIMAL(12, 2) NOT NULL DEFAULT 0,
  bank_name VARCHAR(100),
  account_number VARCHAR(50),
  color VARCHAR(10), -- Color en formato hex (#RRGGBB)
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla de Movimientos de Caja (cash_movements)
CREATE TABLE IF NOT EXISTS cash_movements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id),
  to_account_id UUID REFERENCES accounts(id), -- Solo para traslados
  type VARCHAR(20) NOT NULL, -- 'income', 'expense', 'transfer'
  category VARCHAR(30) NOT NULL, -- Categoría del movimiento
  amount DECIMAL(12, 2) NOT NULL,
  description VARCHAR(255) NOT NULL,
  reference VARCHAR(100), -- Referencia (número de factura, recibo, etc.)
  person_name VARCHAR(100), -- Nombre de la persona (cliente, proveedor, empleado)
  date TIMESTAMP WITH TIME ZONE NOT NULL,
  linked_transfer_id VARCHAR(50), -- Para relacionar traslados
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para mejor rendimiento
CREATE INDEX IF NOT EXISTS idx_movements_account ON cash_movements(account_id);
CREATE INDEX IF NOT EXISTS idx_movements_date ON cash_movements(date);
CREATE INDEX IF NOT EXISTS idx_movements_type ON cash_movements(type);

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger para actualizar updated_at en accounts
DROP TRIGGER IF EXISTS update_accounts_updated_at ON accounts;
CREATE TRIGGER update_accounts_updated_at
  BEFORE UPDATE ON accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Habilitar Row Level Security (opcional pero recomendado)
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cash_movements ENABLE ROW LEVEL SECURITY;

-- Políticas de acceso (permitir todo por ahora - ajustar según necesidades)
DROP POLICY IF EXISTS "Allow all operations on accounts" ON accounts;
CREATE POLICY "Allow all operations on accounts" ON accounts FOR ALL USING (true);

DROP POLICY IF EXISTS "Allow all operations on cash_movements" ON cash_movements;
CREATE POLICY "Allow all operations on cash_movements" ON cash_movements FOR ALL USING (true);

-- =====================================================
-- INSERTAR CUENTAS PREDETERMINADAS
-- =====================================================

-- Insertar las 3 cuentas (usar ON CONFLICT para evitar duplicados)
INSERT INTO accounts (id, name, type, balance, color, is_active)
VALUES 
  (gen_random_uuid(), 'Caja', 'cash', 0, '#4CAF50', TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO accounts (id, name, type, balance, bank_name, color, is_active)
VALUES 
  (gen_random_uuid(), 'Cuenta Daniela', 'bank', 0, 'Banco', '#2196F3', TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO accounts (id, name, type, balance, bank_name, color, is_active)
VALUES 
  (gen_random_uuid(), 'Cuenta Industrial de Molinos', 'bank', 0, 'Banco', '#9C27B0', TRUE)
ON CONFLICT DO NOTHING;

-- =====================================================
-- VERIFICAR ESTRUCTURA
-- =====================================================
-- Ejecuta esto para verificar que las tablas se crearon correctamente:
-- SELECT * FROM accounts;
-- SELECT * FROM cash_movements LIMIT 10;
