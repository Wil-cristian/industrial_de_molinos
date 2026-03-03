-- ============================================================
-- LIMPIAR DATOS FALSOS + CARGAR DATOS REALES DE DICIEMBRE 2025
-- Industrial de Molinos e Importaciones
-- SupÃ­a, Caldas
-- ============================================================
-- Fuente: 32 recibos fÃ­sicos escaneados (0312â€“0349)
-- PerÃ­odo: 01â€“31 diciembre 2025
-- Total ventas: $169,870,901
-- Total ganancia: $91,447,656
-- ============================================================
-- EJECUTAR EN: Supabase Dashboard > SQL Editor
-- ============================================================

BEGIN;

-- ============================================================
-- PASO 1: LIMPIAR TODOS LOS DATOS FALSOS DE PRUEBA
-- ============================================================

-- Contabilidad
TRUNCATE TABLE journal_entry_lines CASCADE;
TRUNCATE TABLE journal_entries CASCADE;

-- NÃ³mina (solo datos generados del LLENAR_4_MESES, NO toca empleados reales)
DELETE FROM payroll WHERE id::text LIKE 'db000001-%';
DELETE FROM payroll_periods WHERE id::text LIKE 'da000001-%';

-- IVA falso
DELETE FROM iva_invoices WHERE id::text LIKE 'ca000001-%';
DELETE FROM iva_bimonthly_settlements WHERE id::text LIKE 'cb000001-%';

-- Ventas y facturaciÃ³n falsa
TRUNCATE TABLE invoice_interests CASCADE;
TRUNCATE TABLE invoice_items CASCADE;
TRUNCATE TABLE invoices CASCADE;
TRUNCATE TABLE quotation_items CASCADE;
TRUNCATE TABLE quotations CASCADE;

-- Compras falsas
DELETE FROM purchase_orders WHERE id::text LIKE 'e1000001-%';

-- Movimientos inventario falsos
DELETE FROM stock_movements WHERE id::text LIKE 'dc100001-%';
DELETE FROM material_movements WHERE id::text LIKE 'dc200001-%';

-- Productos y componentes falsos (seed_data + LLENAR_4_MESES)
DELETE FROM product_components WHERE id::text LIKE 'dc000001-%';

-- Clientes falsos (seed_data peruanos)
DELETE FROM customers WHERE document_number IN (
    '20123456789', '20234567890', '20345678901', '20456789012',
    '20567890123', '12345678', '20678901234', '20789012345'
);

-- ============================================================
-- PASO 2: INSERTAR CLIENTES REALES (Diciembre 2025)
-- ============================================================
-- ExtraÃ­dos de los 32 recibos fÃ­sicos escaneados
-- Todos son clientes de SupÃ­a/Caldas y alrededores (minerÃ­a artesanal)

