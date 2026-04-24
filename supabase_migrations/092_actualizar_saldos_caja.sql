-- ============================================================
-- 092: Actualizar saldos reales de cuentas de caja/banco
-- Fecha: 2026-04-24
-- Valores reales:
--   Jhoan        :             0
--   Davivienda   :     1,573,309
--   Bancolombia  :   114,001,982
--   Caja         :     4,745,200
-- ============================================================

-- Jhoan (caja o cuenta asociada al empleado Jhoan)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM accounts WHERE name ILIKE '%jhoan%') THEN
    UPDATE accounts
    SET balance    = 0.00,
        updated_at = NOW()
    WHERE name ILIKE '%jhoan%';
    RAISE NOTICE 'Jhoan actualizado a 0';
  ELSE
    RAISE NOTICE 'No se encontró cuenta con nombre Jhoan';
  END IF;
END $$;

-- Davivienda
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM accounts WHERE name ILIKE '%davivienda%') THEN
    UPDATE accounts
    SET balance    = 1573309.00,
        updated_at = NOW()
    WHERE name ILIKE '%davivienda%';
    RAISE NOTICE 'Davivienda actualizada a 1,573,309';
  ELSE
    RAISE NOTICE 'No se encontró cuenta Davivienda';
  END IF;
END $$;

-- Bancolombia
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM accounts WHERE name ILIKE '%bancolombia%' OR name ILIKE '%industrial%') THEN
    UPDATE accounts
    SET balance    = 114001982.00,
        updated_at = NOW()
    WHERE name ILIKE '%bancolombia%' OR name ILIKE '%industrial%';
    RAISE NOTICE 'Bancolombia actualizada a 114,001,982';
  ELSE
    RAISE NOTICE 'No se encontró cuenta Bancolombia';
  END IF;
END $$;

-- Caja (efectivo físico)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM accounts WHERE name = 'Caja' AND type = 'cash') THEN
    UPDATE accounts
    SET balance    = 4745200.00,
        updated_at = NOW()
    WHERE name = 'Caja' AND type = 'cash';
    RAISE NOTICE 'Caja actualizada a 4,745,200';
  ELSE
    RAISE NOTICE 'No se encontró cuenta Caja (cash)';
  END IF;
END $$;

-- Verificación final
SELECT name, type, balance
FROM accounts
WHERE name ILIKE '%jhoan%'
   OR name ILIKE '%davivienda%'
   OR name ILIKE '%bancolombia%'
   OR name ILIKE '%industrial%'
   OR (name = 'Caja' AND type = 'cash')
ORDER BY name;
