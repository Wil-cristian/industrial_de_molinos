-- ================================================================
-- SCRIPT: UNIFICACIÓN DE DEUDAS - Industrial de Molinos
-- Fecha: 2026-04-13
-- Descripción: 
--   1. Elimina facturas issued/draft de clientes en la foto
--   2. Ajusta facturas parciales donde la foto difiere
--   3. Crea clientes nuevos que no existían
--   4. Crea UNA factura unificada por cliente con la deuda real (foto)
--   5. Recalcula saldos de todos los clientes afectados
-- ================================================================

BEGIN;

-- ================================================================
-- PASO 1: Crear 4 clientes nuevos (no existían en la BD)
-- ================================================================
INSERT INTO customers (name, document_number, document_type, type, notes)
VALUES 
  ('Jose Ricaute', 'PEND-RICAUTE', 'CC', 'person', 'Cliente creado por unificación de deudas 2026-04-13'),
  ('Marta Escobar', 'PEND-ESCOBAR', 'CC', 'person', 'Cliente creado por unificación de deudas 2026-04-13'),
  ('Alejandra Ayala', 'PEND-AYALA', 'CC', 'person', 'Cliente creado por unificación de deudas 2026-04-13'),
  ('Ferney Taborda', 'PEND-TABORDA', 'CC', 'person', 'Cliente creado por unificación de deudas 2026-04-13');

-- ================================================================
-- PASO 2: Eliminar 23 facturas issued/draft de clientes en la foto
-- (CASCADE elimina invoice_items, payments, invoice_interests)
-- ================================================================
DELETE FROM invoices WHERE id IN (
  -- Alex Canalete: 3 facturas issued ($495K + $5.7M + $3.3M)
  '5ae4ebf7-2a17-49e4-a3c7-cbe7db870ccb',  -- VTA-42
  'bbee89a9-f3b3-4141-a0cc-ff0bafbe8c34',  -- VTA-07
  '85dbd5d4-5346-4b42-bd02-39c840b5bc22',  -- VTA-81
  -- Alex Sociedad: 1 factura issued ($5.7M)
  'ee36103c-b844-45f3-96c6-83b8fc29d710',  -- VTA-59
  -- Ariel Guerrero: 1 factura issued ($4.3M)
  '3b7d92c3-f6d1-4d0f-bc7f-304e7094abd4',  -- VTA-41
  -- Arturo Ocampo: 2 facturas issued ($3.7M + $3.8M)
  'c6e11171-4f4d-470c-a49a-abce2a689a42',  -- VTA-35
  '2ad76efb-cdcd-47af-abbc-e7f69642de78',  -- VTA-26
  -- Buseta: 1 factura issued ($2.7M)
  'cf605862-8834-457c-bf38-0e54f49b1b26',  -- VTA-36
  -- Caparrosal: 1 factura issued ($7.45M)
  'f58e5adb-7771-4db7-89e8-1b8d55222f0f',  -- VTA-31
  -- Daniel Sierra: 1 factura issued ($29.1M)
  '7fa56dc6-6d99-44ef-ab0f-17da613e959c',  -- VTA-63
  -- Eduardo Villada: 2 facturas draft+issued ($21.3M + $1M)
  '0e9bb743-c26e-4f4c-b6d8-9a543ca5bd49',  -- VTA-24
  '076abec1-8895-4344-ae0f-ecbd1140a0d0',  -- VTA-15
  -- Jhoana Romero: 1 factura issued ($2.27M)
  '20d06d89-3ab4-4d2a-8a2e-6bd1b0adeb35',  -- VTA-71
  -- Jhon Edison Ordoñez: 1 factura issued ($3.15M)
  '8fbe5977-2e6d-4486-ba3d-3ecf81e96ed2',  -- VTA-84
  -- Leonel Amariles: 2 facturas issued ($298K + $7M)
  '7d4cb7bc-8647-4c0b-857b-305893f43cd8',  -- VTA-25
  '2cd954ab-04a4-48ad-9267-b0ad3a01252f',  -- VTA-43
  -- Mauricio Arias: 2 facturas issued ($42.9M + $462K)
  'df861a9f-8aad-4b7b-ab76-91b3d3c39d01',  -- VTA-44
  'eb35f731-f96f-49ad-9eeb-ae2a3e773bac',  -- VTA-45
  -- Mauricio Las Pilas: 1 factura issued ($13.8M)
  'c7b41b64-894f-40f2-abe1-8cbbb5d935a2',  -- VTA-77
  -- Orlando Largo: 1 factura issued ($10.3M)
  '4cff2608-f82c-4f8c-8fd2-a8985a4c9580',  -- VTA-55
  -- Robinson Jimenez: 2 facturas issued ($1.95M + $11.25M)
  'cba452dc-a6e9-4cf3-b6e0-0a5668d11f62',  -- VTA-20
  'd85f64d6-42ce-4588-aee6-56f95b24ca5e',  -- VTA-85
  -- Sonia: 1 factura issued ($104K)
  'f0980d7a-3eba-4448-82b4-2f46da98d7e0'   -- VTA-83
);