INSERT INTO customers (id, type, document_type, name, trade_name, phone, is_active, notes, created_at)
VALUES
    -- Clientes recurrentes (aparecen en mÃºltiples recibos)
    ('c2000001-0ea1-0000-0000-000000000001', 'individual', 'cc', 'Jhon Jairo Arenas', NULL, NULL, true, 'Cliente recurrente - Piezas fundidas, bolas, caucho', '2025-12-01'),
    ('c2000001-0ea1-0000-0000-000000000002', 'individual', 'cc', 'Elkin Mario Zapata', NULL, NULL, true, 'Cliente recurrente - Placas de desgaste', '2025-12-01'),
    ('c2000001-0ea1-0000-0000-000000000003', 'individual', 'cc', 'Wilmer Ramos Canaval', NULL, NULL, true, 'Cliente recurrente - Discos, remoledores', '2025-12-01'),
    
    -- Clientes regulares
    ('c2000001-0ea1-0000-0000-000000000004', 'individual', 'cc', 'Reinaldo Mesa', NULL, NULL, true, 'Eclipas/grapas para molino', '2025-12-24'),
    ('c2000001-0ea1-0000-0000-000000000005', 'individual', 'cc', 'Benaimo Carro', NULL, NULL, true, 'Removedores', '2025-12-24'),
    ('c2000001-0ea1-0000-0000-000000000006', 'individual', 'cc', 'Alex Caballero', NULL, NULL, true, 'Volantes', '2025-12-27'),
    ('c2000001-0ea1-0000-0000-000000000007', 'individual', 'cc', 'JuliÃ¡n AndrÃ©s LondoÃ±o', NULL, NULL, true, 'Placas 27" SB 7/8', '2025-12-29'),
    ('c2000001-0ea1-0000-0000-000000000008', 'business', 'nit', 'Buseta', 'Buseta', NULL, true, 'Placas de manganeso', '2025-12-24'),
    ('c2000001-0ea1-0000-0000-000000000009', 'individual', 'cc', 'Guillermo Ortiz', NULL, NULL, true, 'Coches mineros', '2025-12-17'),
    ('c2000001-0ea1-0000-0000-000000000010', 'individual', 'cc', 'William Giraldo', NULL, NULL, true, 'Tubos especiales', '2025-12-18'),
    ('c2000001-0ea1-0000-0000-000000000011', 'individual', 'cc', 'Oscar Ardila', 'La Palomera', NULL, true, 'Cabezotes trituradora, discos - La Palomera', '2025-12-05'),
    ('c2000001-0ea1-0000-0000-000000000012', 'individual', 'cc', 'Jose Bernardo Castro MarÃ­n', NULL, NULL, true, 'Remoledores', '2025-12-17'),
    ('c2000001-0ea1-0000-0000-000000000013', 'individual', 'cc', 'Parmenio RodrÃ­guez Rojas', NULL, NULL, true, 'Bola acero', '2025-12-13'),
    ('c2000001-0ea1-0000-0000-000000000014', 'individual', 'cc', 'Daniel Sierra', NULL, NULL, true, 'Trituradora completa', '2025-12-15'),
    ('c2000001-0ea1-0000-0000-000000000015', 'individual', 'cc', 'Jhon Morales', NULL, NULL, true, 'Bola 3" en volumen', '2025-12-11'),
    ('c2000001-0ea1-0000-0000-000000000016', 'business', 'nit', 'Cliente Sur de BolÃ­var', 'Sur de BolÃ­var', NULL, true, 'Pedido grande - Remoledores, trituradoras, bola, placas, sist. arrastre', '2025-12-12'),
    ('c2000001-0ea1-0000-0000-000000000017', 'individual', 'cc', 'Wilmer Ramos', NULL, NULL, true, 'Discos partidos', '2025-12-12'),
    ('c2000001-0ea1-0000-0000-000000000018', 'individual', 'cc', 'Carlos Arturo Zuluaga', NULL, NULL, true, 'Caja molino. CC: 98532099', '2025-12-11'),
    ('c2000001-0ea1-0000-0000-000000000019', 'individual', 'cc', 'Milton', NULL, NULL, true, 'Volantes', '2025-12-11'),
    ('c2000001-0ea1-0000-0000-000000000020', 'individual', 'cc', 'Ruben Dario Hernandez', NULL, NULL, true, 'Remoledores', '2025-12-09'),
    ('c2000001-0ea1-0000-0000-000000000021', 'business', 'nit', 'El Ceibo', 'El Ceibo', NULL, true, 'Chumaceras en volumen', '2025-12-09'),
    ('c2000001-0ea1-0000-0000-000000000022', 'individual', 'cc', 'Jairo DÃ­az', NULL, '3242069706', true, 'Volantes', '2025-12-04'),
    ('c2000001-0ea1-0000-0000-000000000023', 'individual', 'cc', 'Manuel Salazar', NULL, NULL, true, 'Tapas, ejes, chumaceras', '2025-12-04'),
    ('c2000001-0ea1-0000-0000-000000000024', 'business', 'nit', 'Riel', 'Riel', NULL, true, 'Riel de cubil al por mayor', '2025-12-02'),
    ('c2000001-0ea1-0000-0000-000000000025', 'individual', 'cc', 'Guille', NULL, NULL, true, 'Coches mineros', '2025-12-01'),
    ('c2000001-0ea1-0000-0000-000000000026', 'individual', 'cc', 'Alex Canalete', NULL, NULL, true, 'Tapas fundidas', '2025-12-01'),
    ('c2000001-0ea1-0000-0000-000000000027', 'individual', 'cc', 'Danfer', NULL, NULL, true, 'Discos', '2025-12-01')
ON CONFLICT DO NOTHING;


-- ============================================================
-- PASO 3: INSERTAR FACTURAS REALES - DICIEMBRE 2025
-- ============================================================
-- Serie REC = Recibos de venta (sin IVA formal)
-- Datos exactos de los recibos fÃ­sicos

