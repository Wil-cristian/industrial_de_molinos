-- =====================================================
-- DATOS DE PRUEBA - Industrial de Molinos
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- =====================================================
-- CLIENTES DE PRUEBA
-- =====================================================
INSERT INTO customers (type, document_type, document_number, name, trade_name, address, phone, email, credit_limit, current_balance) VALUES
    ('business', 'ruc', '20123456789', 'Minera Buenaventura S.A.C.', 'Buenaventura', 'Av. Las Begonias 415, San Isidro, Lima', '01-4151500', 'compras@buenaventura.com', 100000.00, 25000.00),
    ('business', 'ruc', '20234567890', 'Compañía Minera Antamina S.A.', 'Antamina', 'Av. El Derby 055, Santiago de Surco, Lima', '01-2170500', 'ventas@antamina.com', 150000.00, 0.00),
    ('business', 'ruc', '20345678901', 'Southern Peru Copper Corporation', 'Southern Copper', 'Av. Caminos del Inca 171, Surco, Lima', '01-5128000', 'adquisiciones@southernperu.com', 200000.00, 45000.00),
    ('business', 'ruc', '20456789012', 'Cementos Pacasmayo S.A.A.', 'Pacasmayo', 'Calle La Colonia 150, Surquillo, Lima', '01-3171000', 'compras@pacasmayo.com.pe', 80000.00, 12000.00),
    ('business', 'ruc', '20567890123', 'Volcán Compañía Minera S.A.A.', 'Volcán', 'Av. Manuel Olguín 373, Surco, Lima', '01-4161600', 'proveedores@volcan.com.pe', 120000.00, 0.00),
    ('individual', 'dni', '12345678', 'Juan Carlos Mendoza López', NULL, 'Jr. Los Pinos 234, La Molina, Lima', '987654321', 'jcmendoza@gmail.com', 15000.00, 5000.00),
    ('business', 'ruc', '20678901234', 'Ferreyros S.A.', 'Ferreyros', 'Jr. Cristóbal de Peralta Norte 820, Surco', '01-6261000', 'compras@ferreyros.com.pe', 90000.00, 18000.00),
    ('business', 'ruc', '20789012345', 'Komatsu-Mitsui S.A.', 'Komatsu', 'Av. Argentina 4453, Callao', '01-5775000', 'repuestos@kmmp.com.pe', 75000.00, 0.00)
ON CONFLICT (document_number) DO NOTHING;

-- =====================================================
-- PRODUCTOS DE PRUEBA
-- =====================================================

-- Primero obtenemos los IDs de las categorías
DO $$
DECLARE
    cat_molinos UUID;
    cat_repuestos UUID;
    cat_servicios UUID;
    cat_materiales UUID;