-- ================================================================
-- PASO 3: Ajustar facturas parciales donde la foto difiere
-- ================================================================

-- Maira Alejandra Romero: ella pagó $3M (no $2.5M) → pending = $4,095,000
UPDATE invoices 
SET paid_amount = 3000000.00,
    status = 'partial',
    notes = COALESCE(notes, '') || ' [Ajuste 2026-04-13: paid_amount corregido de 2500000 a 3000000 por pago no registrado]',
    updated_at = NOW()
WHERE id = '72fd91be-d063-4d1e-ae4e-1d5790caec35';  -- VTA-65

-- Alvaro Rendon (trituradora): ajustar para que pending = $4,800,000
-- total = 9309045.60, nuevo paid = 9309045.60 - 4800000 = 4509045.60
UPDATE invoices 
SET paid_amount = 4509045.60,
    notes = COALESCE(notes, '') || ' [Ajuste 2026-04-13: paid_amount ajustado para cuadrar con saldo real $4,800,000]',
    updated_at = NOW()
WHERE id = '8ed454c3-8531-4e19-bec4-db6239ab7787';  -- VTA-53

-- ================================================================
-- PASO 4: Crear 28 facturas unificadas con la deuda real (foto)
-- Fecha emisión: 2026-04-13, vencimiento: 2026-07-12
-- ================================================================

-- Helper: insertar facturas + items en un DO block para referenciar IDs
DO $$
DECLARE
  v_inv_id UUID;
  v_cust_id UUID;