INSERT INTO invoices (id, type, series, number, customer_id, customer_name, issue_date, subtotal, tax_rate, tax_amount, total, paid_amount, status, payment_method, notes, created_at)
VALUES
    -- === RECIBO 0312 â€” 01 dic === Guille - Coches mineros
    ('1acc0ea1-0000-0000-0000-000000000312', 'invoice', 'REC', '0312',
     'c2000001-0ea1-0000-0000-000000000025', 'Guille',
     '2025-12-01', 10541345, 0, 0, 10541345, 10541345, 'paid', 'cash',
     'Coches mineros x6 (8 fabricados, 2 pendientes entrega). Costo mat: $3,250,000. G=$7,291,000',
     '2025-12-01'),

    -- === RECIBO 0313 â€” 01 dic === Alex Canalete - Tapas 40"
    ('1acc0ea1-0000-0000-0000-000000000313', 'invoice', 'REC', '0313',
     'c2000001-0ea1-0000-0000-000000000026', 'Alex Canalete',
     '2025-12-01', 2652000, 0, 0, 2652000, 2652000, 'paid', 'cash',
     'Tapas de 40" c 1" x2. Costo mat: $1,591,200. G=$1,060,800',
     '2025-12-01'),

    -- === RECIBO 0314 â€” 01 dic === Danfer - Discos 52cm
    ('1acc0ea1-0000-0000-0000-000000000314', 'invoice', 'REC', '0314',
     'c2000001-0ea1-0000-0000-000000000027', 'Danfer',
     '2025-12-01', 700000, 0, 0, 700000, 700000, 'paid', 'cash',
     'Discos 52 cm c 1" x2. Costo mat: $421,824. G=$278,176',
     '2025-12-01'),

    -- === RECIBO 0315 â€” 02 dic === Riel - Riel de cubil
    ('1acc0ea1-0000-0000-0000-000000000315', 'invoice', 'REC', '0315',
     'c2000001-0ea1-0000-0000-000000000024', 'Riel',
     '2025-12-02', 14600000, 0, 0, 14600000, 14600000, 'paid', 'cash',
     'Riel de cubil x2,000. Costo: $9,200,000 + transporte $800,000 = $10,000,000. G=$4,600,000',
     '2025-12-02'),

    -- === RECIBO 0316 â€” 02 dic === (sin nombre) - Tarro breke minero
    ('1acc0ea1-0000-0000-0000-000000000316', 'invoice', 'REC', '0316',
     NULL, '(sin nombre)',
     '2025-12-02', 1800000, 0, 0, 1800000, 1800000, 'paid', 'cash',
     'Tarro para breke minero, tapa c 3/16. Costo mat: $542,502. G=$1,257,498',
     '2025-12-02'),

    -- === RECIBO 0317 â€” 04 dic === Jairo DÃ­az - Volante 18"
    ('1acc0ea1-0000-0000-0000-000000000317', 'invoice', 'REC', '0317',
     'c2000001-0ea1-0000-0000-000000000022', 'Jairo DÃ­az',
     '2025-12-04', 280000, 0, 0, 280000, 280000, 'paid', 'cash',
     'Volante de 18" x1. Costo mat: $180,000. G=$100,000. Cel: 3242069706',
     '2025-12-04'),

    -- === RECIBO 0320 â€” 04 dic === Wilmer Ramos Canaval - Remoledor 36"
    ('1acc0ea1-0000-0000-0000-000000000320', 'invoice', 'REC', '0320',
     'c2000001-0ea1-0000-0000-000000000003', 'Wilmer Ramos Canaval',
     '2025-12-04', 7850000, 0, 0, 7850000, 7850000, 'paid', 'cash',
     'Remoledor 36"Ã—110cm C1", eje 3"Ã—22cm, pie amigos 5Ã—40. Costo mat: $3,828,058. G=$4,021,942',
     '2025-12-04'),

    -- === RECIBO 0321 â€” 04 dic === Manuel Salazar - Tapas+Eje+Chumaceras
    ('1acc0ea1-0000-0000-0000-000000000321', 'invoice', 'REC', '0321',
     'c2000001-0ea1-0000-0000-000000000023', 'Manuel Salazar',
     '2025-12-04', 2091000, 0, 0, 2091000, 2091000, 'paid', 'cash',
     'Tapas Ã˜32" c media x2 ($874,000) + Eje 2"Ã—4m ($992,000) + Chumaceras x3 ($225,000). Costo mat: $1,055,748. G=$1,035,252',
     '2025-12-04'),

    -- === RECIBO 0322 â€” 05 dic === La Palomera - Discos 36"
    ('1acc0ea1-0000-0000-0000-000000000322', 'invoice', 'REC', '0322',
     'c2000001-0ea1-0000-0000-000000000011', 'La Palomera',
     '2025-12-05', 1610556, 0, 0, 1610556, 1610556, 'paid', 'cash',
     'Discos laterales c 3/4 36" x2. Costo mat: $966,334. G=$644,222. Cliente nombre corregido de Marta Escobar',
     '2025-12-05'),

    -- === RECIBO 0324 â€” 09 dic === Ruben Dario Hernandez - Remoledor 22"
    ('1acc0ea1-0000-0000-0000-000000000324', 'invoice', 'REC', '0324',
     'c2000001-0ea1-0000-0000-000000000020', 'Ruben Dario Hernandez',
     '2025-12-09', 2400000, 0, 0, 2400000, 1200000, 'partial', 'cash',
     'Remoledor 22" c1"Ã—50cm, tapas Ã˜47cm media, eje 1.5"Ã—17cm, boca 20Ã—20. Costo mat: $778,422. G=$1,621,578. ABONO $1,200,000. Entrega est. 24/dic',
     '2025-12-09'),

    -- === RECIBO 0325 â€” 09 dic === El Ceibo - Chumaceras
    ('1acc0ea1-0000-0000-0000-000000000325', 'invoice', 'REC', '0325',
     'c2000001-0ea1-0000-0000-000000000021', 'El Ceibo',
     '2025-12-09', 2580000, 0, 0, 2580000, 2580000, 'paid', 'cash',
     'Chumaceras x12 @ $215,000 c/u. Costo compra: $135,000Ã—12=$1,620,000. G=$960,000. CancelÃ³ 16/dic contra-entrega',
     '2025-12-09'),

    -- === RECIBO 0326 â€” 09 dic === nn - Bola 1"
    ('1acc0ea1-0000-0000-0000-000000000326', 'invoice', 'REC', '0326',
     NULL, 'nn',
     '2025-12-09', 100500, 0, 0, 100500, 100500, 'paid', 'cash',
     'Bola 1" x15 @ $6,700. Costo: 15Ã—$6,000=$90,000. G=$10,500',
     '2025-12-09'),

    -- === RECIBO 0327 â€” 11 dic === Carlos Arturo Zuluaga - Caja
    ('1acc0ea1-0000-0000-0000-000000000327', 'invoice', 'REC', '0327',
     'c2000001-0ea1-0000-0000-000000000018', 'Carlos Arturo Zuluaga',
     '2025-12-11', 3300000, 0, 0, 3300000, 3300000, 'paid', 'cash',
     'Caja x1. CC: 98532099. Costo mat: $688,652. G=$2,611,348',
     '2025-12-11'),

    -- === RECIBO 0328 â€” 11 dic === Milton - Volantes
    ('1acc0ea1-0000-0000-0000-000000000328', 'invoice', 'REC', '0328',
     'c2000001-0ea1-0000-0000-000000000019', 'Milton',
     '2025-12-11', 500000, 0, 0, 500000, 500000, 'paid', 'cash',
     'Volante 20" x1 ($320,000) + Volante 18" x1 ($180,000). Precios corregidos a mano. G=$80,000',
     '2025-12-11'),

    -- === RECIBO 0329 â€” 11 dic === Jhon Morales - Bola 3"
    ('1acc0ea1-0000-0000-0000-000000000329', 'invoice', 'REC', '0329',
     'c2000001-0ea1-0000-0000-000000000015', 'Jhon Morales',
     '2025-12-11', 3780000, 0, 0, 3780000, 3780000, 'paid', 'cash',
     'Bola 3" x600 @ $6,300. ImportaciÃ³n: 600Ã—$3,031=$1,818,600. G=$1,961,400',
     '2025-12-11'),

    -- === RECIBO 0330 â€” 12 dic === Cliente Sur de BolÃ­var - Pedido grande
    ('1acc0ea1-0000-0000-0000-000000000330', 'invoice', 'REC', '0330',
     'c2000001-0ea1-0000-0000-000000000016', 'Cliente Sur de BolÃ­var',
     '2025-12-12', 63000000, 0, 0, 63000000, 9770750, 'partial', 'cash',
     'PEDIDO GRANDE: Remoledor 42" ext cal 14mmÃ—150cm + Trituradora #2 + Bola x1600 + Remoledor 36"Ã—1m c1" + Sist arrastre 42" + Sist arrastre 36" + Placas 26.5Ã—93 x10. Costo total: ~$28,741,972. G=$34,258,028. ABONO $9,770,750 el 12/12',
     '2025-12-12'),

    -- === RECIBO 0331 â€” 12 dic === Wilmer Ramos - Discos 39"
    ('1acc0ea1-0000-0000-0000-000000000331', 'invoice', 'REC', '0331',
     'c2000001-0ea1-0000-0000-000000000017', 'Wilmer Ramos',
     '2025-12-12', 1800000, 0, 0, 1800000, 1800000, 'paid', 'cash',
     'Discos 39" c 3/4 partidos en 4 x2. Costo mat: $572,840. G=$1,227,160',
     '2025-12-12'),

    -- === RECIBO 0333 â€” 13 dic === Parmenio RodrÃ­guez Rojas - Bola
    ('1acc0ea1-0000-0000-0000-000000000333', 'invoice', 'REC', '0333',
     'c2000001-0ea1-0000-0000-000000000013', 'Parmenio RodrÃ­guez Rojas',
     '2025-12-13', 249500, 0, 0, 249500, 249500, 'paid', 'cash',
     'Bola Acero 15kg @ $6,900 ($103,500) + Bola ImportaciÃ³n 24kg @ $6,000 ($144,000). Costo: $90,000+$72,744=$162,744. G=$86,756',
     '2025-12-13'),

    -- === RECIBO 0334 â€” 15 dic === Elkin Mario Zapata - Placas
    ('1acc0ea1-0000-0000-0000-000000000334', 'invoice', 'REC', '0334',
     'c2000001-0ea1-0000-0000-000000000002', 'Elkin Mario Zapata',
     '2025-12-15', 1250000, 0, 0, 1250000, 1250000, 'paid', 'cash',
     'Placas 66Ã—24 c7/8 x9 + Placas 19Ã—24 c7/8 x2. Costo mat: $663,450. G=$586,550',
     '2025-12-15'),

    -- === RECIBO 0335 â€” 15 dic === Daniel Sierra - Trituradora #2
    ('1acc0ea1-0000-0000-0000-000000000335', 'invoice', 'REC', '0335',
     'c2000001-0ea1-0000-0000-000000000014', 'Daniel Sierra',
     '2025-12-15', 16000000, 0, 0, 16000000, 16000000, 'paid', 'cash',
     'Trituradora #2 completa. Costo mat: $8,150,000. G=$7,850,000',
     '2025-12-15'),

    -- === RECIBO 0336 â€” 16 dic === Oscar Ardila (La Palomera) - Cabezote trituradora
    ('1acc0ea1-0000-0000-0000-000000000336', 'invoice', 'REC', '0336',
     'c2000001-0ea1-0000-0000-000000000011', 'Oscar Ardila (La Palomera)',
     '2025-12-16', 6000000, 0, 0, 6000000, 3000000, 'partial', 'cash',
     'Cabezote trituradora c/cigÃ¼eÃ±al, balineras 22217-22317, sin placa Mn ni chumaceras. Costo mat: $1,611,362. G=$4,388,638. ABONO $3,000,000 el 15/dic',
     '2025-12-16'),

    -- === RECIBO 0338 â€” 17 dic === Jose B. Castro MarÃ­n - Remoledor 22"
    ('1acc0ea1-0000-0000-0000-000000000338', 'invoice', 'REC', '0338',
     'c2000001-0ea1-0000-0000-000000000012', 'Jose Bernardo Castro MarÃ­n',
     '2025-12-17', 1920000, 0, 0, 1920000, 1920000, 'paid', 'cash',
     'Remoledor 22" ext cal 7/8Ã—50cm. Costo mat: $784,313. G=$1,135,687',
     '2025-12-17'),

    -- === RECIBO 0339 â€” 17 dic === Guillermo Ortiz - Coches
    ('1acc0ea1-0000-0000-0000-000000000339', 'invoice', 'REC', '0339',
     'c2000001-0ea1-0000-0000-000000000009', 'Guillermo Ortiz',
     '2025-12-17', 8100000, 0, 0, 8100000, 8100000, 'paid', 'cash',
     'Coches x6 @ $1,350,000. Costo mat: ~$2,437,500. G=$5,662,500',
     '2025-12-17'),

    -- === RECIBO 0340 â€” 18 dic === William Giraldo - Tubo 22"
    ('1acc0ea1-0000-0000-0000-000000000340', 'invoice', 'REC', '0340',
     'c2000001-0ea1-0000-0000-000000000010', 'William Giraldo',
     '2025-12-18', 1500000, 0, 0, 1500000, 1500000, 'paid', 'cash',
     'Tubo 22" cal 7/8 Ã— 70cm. Costo mat: $681,199. G=$818,801',
     '2025-12-18'),

    -- === RECIBO 0341 â€” 18 dic === Jhon Jairo Arenas - Bola 1"
    ('1acc0ea1-0000-0000-0000-000000000341', 'invoice', 'REC', '0341',
     'c2000001-0ea1-0000-0000-000000000001', 'Jhon Jairo Arenas',
     '2025-12-18', 345000, 0, 0, 345000, 345000, 'paid', 'cash',
     'Bola 1" x50 @ $6,900. Costo mat: $300,000. G=$45,000',
     '2025-12-18'),

    -- === RECIBO 0342 â€” 24 dic === Buseta - Placas
    ('1acc0ea1-0000-0000-0000-000000000342', 'invoice', 'REC', '0342',
     'c2000001-0ea1-0000-0000-000000000008', 'Buseta',
     '2025-12-24', 1434000, 0, 0, 1434000, 1434000, 'paid', 'cash',
     'Placas 26Ã—92 c media x10. @ $143,400. Costo compra: 23.9Ã—$2,500Ã—10=$597,500. G=$836,500',
     '2025-12-24'),

    -- === RECIBO 0343 â€” 24 dic === Elkin Mario Zapata - Placas
    ('1acc0ea1-0000-0000-0000-000000000343', 'invoice', 'REC', '0343',
     'c2000001-0ea1-0000-0000-000000000002', 'Elkin Mario Zapata',
     '2025-12-24', 2000000, 0, 0, 2000000, 2000000, 'paid', 'cash',
     'Placas 20Ã—40 c7/8 x2 + Placas 29Ã—67 c7/8 x9. Costo mat: $826,602. G=$1,173,398',
     '2025-12-24'),

    -- === RECIBO 0344 â€” 24 dic === Reinaldo Mesa - Eclipas
    ('1acc0ea1-0000-0000-0000-000000000344', 'invoice', 'REC', '0344',
     'c2000001-0ea1-0000-0000-000000000004', 'Reinaldo Mesa',
     '2025-12-24', 1554000, 0, 0, 1554000, 1554000, 'paid', 'cash',
     'Eclipas (grapas/clips molino) x42 @ $37,000. G=$239,000',
     '2025-12-24'),

    -- === RECIBO 0345 â€” 24 dic === Benaimo Carro - Removedores
    ('1acc0ea1-0000-0000-0000-000000000345', 'invoice', 'REC', '0345',
     'c2000001-0ea1-0000-0000-000000000005', 'Benaimo Carro',
     '2025-12-24', 4120000, 0, 0, 4120000, 4120000, 'paid', 'cash',
     'Removedor 22" ext c/8" 50cm ($1,920,000) + Removedor 16"Ã—50cm contracarga 30"Ã—30 ($2,200,000). Costo mat: ~$738,097. G=~$2,414,000',
     '2025-12-24'),

    -- === RECIBO 0346 â€” 27 dic === Alex Caballero - Volantes
    ('1acc0ea1-0000-0000-0000-000000000346', 'invoice', 'REC', '0346',
     'c2000001-0ea1-0000-0000-000000000006', 'Alex Caballero',
     '2025-12-27', 1560000, 0, 0, 1560000, 1560000, 'paid', 'cash',
     'Volantes 18" x2 @ $380,000 ($760,000) + Volante 24" x1 ($800,000). G=$840,000',
     '2025-12-27'),

    -- === RECIBO 0347 â€” 29 dic === JuliÃ¡n A. LondoÃ±o - Placas
    ('1acc0ea1-0000-0000-0000-000000000347', 'invoice', 'REC', '0347',
     'c2000001-0ea1-0000-0000-000000000007', 'JuliÃ¡n AndrÃ©s LondoÃ±o',
     '2025-12-29', 658000, 0, 0, 658000, 658000, 'paid', 'cash',
     'Placas 27" SB 7/8 x4 @ $164,500. Costo: $291,235. G=$386,725',
     '2025-12-29'),

    -- === RECIBO 0349 â€” 31 dic === Jhon Jairo Arenas - Piezas + Caucho
    ('1acc0ea1-0000-0000-0000-000000000349', 'invoice', 'REC', '0349',
     'c2000001-0ea1-0000-0000-000000000001', 'Jhon Jairo Arenas',
     '2025-12-31', 3125000, 0, 0, 3125000, 3125000, 'paid', 'cash',
     'Piezas 26Ã—107 partidas en 2 x10 @ $280,000 ($2,800,000) + Caucho x25 @ $13,000 ($325,000). Costo: $7,204,803 total... G=$1,745,197',
     '2025-12-31')
