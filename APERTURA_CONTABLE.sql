-- =====================================================================
-- APERTURA_CONTABLE.sql
-- Saldos iniciales de empalme al 12 de Marzo 2026
-- Fuente: Excel "INDUSTRIAL DE MOLINOS E IMPORTACIONES SAS.xlsx"
-- =====================================================================
--
-- QUÉ HACE ESTE SCRIPT:
--   A) Establece saldos de caja/bancos
--   B) Registra movimientos de apertura en cash_movements
--   C) Carga cartera de deudores como facturas pendientes (serie APE)
--   D) Carga inventario inicial de bolas de acero
--
-- ANTES DE EJECUTAR:
--   1. Correr REINICIAR_FACTURAS_DESDE_CERO.sql para partir limpio
--   2. Verificar que las cuentas en la app tienen los nombres correctos
--      con: SELECT id, name, type, balance FROM accounts;
--   3. Ajustar los nombres de cuenta en la SECCIÓN A si difieren
--
-- TOTALES DE REFERENCIA:
--   Caja 1 (efectivo fisico)   :       5,575,800
--   Caja 2 (otro efectivo)     :       2,256,441
--   Bancolombia cta empresa    :       1,998,651
--   Davivienda                 :               0
--   ─────────────────────────────────────────────
--   TOTAL BANCOS               :       9,830,892
--
--   Cartera deudores (30 clientes) : 256,878,413
--
--   Inventario bolas (5 calibres)  :       REVISAR (ver nota 4")
-- =====================================================================

BEGIN;

-- =====================================================================
-- A) CUENTAS — Establecer saldos reales
-- =====================================================================
-- NOTA: Si los nombres no coinciden con los que aparecen en la app,
--       actualiza el WHERE name = '...' antes de ejecutar.

-- A1) Caja principal (efectivo en caja)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM accounts WHERE name = 'Caja' AND type = 'cash') THEN
    UPDATE accounts
    SET balance    = 5575800.00,
        updated_at = NOW()
    WHERE name = 'Caja' AND type = 'cash';
    RAISE NOTICE 'Caja actualizada a 5,575,800';
  ELSE
    INSERT INTO accounts (name, type, balance, color, is_active)
    VALUES ('Caja', 'cash', 5575800.00, '#4CAF50', TRUE);
    RAISE NOTICE 'Caja creada con saldo 5,575,800';
  END IF;
END $$;

-- A2) Caja 2 (segundo fondo de efectivo)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM accounts WHERE name = 'Caja 2') THEN
    UPDATE accounts
    SET balance    = 2256441.00,
        updated_at = NOW()
    WHERE name = 'Caja 2';
    RAISE NOTICE 'Caja 2 actualizada a 2,256,441';
  ELSE
    INSERT INTO accounts (name, type, balance, color, is_active)
    VALUES ('Caja 2', 'cash', 2256441.00, '#8BC34A', TRUE);
    RAISE NOTICE 'Caja 2 creada con saldo 2,256,441';
  END IF;
END $$;

-- A3) Bancolombia — Cuenta empresa (36800003820 Ahorros)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM accounts
             WHERE name ILIKE '%industrial%' OR name ILIKE '%bancolombia%') THEN
    UPDATE accounts
    SET balance        = 1998651.00,
        bank_name      = 'Bancolombia',
        account_number = '36800003820',
        updated_at     = NOW()
    WHERE name ILIKE '%industrial%' OR name ILIKE '%bancolombia%';
    RAISE NOTICE 'Bancolombia actualizada a 1,998,651';
  ELSE
    INSERT INTO accounts (name, type, balance, bank_name, account_number, color, is_active)
    VALUES ('Cuenta Industrial de Molinos', 'bank', 1998651.00,
            'Bancolombia', '36800003820', '#1565C0', TRUE);
    RAISE NOTICE 'Cuenta Industrial de Molinos creada';
  END IF;
END $$;

