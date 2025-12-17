-- =====================================================
-- LIMPIAR CUENTAS DUPLICADAS Y DEJAR SOLO 3
-- =====================================================

-- Paso 1: Ver cuántas cuentas hay
SELECT COUNT(*) as total_accounts FROM accounts;

-- Paso 2: Eliminar todas las cuentas
DELETE FROM accounts;

-- Paso 3: Insertar las 3 cuentas correctas
INSERT INTO accounts (name, type, balance, color, is_active)
VALUES ('Caja', 'cash', 0, '#4CAF50', TRUE);

INSERT INTO accounts (name, type, balance, bank_name, color, is_active)
VALUES ('Cuenta Daniela', 'bank', 0, 'Banco', '#2196F3', TRUE);

INSERT INTO accounts (name, type, balance, bank_name, color, is_active)
VALUES ('Cuenta Industrial de Molinos', 'bank', 0, 'Banco', '#9C27B0', TRUE);

-- Paso 4: Verificar que están las 3
SELECT * FROM accounts ORDER BY name;