ON CONFLICT (series, number) DO NOTHING;


-- ============================================================
-- PASO 4: INSERTAR ITEMS DE FACTURA (detalle por producto)
-- ============================================================

INSERT INTO invoice_items (invoice_id, product_name, description, quantity, unit_price, total_price)
VALUES
    -- REC-0312: Coches mineros
    ('1acc0ea1-0000-0000-0000-000000000312', 'Coches mineros', 'Coche minero artesanal', 6, 1756891, 10541345),
    -- REC-0313: Tapas 40"
    ('1acc0ea1-0000-0000-0000-000000000313', 'Tapas de 40" c 1"', 'Tapa circular Ã˜40" calibre 1"', 2, 1326000, 2652000),
    -- REC-0314: Discos 52cm
    ('1acc0ea1-0000-0000-0000-000000000314', 'Discos 52 cm c 1"', 'Disco circular 52cm calibre 1"', 2, 350000, 700000),
    -- REC-0315: Riel
    ('1acc0ea1-0000-0000-0000-000000000315', 'Riel de cubil', 'Riel de cubil', 2000, 7300, 14600000),
    -- REC-0316: Tarro breke
    ('1acc0ea1-0000-0000-0000-000000000316', 'Tarro para breke minero', 'Tarro breke minero, tapa c 3/16', 1, 1800000, 1800000),
    -- REC-0317: Volante 18"
    ('1acc0ea1-0000-0000-0000-000000000317', 'Volante de 18"', 'Volante fundido Ã˜18"', 1, 280000, 280000),
    -- REC-0320: Remoledor 36"
    ('1acc0ea1-0000-0000-0000-000000000320', 'Remoledor de 36"Ã—110cm C1"', 'Remoledor 36"Ã—110cm C1", eje 3"Ã—22cm, pie amigos 5Ã—40', 1, 7850000, 7850000),
    -- REC-0321: Tapas+Eje+Chumaceras
    ('1acc0ea1-0000-0000-0000-000000000321', 'Tapas Ã˜32" c media', 'Tapas diÃ¡metro 32" calibre media', 2, 437000, 874000),
    ('1acc0ea1-0000-0000-0000-000000000321', 'Eje 2"Ã—4 metros', 'Eje de 2" Ã— 4 metros', 4, 248000, 992000),
    ('1acc0ea1-0000-0000-0000-000000000321', 'Chumaceras', 'Chumacera estÃ¡ndar', 3, 75000, 225000),
    -- REC-0322: Discos 36"
    ('1acc0ea1-0000-0000-0000-000000000322', 'Discos laterales c 3/4 36"', 'Disco lateral cal 3/4 Ã˜36"', 2, 805278, 1610556),
    -- REC-0324: Remoledor 22"
    ('1acc0ea1-0000-0000-0000-000000000324', 'Remoledor de 22" c1"Ã—50cm', 'Remoledor 22" c1"Ã—50cm, tapas Ã˜47cm media, eje 1.5"Ã—17cm, boca 20Ã—20', 1, 2400000, 2400000),
    -- REC-0325: Chumaceras
    ('1acc0ea1-0000-0000-0000-000000000325', 'Chumaceras', 'Chumacera industrial', 12, 215000, 2580000),
    -- REC-0326: Bola 1"
    ('1acc0ea1-0000-0000-0000-000000000326', 'Bola 1"', 'Bola de acero 1"', 15, 6700, 100500),
    -- REC-0327: Caja
    ('1acc0ea1-0000-0000-0000-000000000327', 'Caja', 'Caja para molino', 1, 3300000, 3300000),
    -- REC-0328: Volantes
    ('1acc0ea1-0000-0000-0000-000000000328', 'Volante 20"', 'Volante fundido Ã˜20"', 1, 320000, 320000),
    ('1acc0ea1-0000-0000-0000-000000000328', 'Volante de 18"', 'Volante fundido Ã˜18"', 1, 180000, 180000),
    -- REC-0329: Bola 3"
    ('1acc0ea1-0000-0000-0000-000000000329', 'Bola 3"', 'Bola de acero 3" (importaciÃ³n)', 600, 6300, 3780000),
    -- REC-0330: Pedido grande Sur de BolÃ­var
    ('1acc0ea1-0000-0000-0000-000000000330', 'Remoledor continuo 42"', 'Remoledor 42" ext cal 14mmÃ—150cm, tapas atornilladas, bases metÃ¡licas tipo A, rod 6312, sist arrastre poleas/bandas', 1, 0, 0),
    ('1acc0ea1-0000-0000-0000-000000000330', 'Trituradora #2', 'Trituradora modelo #2 completa', 1, 0, 0),
    ('1acc0ea1-0000-0000-0000-000000000330', 'Bola', 'Bola de acero importaciÃ³n', 1600, 3031, 4849600),
    ('1acc0ea1-0000-0000-0000-000000000330', 'Remoledor 36"Ã—1m c1"', 'Remoledor 36"Ã—1m c1" emplacado metÃ¡lico cambio, chumaceras 2"', 1, 0, 0),
    ('1acc0ea1-0000-0000-0000-000000000330', 'Sistema arrastre 42"', 'Sistema de arrastre para remoledor 42"', 1, 0, 0),
    ('1acc0ea1-0000-0000-0000-000000000330', 'Sistema arrastre 36"', 'Sistema de arrastre para remoledor 36"', 1, 0, 0),
    ('1acc0ea1-0000-0000-0000-000000000330', 'Placas 26.5Ã—93 c 3/6 20mm', 'Placas de desgaste 26.5Ã—93 cal 3/6 20mm', 10, 0, 0),
    -- REC-0331: Discos 39"
    ('1acc0ea1-0000-0000-0000-000000000331', 'Discos 39" c 3/4 partidos en 4', 'Disco Ã˜39" cal 3/4 partido en 4', 2, 900000, 1800000),
    -- REC-0333: Bola mixta
    ('1acc0ea1-0000-0000-0000-000000000333', 'Bola Acero', 'Bola de acero nacional', 15, 6900, 103500),
    ('1acc0ea1-0000-0000-0000-000000000333', 'Bola ImportaciÃ³n', 'Bola de acero importaciÃ³n', 24, 6000, 144000),
    -- REC-0334: Placas Elkin
    ('1acc0ea1-0000-0000-0000-000000000334', 'Placas 66Ã—24 c 7/8', 'Placa de desgaste 66Ã—24 cal 7/8', 9, 0, 0),
    ('1acc0ea1-0000-0000-0000-000000000334', 'Placas 19Ã—24 c 7/8', 'Placa de desgaste 19Ã—24 cal 7/8', 2, 0, 0),
    -- REC-0335: Trituradora
    ('1acc0ea1-0000-0000-0000-000000000335', 'Trituradora #2', 'Trituradora modelo #2 completa', 1, 16000000, 16000000),
    -- REC-0336: Cabezote
    ('1acc0ea1-0000-0000-0000-000000000336', 'Cabezote trituradora', 'Cabezote trituradora c/cigÃ¼eÃ±al, balineras 22217-22317, sin placa Mn, sin chumaceras', 1, 6000000, 6000000),
    -- REC-0338: Remoledor
    ('1acc0ea1-0000-0000-0000-000000000338', 'Remoledor de 22" cal 7/8Ã—50cm', 'Remoledor 22" ext cal 7/8Ã—50cm largo', 1, 1920000, 1920000),
    -- REC-0339: Coches
    ('1acc0ea1-0000-0000-0000-000000000339', 'Coches', 'Coche minero', 6, 1350000, 8100000),
    -- REC-0340: Tubo
    ('1acc0ea1-0000-0000-0000-000000000340', 'Tubo de 22" cal 7/8 Ã— 70cm', 'Tubo 22" calibre 7/8 largo 70cm', 1, 1500000, 1500000),
    -- REC-0341: Bola
    ('1acc0ea1-0000-0000-0000-000000000341', 'Bola 1"', 'Bola de acero 1"', 50, 6900, 345000),
    -- REC-0342: Placas
    ('1acc0ea1-0000-0000-0000-000000000342', 'Placas 26Ã—92 c media', 'Placa de desgaste 26Ã—92 cal media', 10, 143400, 1434000),
    -- REC-0343: Placas Elkin 2
    ('1acc0ea1-0000-0000-0000-000000000343', 'Placas 20Ã—40 c 7/8', 'Placa de desgaste 20Ã—40 cal 7/8', 2, 0, 0),
    ('1acc0ea1-0000-0000-0000-000000000343', 'Placas 29Ã—67 c 7/8', 'Placa de desgaste 29Ã—67 cal 7/8', 9, 0, 0),
    -- REC-0344: Eclipas
    ('1acc0ea1-0000-0000-0000-000000000344', 'Eclipas', 'Eclipa (grapa/clip) para molino', 42, 37000, 1554000),
    -- REC-0345: Removedores
    ('1acc0ea1-0000-0000-0000-000000000345', 'Removedor 22" ext c/8" 50cm', 'Removedor Ã˜22" exterior calibre 8" largo 50cm', 1, 1920000, 1920000),
    ('1acc0ea1-0000-0000-0000-000000000345', 'Removedor 16"Ã—50cm contracarga 30"Ã—30', 'Removedor 16"Ã—50cm con contracarga 30"Ã—30', 1, 2200000, 2200000),
    -- REC-0346: Volantes
    ('1acc0ea1-0000-0000-0000-000000000346', 'Volantes de 18"', 'Volante fundido Ã˜18"', 2, 380000, 760000),
    ('1acc0ea1-0000-0000-0000-000000000346', 'Volante de 24"', 'Volante fundido Ã˜24"', 1, 800000, 800000),
    -- REC-0347: Placas
    ('1acc0ea1-0000-0000-0000-000000000347', 'Placas de 27" SB 7/8', 'Placa 27" SB cal 7/8', 4, 164500, 658000),
    -- REC-0349: Piezas + Caucho
    ('1acc0ea1-0000-0000-0000-000000000349', 'Piezas 26Ã—107 partidas en 2', 'Pieza fundida/cortada 26Ã—107', 10, 280000, 2800000),
    ('1acc0ea1-0000-0000-0000-000000000349', 'Caucho', 'Caucho industrial', 25, 13000, 325000);