BEGIN
    SELECT id INTO cat_molinos FROM categories WHERE name = 'Molinos de Bolas' LIMIT 1;
    SELECT id INTO cat_repuestos FROM categories WHERE name = 'Repuestos' LIMIT 1;
    SELECT id INTO cat_servicios FROM categories WHERE name = 'Servicios' LIMIT 1;
    SELECT id INTO cat_materiales FROM categories WHERE name = 'Materiales' LIMIT 1;

    -- Insertar productos
    INSERT INTO products (code, name, description, category_id, unit_price, cost_price, stock, min_stock, unit) VALUES
        ('MOL-3X4', 'Molino de Bolas 3x4 pies', 'Molino de bolas pequeño para laboratorio o pequeña producción. Incluye motor y base.', cat_molinos, 45000.00, 32000.00, 2, 1, 'UND'),
        ('MOL-4X6', 'Molino de Bolas 4x6 pies', 'Molino de bolas mediano para producción industrial. Capacidad 5-10 TPH.', cat_molinos, 85000.00, 60000.00, 1, 1, 'UND'),
        ('MOL-5X8', 'Molino de Bolas 5x8 pies', 'Molino de bolas grande para alta producción. Capacidad 15-25 TPH.', cat_molinos, 150000.00, 105000.00, 0, 1, 'UND'),
        ('REP-CIL-01', 'Cilindro para Molino 4x6', 'Cilindro de reemplazo fabricado en acero A36 de 16mm', cat_repuestos, 18500.00, 12000.00, 3, 2, 'UND'),
        ('REP-TAP-01', 'Tapa Frontal Molino 4x6', 'Tapa frontal con bocamasa, acero A36 de 25mm', cat_repuestos, 8500.00, 5500.00, 5, 3, 'UND'),
        ('REP-EJE-01', 'Eje Principal Molino 4x6', 'Eje principal SAE 4140, tratamiento térmico incluido', cat_repuestos, 12000.00, 7800.00, 2, 2, 'UND'),
        ('REP-PIN-01', 'Piñón de Transmisión', 'Piñón helicoidal para molino, acero SAE 4340', cat_repuestos, 6500.00, 4200.00, 8, 5, 'UND'),
        ('REP-COR-01', 'Corona Dentada Molino', 'Corona dentada fundición nodular, 72 dientes', cat_repuestos, 22000.00, 14500.00, 1, 1, 'UND'),
        ('SRV-MANT-01', 'Servicio Mantenimiento Preventivo', 'Mantenimiento preventivo completo, incluye inspección y lubricación', cat_servicios, 3500.00, 2000.00, 100, 10, 'SRV'),
        ('SRV-INST-01', 'Servicio de Instalación', 'Instalación y puesta en marcha de molino', cat_servicios, 8000.00, 5000.00, 50, 5, 'SRV'),
        ('SRV-REP-01', 'Servicio de Reparación', 'Reparación general de molino, mano de obra', cat_servicios, 5000.00, 3000.00, 50, 5, 'SRV'),
        ('MAT-LAM-12', 'Lámina Acero A36 12mm', 'Lámina de acero A36, espesor 12mm, por kg', cat_materiales, 4.80, 3.80, 5000, 1000, 'KG'),
        ('MAT-LAM-19', 'Lámina Acero A36 19mm', 'Lámina de acero A36, espesor 19mm, por kg', cat_materiales, 5.00, 4.00, 3500, 800, 'KG'),
        ('MAT-EJE-4140', 'Barra Acero SAE 4140', 'Barra redonda SAE 4140 para ejes, por kg', cat_materiales, 8.00, 6.50, 2000, 500, 'KG'),
        ('MAT-BRON-40', 'Bronce SAE 40', 'Bronce SAE 40 para bocamasas, por kg', cat_materiales, 25.00, 20.00, 500, 100, 'KG')
    ON CONFLICT (code) DO NOTHING;
END $$;

-- =====================================================
-- COTIZACIONES DE PRUEBA
-- =====================================================
INSERT INTO quotations (number, date, valid_until, customer_id, customer_name, customer_document, status, materials_cost, labor_cost, labor_hours, subtotal, profit_margin, profit_amount, total, total_weight, notes) 
SELECT 
    'COT-2025-0001',
    '2025-12-01',
    '2025-12-31',
    c.id,
    c.name,
    c.document_number,
    'Enviada',
    45000.00,
    8000.00,
    120,
    53000.00,
    20.00,
    10600.00,
    63600.00,
    3200.50,
    'Cotización para molino 4x6 pies completo con instalación'
FROM customers c WHERE c.document_number = '20123456789'
ON CONFLICT (number) DO NOTHING;

INSERT INTO quotations (number, date, valid_until, customer_id, customer_name, customer_document, status, materials_cost, labor_cost, labor_hours, subtotal, profit_margin, profit_amount, total, total_weight, notes) 
SELECT 
    'COT-2025-0002',
    '2025-12-05',
    '2026-01-05',
    c.id,
    c.name,
    c.document_number,
    'Borrador',
    85000.00,
    15000.00,
    200,
    100000.00,
    20.00,
    20000.00,
    120000.00,
    5500.00,
    'Molino 5x8 pies para planta de procesamiento'
FROM customers c WHERE c.document_number = '20234567890'
ON CONFLICT (number) DO NOTHING;

INSERT INTO quotations (number, date, valid_until, customer_id, customer_name, customer_document, status, materials_cost, labor_cost, labor_hours, subtotal, profit_margin, profit_amount, total, total_weight, notes) 
SELECT 
    'COT-2025-0003',
    '2025-11-20',
    '2025-12-20',
    c.id,
    c.name,
    c.document_number,
    'Aprobada',
    22000.00,
    3500.00,
    40,
    25500.00,
    20.00,
    5100.00,
    30600.00,
    850.00,
    'Repuestos para mantenimiento programado'
FROM customers c WHERE c.document_number = '20345678901'
ON CONFLICT (number) DO NOTHING;

