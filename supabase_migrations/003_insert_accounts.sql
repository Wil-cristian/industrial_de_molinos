-- =====================================================
-- EJECUTAR ESTE SQL EN SUPABASE PARA INSERTAR LAS CUENTAS
-- =====================================================

-- Primero verificar si ya existen las cuentas
SELECT * FROM accounts;

-- Si no hay cuentas, ejecutar esto:
INSERT INTO accounts (name, type, balance, color, is_active)
VALUES ('Caja', 'cash', 0, '#4CAF50', TRUE);

INSERT INTO accounts (name, type, balance, bank_name, color, is_active)
VALUES ('Cuenta Daniela', 'bank', 0, 'Banco', '#2196F3', TRUE);

INSERT INTO accounts (name, type, balance, bank_name, color, is_active)
VALUES ('Cuenta Industrial de Molinos', 'bank', 0, 'Banco', '#9C27B0', TRUE);

-- Verificar que se insertaron
SELECT * FROM accounts;