-- ============================================================
-- PASO 5: VERIFICACIÃ“N
-- ============================================================
SELECT '=== DATOS REALES CARGADOS ===' AS info;

SELECT 'Clientes reales' AS tabla, COUNT(*) AS registros 
FROM customers WHERE id::text LIKE 'c2000001-0ea1-%'
UNION ALL
SELECT 'Facturas reales (REC)', COUNT(*) 
FROM invoices WHERE series = 'REC'
UNION ALL
SELECT 'Items de factura', COUNT(*) 
FROM invoice_items ii JOIN invoices i ON ii.invoice_id = i.id WHERE i.series = 'REC';

-- Resumen financiero
SELECT 
    'DICIEMBRE 2025' AS periodo,
    COUNT(*) AS num_recibos,
    SUM(total) AS total_ventas,
    SUM(paid_amount) AS total_cobrado,
    SUM(total - paid_amount) AS total_pendiente
FROM invoices WHERE series = 'REC';

-- Top clientes por ventas
SELECT 
    customer_name,
    COUNT(*) AS num_facturas,
    SUM(total) AS total_compras
FROM invoices 
WHERE series = 'REC'
GROUP BY customer_name
ORDER BY total_compras DESC
LIMIT 10;

-- CategorÃ­as de producto mÃ¡s vendidas (basado en items)
SELECT 
    CASE 
        WHEN product_name ILIKE '%remoledor%' OR product_name ILIKE '%removedor%' THEN 'Remoledores/Removedores'
        WHEN product_name ILIKE '%trituradora%' OR product_name ILIKE '%cabezote%' THEN 'Trituradoras'
        WHEN product_name ILIKE '%placa%' THEN 'Placas de desgaste'
        WHEN product_name ILIKE '%bola%' THEN 'Bola de acero'
        WHEN product_name ILIKE '%volante%' THEN 'Volantes'
        WHEN product_name ILIKE '%disco%' THEN 'Discos'
        WHEN product_name ILIKE '%tapa%' THEN 'Tapas'
        WHEN product_name ILIKE '%coche%' THEN 'Coches mineros'
        WHEN product_name ILIKE '%chumacera%' THEN 'Chumaceras'
        WHEN product_name ILIKE '%eje%' THEN 'Ejes'
        WHEN product_name ILIKE '%caja%' THEN 'Cajas'
        WHEN product_name ILIKE '%tubo%' THEN 'Tubos'
        WHEN product_name ILIKE '%riel%' THEN 'Riel'
        WHEN product_name ILIKE '%sistema%' THEN 'Sistemas de arrastre'
        ELSE 'Otros'
    END AS categoria,
    COUNT(*) AS items,
    SUM(total_price) AS total_ventas
FROM invoice_items ii
JOIN invoices i ON ii.invoice_id = i.id
WHERE i.series = 'REC'
GROUP BY categoria
ORDER BY total_ventas DESC;

COMMIT;