-- A4) Davivienda
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM accounts WHERE name ILIKE '%davivienda%') THEN
    UPDATE accounts
    SET balance    = 0.00,
        bank_name  = 'Davivienda',
        updated_at = NOW()
    WHERE name ILIKE '%davivienda%';
  ELSE
    INSERT INTO accounts (name, type, balance, bank_name, color, is_active)
    VALUES ('Davivienda', 'bank', 0.00, 'Davivienda', '#C62828', TRUE);
  END IF;
  RAISE NOTICE 'Davivienda = 0 registrada';
END $$;


-- =====================================================================
-- B) MOVIMIENTOS DE APERTURA — Documentar los saldos en caja
--    category = 'apertura' | reference = 'APERTURA-2026-03-12'
--    Permite que los reportes separen los movimientos reales del empalme
-- =====================================================================

-- B1) Ingreso apertura Caja
INSERT INTO cash_movements (
  account_id, type, category, amount,
  description, reference, person_name, date
)
SELECT
  a.id,
  'income',
  'apertura',
  5575800.00,
  'Saldo inicial apertura contable — Caja efectivo',
  'APERTURA-2026-03-12',
  'Apertura Industrial de Molinos',
  '2026-03-12 00:00:00+00'
FROM accounts a
WHERE a.name = 'Caja' AND a.type = 'cash'
LIMIT 1;

-- B2) Ingreso apertura Caja 2
INSERT INTO cash_movements (
  account_id, type, category, amount,
  description, reference, person_name, date
)
SELECT
  a.id,
  'income',
  'apertura',
  2256441.00,
  'Saldo inicial apertura contable — Caja 2 efectivo',
  'APERTURA-2026-03-12',
  'Apertura Industrial de Molinos',
  '2026-03-12 00:00:00+00'
FROM accounts a
WHERE a.name = 'Caja 2'
LIMIT 1;

-- B3) Ingreso apertura Bancolombia
INSERT INTO cash_movements (
  account_id, type, category, amount,
  description, reference, person_name, date
)
SELECT
  a.id,
  'income',
  'apertura',
  1998651.00,
  'Saldo inicial apertura contable — Bancolombia 36800003820',
  'APERTURA-2026-03-12',
  'Apertura Industrial de Molinos',
  '2026-03-12 00:00:00+00'
FROM accounts a
WHERE a.bank_name = 'Bancolombia' OR a.name ILIKE '%industrial%'
LIMIT 1;


-- =====================================================================
-- C) CARTERA DE DEUDORES — Facturas pendientes de cobro
--    Serie APE = Apertura (se distinguen de facturas reales VTA/FAC)
--    Total cartera: $256,878,413
-- =====================================================================