INSERT INTO quotations (number, date, valid_until, customer_id, customer_name, customer_document, status, materials_cost, labor_cost, labor_hours, subtotal, profit_margin, profit_amount, total, total_weight, notes) 
SELECT 
    'COT-2025-0004',
    '2025-10-15',
    '2025-11-15',
    c.id,
    c.name,
    c.document_number,
    'Vencida',
    12000.00,
    2000.00,
    30,
    14000.00,
    20.00,
    2800.00,
    16800.00,
    420.00,
    'Fabricación de eje principal'
FROM customers c WHERE c.document_number = '20456789012'
ON CONFLICT (number) DO NOTHING;

-- =====================================================
-- FACTURAS DE PRUEBA
-- =====================================================
INSERT INTO invoices (type, series, number, customer_id, customer_name, customer_document, customer_address, issue_date, due_date, subtotal, tax_rate, tax_amount, total, paid_amount, status, payment_method, notes)
SELECT 
    'invoice',
    'F001',
    '00000001',
    c.id,
    c.name,
    c.document_number,
    c.address,
    '2025-12-01',
    '2025-12-31',
    25423.73,
    18.00,
    4576.27,
    30000.00,
    30000.00,
    'paid',
    'transfer',
    'Venta de repuestos - Pago completo'
FROM customers c WHERE c.document_number = '20123456789'
ON CONFLICT (series, number) DO NOTHING;

INSERT INTO invoices (type, series, number, customer_id, customer_name, customer_document, customer_address, issue_date, due_date, subtotal, tax_rate, tax_amount, total, paid_amount, status, payment_method, notes)
SELECT 
    'invoice',
    'F001',
    '00000002',
    c.id,
    c.name,
    c.document_number,
    c.address,
    '2025-12-05',
    '2026-01-05',
    42372.88,
    18.00,
    7627.12,
    50000.00,
    25000.00,
    'partial',
    'transfer',
    'Adelanto molino 4x6 - 50% inicial'
FROM customers c WHERE c.document_number = '20234567890'
ON CONFLICT (series, number) DO NOTHING;

INSERT INTO invoices (type, series, number, customer_id, customer_name, customer_document, customer_address, issue_date, due_date, subtotal, tax_rate, tax_amount, total, paid_amount, status, notes)
SELECT 
    'invoice',
    'F001',
    '00000003',
    c.id,
    c.name,
    c.document_number,
    c.address,
    '2025-12-08',
    '2026-01-08',
    10169.49,
    18.00,
    1830.51,
    12000.00,
    0.00,
    'issued',
    'Servicio de mantenimiento preventivo'
FROM customers c WHERE c.document_number = '20345678901'
ON CONFLICT (series, number) DO NOTHING;

INSERT INTO invoices (type, series, number, customer_id, customer_name, customer_document, customer_address, issue_date, due_date, subtotal, tax_rate, tax_amount, total, paid_amount, status, notes)
SELECT 
    'invoice',
    'F001',
    '00000004',
    c.id,
    c.name,
    c.document_number,
    c.address,
    '2025-11-15',
    '2025-12-01',
    6355.93,
    18.00,
    1144.07,
    7500.00,
    0.00,
    'overdue',
    'Venta de materiales - VENCIDA'
FROM customers c WHERE c.document_number = '20456789012'
ON CONFLICT (series, number) DO NOTHING;

INSERT INTO invoices (type, series, number, customer_id, customer_name, customer_document, customer_address, issue_date, due_date, subtotal, tax_rate, tax_amount, total, paid_amount, status, payment_method, notes)
SELECT 
    'invoice',
    'F001',
    '00000005',
    c.id,
    c.name,
    c.document_number,
    c.address,
    '2025-12-09',
    '2026-01-09',
    63559.32,
    18.00,
    11440.68,
    75000.00,
    75000.00,
    'paid',
    'transfer',
    'Molino 3x4 completo - Pagado'
FROM customers c WHERE c.document_number = '20567890123'
ON CONFLICT (series, number) DO NOTHING;

-- =====================================================
-- VERIFICACIÓN FINAL
-- =====================================================
-- Mostrar resumen de datos insertados
SELECT 'Clientes' as tabla, COUNT(*) as registros FROM customers
UNION ALL
SELECT 'Productos', COUNT(*) FROM products
UNION ALL
SELECT 'Cotizaciones', COUNT(*) FROM quotations
UNION ALL
SELECT 'Facturas', COUNT(*) FROM invoices
UNION ALL
SELECT 'Materiales', COUNT(*) FROM material_prices
UNION ALL
SELECT 'Categorías', COUNT(*) FROM categories;