BEGIN

  -- ---- 1. Alex Canalete → $50,745,900 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000086', '321c95d1-104c-4a69-a14b-4a5d927bc4af', 'Alex Canalete', '2026-04-13', '2026-07-12', 50745900, 0, 0, 0, 50745900, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 50745900, 50745900, 0, 50745900, 1);

  -- ---- 2. Alex Canalete Sociedad → $18,266,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000087', '6b827779-3dec-41b9-a3af-e2d97e77e9fe', 'Alex Sociedad', '2026-04-13', '2026-07-12', 18266000, 0, 0, 0, 18266000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 18266000, 18266000, 0, 18266000, 1);

  -- ---- 3. Ariel Guerrero → $4,286,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000088', '2297ee06-2118-4913-b195-1196695d0c7f', 'Ariel Guerrero', '2026-04-13', '2026-07-12', 4286000, 0, 0, 0, 4286000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 4286000, 4286000, 0, 4286000, 1);

  -- ---- 4. Arturo Ocampo → $1,050,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000089', 'b890fba3-183b-43ac-a4f6-d6e492e56d61', 'Arturo Ocampo', '2026-04-13', '2026-07-12', 1050000, 0, 0, 0, 1050000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 1050000, 1050000, 0, 1050000, 1);

  -- ---- 5. Buseta → $3,296,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000090', '1d76b7c0-b89b-42c7-b391-f7629ec8e022', 'Buseta', '2026-04-13', '2026-07-12', 3296000, 0, 0, 0, 3296000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 3296000, 3296000, 0, 3296000, 1);

  -- ---- 6. Caparrosal → $8,736,000 (horno $3,136,000 + bola $5,600,000) ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000091', '703ef007-4b2f-48f4-a5ba-64bccb1bc4c0', 'Caparrosal', '2026-04-13', '2026-07-12', 8736000, 0, 0, 0, 8736000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES 
    (v_inv_id, 'Horno', 1, 'UND', 3136000, 3136000, 0, 3136000, 1),
    (v_inv_id, 'Bola', 1, 'UND', 5600000, 5600000, 0, 5600000, 2);

  -- ---- 7. Daniel Sierra → $35,327,820 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000092', '7ffbf93b-a273-4c88-8e94-50cd6376d3c4', 'Daniel Sierra', '2026-04-13', '2026-07-12', 35327820, 0, 0, 0, 35327820, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 35327820, 35327820, 0, 35327820, 1);

  -- ---- 8. Eduardo Villada → $11,447,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000093', 'b1e53371-f0b3-4637-be70-f8bb22532e51', 'Eduardo Villada', '2026-04-13', '2026-07-12', 11447000, 0, 0, 0, 11447000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 11447000, 11447000, 0, 11447000, 1);

  -- ---- 9. Jhoana Romero → $6,500,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000094', '0f694070-dcc8-4480-bdea-f183d2af7728', 'Jhoana Romero', '2026-04-13', '2026-07-12', 6500000, 0, 0, 0, 6500000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 6500000, 6500000, 0, 6500000, 1);

  -- ---- 10. Jhon Edison Ordoñez → $3,150,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000095', '69a50239-6d3e-43af-9f1b-7654a1e8576c', 'Jhon Edison Ordoñez', '2026-04-13', '2026-07-12', 3150000, 0, 0, 0, 3150000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 3150000, 3150000, 0, 3150000, 1);

  -- ---- 11. Mauricio Arias → $12,900,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000096', '53c50ad0-a678-43b7-b537-2198f7402c11', 'Mauricio Arias', '2026-04-13', '2026-07-12', 12900000, 0, 0, 0, 12900000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 12900000, 12900000, 0, 12900000, 1);

  -- ---- 12. Mauricio Las Pilas → $13,827,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000097', '462f1fdd-c526-444a-a7ed-7d90e775bd01', 'Mauricio Las Pilas', '2026-04-13', '2026-07-12', 13827000, 0, 0, 0, 13827000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 13827000, 13827000, 0, 13827000, 1);

  -- ---- 13. Orlando Largo → $4,740,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000098', '8868d9f0-1f12-48ac-9cfc-7b899f0e3a5e', 'Orlando Largo', '2026-04-13', '2026-07-12', 4740000, 0, 0, 0, 4740000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 4740000, 4740000, 0, 4740000, 1);

  -- ---- 14. Robinson Jimenez → $21,250,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000099', 'fc80159e-64a5-4e88-85d3-59bd2be4b9eb', 'ROBINSON JIMENEZ', '2026-04-13', '2026-07-12', 21250000, 0, 0, 0, 21250000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 21250000, 21250000, 0, 21250000, 1);

  -- ---- 15. Sonia → $104,000 (foto $2,604,000 - parcial $2,500,000) ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000100', '0ebe06cd-0d67-4140-9cd2-d6613ae058b9', 'Sonia', '2026-04-13', '2026-07-12', 104000, 0, 0, 0, 104000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13 (restante después de parcial VTA-82)');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda (saldo restante)', 1, 'UND', 104000, 104000, 0, 104000, 1);

  -- ================================================================
  -- Clientes que ya existen pero no tenían facturas en la app
  -- ================================================================

  -- ---- 16. Reinaldo Meza → $2,565,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000101', '6b4074f6-a24c-4368-8a95-b4d1a3dbaaa5', 'Reinaldo Meza', '2026-04-13', '2026-07-12', 2565000, 0, 0, 0, 2565000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 2565000, 2565000, 0, 2565000, 1);

  -- ---- 17. Wilmer Ramos → $3,242,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000102', 'df5dc0c2-c3f7-4388-a4e9-3a421cd04f21', 'Wilmer Ramos', '2026-04-13', '2026-07-12', 3242000, 0, 0, 0, 3242000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 3242000, 3242000, 0, 3242000, 1);

  -- ---- 18. Maria Helena → $13,650,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000103', 'c4ba19ed-5203-4052-bdfd-4684fc0c16b8', 'Maria Helena', '2026-04-13', '2026-07-12', 13650000, 0, 0, 0, 13650000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 13650000, 13650000, 0, 13650000, 1);

  -- ---- 19. Edilberto Bañol → $2,435,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000104', '30078543-7026-48e0-80e3-2d8bade74e8c', 'Edilberto Baniol', '2026-04-13', '2026-07-12', 2435000, 0, 0, 0, 2435000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 2435000, 2435000, 0, 2435000, 1);

  -- ---- 20. Norbey Leon → $2,950,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000105', 'd43ef4e7-4565-4878-8993-627d966a6b66', 'Norbey León Rios', '2026-04-13', '2026-07-12', 2950000, 0, 0, 0, 2950000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 2950000, 2950000, 0, 2950000, 1);

  -- ---- 21. Ruben Dario Taborda → $7,347,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000106', '3374a0f7-693a-4e9e-8058-2f90ea7805ee', 'Ruben Dario Taborda', '2026-04-13', '2026-07-12', 7347000, 0, 0, 0, 7347000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 7347000, 7347000, 0, 7347000, 1);

  -- ---- 22. Don Luis → $25,520,400 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000107', '7c577076-ca9c-45cb-bf10-9e64eb7f06d3', 'Don Luis', '2026-04-13', '2026-07-12', 25520400, 0, 0, 0, 25520400, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 25520400, 25520400, 0, 25520400, 1);

  -- ---- 23. Guille → $4,050,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000108', '96de9df2-9dfa-4661-b4d5-636ad8a550b1', 'Guille', '2026-04-13', '2026-07-12', 4050000, 0, 0, 0, 4050000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 4050000, 4050000, 0, 4050000, 1);

  -- ---- 24. Jorge Guerrero → $195,000 ----
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000109', 'b31d6ca2-8367-43a8-b850-5de0e466135d', 'Jorge Guerrero', '2026-04-13', '2026-07-12', 195000, 0, 0, 0, 195000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 195000, 195000, 0, 195000, 1);

  -- ================================================================
  -- Clientes NUEVOS (recién creados en Paso 1)
  -- ================================================================

  -- ---- 25. Jose Ricaute → $2,768,000 ----
  SELECT id INTO v_cust_id FROM customers WHERE name = 'Jose Ricaute' LIMIT 1;
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000110', v_cust_id, 'Jose Ricaute', '2026-04-13', '2026-07-12', 2768000, 0, 0, 0, 2768000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 2768000, 2768000, 0, 2768000, 1);

  -- ---- 26. Marta Escobar → $31,000,000 (trituradora $15.5M + mesa $15.5M) ----
  SELECT id INTO v_cust_id FROM customers WHERE name = 'Marta Escobar' LIMIT 1;
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000111', v_cust_id, 'Marta Escobar', '2026-04-13', '2026-07-12', 31000000, 0, 0, 0, 31000000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES 
    (v_inv_id, 'Trituradora', 1, 'UND', 15500000, 15500000, 0, 15500000, 1),
    (v_inv_id, 'Mesa', 1, 'UND', 15500000, 15500000, 0, 15500000, 2);

  -- ---- 27. Alejandra Ayala → $250,000 ----
  SELECT id INTO v_cust_id FROM customers WHERE name = 'Alejandra Ayala' LIMIT 1;
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000112', v_cust_id, 'Alejandra Ayala', '2026-04-13', '2026-07-12', 250000, 0, 0, 0, 250000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 250000, 250000, 0, 250000, 1);

  -- ---- 28. Ferney Taborda → $1,800,000 ----
  SELECT id INTO v_cust_id FROM customers WHERE name = 'Ferney Taborda' LIMIT 1;
  v_inv_id := gen_random_uuid();
  INSERT INTO invoices (id, series, number, customer_id, customer_name, issue_date, due_date, subtotal, tax_amount, tax_rate, discount, total, paid_amount, status, sale_payment_type, notes)
  VALUES (v_inv_id, 'VTA', '00000113', v_cust_id, 'Ferney Taborda', '2026-04-13', '2026-07-12', 1800000, 0, 0, 0, 1800000, 0, 'issued', 'credit', 'Factura unificada - consolidación de deudas 2026-04-13');
  INSERT INTO invoice_items (invoice_id, product_name, quantity, unit, unit_price, subtotal, tax_amount, total, sort_order)
  VALUES (v_inv_id, 'Consolidación de deuda', 1, 'UND', 1800000, 1800000, 0, 1800000, 1);

END $$;

-- ================================================================
-- PASO 5: Recalcular saldos (current_balance) de TODOS los clientes
-- current_balance = suma de pending de facturas no paid/cancelled
-- ================================================================
UPDATE customers SET current_balance = COALESCE(sub.total_pending, 0), updated_at = NOW()
FROM (
  SELECT customer_id, SUM(total - paid_amount) AS total_pending
  FROM invoices
  WHERE status NOT IN ('paid', 'cancelled')
    AND series = 'VTA'
  GROUP BY customer_id
) sub
WHERE customers.id = sub.customer_id;

-- También poner en 0 los clientes que ya no tienen deuda pendiente
UPDATE customers SET current_balance = 0, updated_at = NOW()
WHERE id NOT IN (
  SELECT DISTINCT customer_id FROM invoices 
  WHERE status NOT IN ('paid', 'cancelled') 
    AND series = 'VTA'
    AND customer_id IS NOT NULL
)
AND current_balance != 0;

COMMIT;