INSERT INTO invoices (type,series,number,customer_name,issue_date,due_date,subtotal,tax_rate,tax_amount,total,paid_amount,status,notes) VALUES
    ('invoice','APE','001','Daniel Sierra',          '2026-03-12','2026-03-12', 14750000,0,0, 14750000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','002','Daniel Sierra (2)',       '2026-03-12','2026-03-12', 13834000,0,0, 13834000,0,'pending','Apertura 12-Mar-2026 — segundo saldo'),
    ('invoice','APE','003','Alex Canalete',           '2026-03-12','2026-03-12', 40535000,0,0, 40535000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','004','Alex Sociedad',           '2026-03-12','2026-03-12', 12510000,0,0, 12510000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','005','Jhoana Romero',           '2026-03-12','2026-03-12',  5800000,0,0,  5800000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','006','Mauricio Las Pilas',      '2026-03-12','2026-03-12',  8388400,0,0,  8388400,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','007','La Palomera',             '2026-03-12','2026-03-12',  3600000,0,0,  3600000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','008','Alfred Betancurt',        '2026-03-12','2026-03-12',  9781000,0,0,  9781000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','009','Guille',                  '2026-03-12','2026-03-12', 44000000,0,0, 44000000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','010','Don Luis',                '2026-03-12','2026-03-12', 23674000,0,0, 23674000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','011','Jorge Guerrero',          '2026-03-12','2026-03-12',   195000,0,0,   195000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','012','Sonia',                   '2026-03-12','2026-03-12',  1712500,0,0,  1712500,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','013','Maria Helena',            '2026-03-12','2026-03-12',  5900000,0,0,  5900000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','014','Ramiro Guadualejo',       '2026-03-12','2026-03-12',   120000,0,0,   120000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','015','Buseta',                  '2026-03-12','2026-03-12',  6896513,0,0,  6896513,0,'pending','Apertura 12-Mar-2026'),
    -- Arenas ya pagó hoy según hoja Recibos ($5,500,000 trituradora)
    ('invoice','APE','016','Jhon Jairo Arenas',       '2026-03-12','2026-03-12',  5500000,0,0,  5500000,5500000,'paid','Apertura 12-Mar-2026 — Pagado 12-Mar-2026 trituradora'),
    ('invoice','APE','017','Carlos Garcia',           '2026-03-12','2026-03-12',  2060000,0,0,  2060000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','018','Maira Alejandra Romero',  '2026-03-12','2026-03-12',  3750000,0,0,  3750000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','019','Reinaldo Meza',           '2026-03-12','2026-03-12', 11565000,0,0, 11565000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','020','Wilmer Ramos',            '2026-03-12','2026-03-12',  3242000,0,0,  3242000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','021','Cliente Sur de Bolivar',  '2026-03-12','2026-03-12',  4400000,0,0,  4400000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','022','Bernardo Castro',         '2026-03-12','2026-03-12',  1240000,0,0,  1240000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','023','El Ceibo',                '2026-03-12','2026-03-12',   926000,0,0,   926000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','024','Ruben Dario Taborda',     '2026-03-12','2026-03-12',  7347000,0,0,  7347000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','025','Mauricio Escobar',        '2026-03-12','2026-03-12',  1450000,0,0,  1450000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','026','Eduardo Villada',         '2026-03-12','2026-03-12',  5540000,0,0,  5540000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','027','Wilson Ladino Henao',     '2026-03-12','2026-03-12',   267000,0,0,   267000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','028','Edilberto Bañol',         '2026-03-12','2026-03-12',  7765000,0,0,  7765000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','029','William Guevara',         '2026-03-12','2026-03-12',  2600000,0,0,  2600000,0,'pending','Apertura 12-Mar-2026'),
    ('invoice','APE','030','Victor Morales',          '2026-03-12','2026-03-12',  7530000,0,0,  7530000,0,'pending','Apertura 12-Mar-2026')
ON CONFLICT (series, number) DO NOTHING;


-- =====================================================================
-- D) INVENTARIO — Bolas de acero (stock a 14-Enero-2026)
--    Fuente: hoja "nomina" del Excel (INVENTARIO BOLA 14/01/2026)
--
--    Calibre 4": 2,415 kg (confirmado por usuario).
-- =====================================================================

DO $$
DECLARE
  v_id UUID;
BEGIN
  -- Bola 4"
  SELECT id INTO v_id FROM materials
  WHERE name ILIKE '%bola%4%' OR name ILIKE '%4"%' AND name ILIKE '%bola%'
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE materials SET stock = 2415, updated_at = NOW() WHERE id = v_id;
    RAISE NOTICE 'Bola 4" actualizada: 2415 kg';
  ELSE
    INSERT INTO materials (name, description, unit, stock, min_stock, updated_at)
    VALUES ('Bola de acero 4"', 'Bola de molienda calibre 4 pulgadas — apertura 14-Ene-2026',
            'KG', 2415, 100, NOW());
    RAISE NOTICE 'Bola 4" creada: 2415 kg';
  END IF;

  -- Bola 3"
  SELECT id INTO v_id FROM materials
  WHERE name ILIKE '%bola%3%' OR (name ILIKE '%3"%' AND name ILIKE '%bola%')
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE materials SET stock = 579.5, updated_at = NOW() WHERE id = v_id;
  ELSE
    INSERT INTO materials (name, description, unit, stock, min_stock, updated_at)
    VALUES ('Bola de acero 3"', 'Bola de molienda calibre 3 pulgadas — apertura 14-Ene-2026',
            'KG', 579.5, 100, NOW());
  END IF;
  RAISE NOTICE 'Bola 3": 579.5 kg';

  -- Bola 2.5"
  SELECT id INTO v_id FROM materials
  WHERE name ILIKE '%bola%2.5%' OR name ILIKE '%bola%2,5%'
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE materials SET stock = 378.2, updated_at = NOW() WHERE id = v_id;
  ELSE
    INSERT INTO materials (name, description, unit, stock, min_stock, updated_at)
    VALUES ('Bola de acero 2.5"', 'Bola de molienda calibre 2.5 pulgadas — apertura 14-Ene-2026',
            'KG', 378.2, 50, NOW());
  END IF;
  RAISE NOTICE 'Bola 2.5": 378.2 kg';

  -- Bola 2"
  SELECT id INTO v_id FROM materials
  WHERE name ILIKE '%bola%' AND (name ILIKE '%2"%' OR name ILIKE '% 2 %')
    AND name NOT ILIKE '%2.5%' AND name NOT ILIKE '%2,5%'
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE materials SET stock = 267.3, updated_at = NOW() WHERE id = v_id;
  ELSE
    INSERT INTO materials (name, description, unit, stock, min_stock, updated_at)
    VALUES ('Bola de acero 2"', 'Bola de molienda calibre 2 pulgadas — apertura 14-Ene-2026',
            'KG', 267.3, 50, NOW());
  END IF;
  RAISE NOTICE 'Bola 2": 267.3 kg';

  -- Bola 1"
  SELECT id INTO v_id FROM materials
  WHERE name ILIKE '%bola%1"%' OR (name ILIKE '%bola%' AND name ILIKE '% 1"')
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE materials SET stock = 647.6, updated_at = NOW() WHERE id = v_id;
  ELSE
    INSERT INTO materials (name, description, unit, stock, min_stock, updated_at)
    VALUES ('Bola de acero 1"', 'Bola de molienda calibre 1 pulgada — apertura 14-Ene-2026',
            'KG', 647.6, 50, NOW());
  END IF;
  RAISE NOTICE 'Bola 1": 647.6 kg';

END $$;

-- Registrar movimientos de inventario por la apertura
INSERT INTO material_movements (material_id, type, quantity, reason, reference, created_at)
SELECT
  m.id,
  'entrada',
  m.stock,
  'Stock inicial apertura contable',
  'APERTURA-2026-03-12',
  NOW()
FROM materials m
WHERE m.name ILIKE '%bola de acero%'
  AND NOT EXISTS (
    SELECT 1 FROM material_movements mm
    WHERE mm.material_id = m.id
      AND mm.reference = 'APERTURA-2026-03-12'
  );

COMMIT;

-- =====================================================================
-- RESUMEN POST-APERTURA
-- =====================================================================
SELECT '── CUENTAS ──────────────────────────────────' AS seccion, '' AS detalle, NULL AS valor
UNION ALL
SELECT '  ' || name, type, balance FROM accounts WHERE is_active = TRUE
UNION ALL
SELECT '  TOTAL BANCOS/CAJA', '', SUM(balance) FROM accounts WHERE is_active = TRUE
UNION ALL
SELECT '── DEUDORES (facturas APE) ──────────────────', '', NULL
UNION ALL
SELECT '  Cantidad facturas APE', '', COUNT(*)::NUMERIC FROM invoices WHERE series = 'APE'
UNION ALL
SELECT '  Total cartera APE', '', SUM(total) FROM invoices WHERE series = 'APE'
UNION ALL
SELECT '── INVENTARIO BOLAS ─────────────────────────', '', NULL
UNION ALL
SELECT '  ' || name, unit, stock FROM materials WHERE name ILIKE '%bola de acero%'
ORDER BY seccion;

-- Verificar total caja/bancos
SELECT
  ROUND(SUM(balance), 0) AS total_caja_bancos,
  9830892                 AS esperado,
  ROUND(SUM(balance), 0) - 9830892 AS diferencia
FROM accounts;
