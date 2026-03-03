-- =====================================================
-- MIGRACIÓN 044: Nómina 1era Quincena Febrero 2026
-- Industrial de Molinos - Supía, Caldas, Colombia
-- =====================================================
-- Período: 01-Feb-2026 al 15-Feb-2026
-- Datos tomados del cuaderno de horas extras
-- Total HE según cuaderno: $10,958,100
-- =====================================================

-- =====================================================
-- 1. CREAR PERÍODO DE NÓMINA: 1era Quincena Febrero 2026
-- =====================================================
INSERT INTO payroll_periods (
    period_type, period_number, year, 
    start_date, end_date, payment_date, 
    status, notes
) VALUES (
    'quincenal', 3, 2026,  -- Q3 del año (Ene Q1, Ene Q2, Feb Q1)
    '2026-02-01', '2026-02-15', '2026-02-15',
    'abierto', '1era quincena de Febrero 2026'
) ON CONFLICT (period_type, period_number, year) DO NOTHING;

-- =====================================================
-- 2. CREAR REGISTROS DE NÓMINA POR EMPLEADO
-- Con las horas extras de la quincena
-- =====================================================
-- Nota: Los montos de HE incluyen el total pagado por 
-- horas extras durante la quincena del 01-15 Feb 2026.
-- No todos los empleados hicieron HE.
-- =====================================================

-- Barón (EMP002) - HE: $1,450,000
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 1450000, 0, (e.salary / 2) + 1450000, 'borrador',
       'HE quincena: $1,450,000. Días: 02-14 Feb.'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP002' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

-- Detalle HE Barón
INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 1450000, 1450000, 'HE 1era quincena Feb 2026. Días: 02-14.'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP002' AND pp.period_number = 3 AND pp.year = 2026;

-- Gabriel (EMP008) - HE: $1,900,000
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 1900000, 0, (e.salary / 2) + 1900000, 'borrador',
       'HE quincena: $1,900,000'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP008' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 1900000, 1900000, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP008' AND pp.period_number = 3 AND pp.year = 2026;

-- Franklin (EMP009) - HE: $1,050,000
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 1050000, 0, (e.salary / 2) + 1050000, 'borrador',
       'HE quincena: $1,050,000'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP009' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 1050000, 1050000, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP009' AND pp.period_number = 3 AND pp.year = 2026;

-- Carlos (EMP011) - HE: $1,250,000
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 1250000, 0, (e.salary / 2) + 1250000, 'borrador',
       'HE quincena: $1,250,000'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP011' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 1250000, 1250000, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP011' AND pp.period_number = 3 AND pp.year = 2026;

-- Jhon Davio (EMP012) - HE: $800,000
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 800000, 0, (e.salary / 2) + 800000, 'borrador',
       'HE quincena: $800,000'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP012' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 800000, 800000, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP012' AND pp.period_number = 3 AND pp.year = 2026;

-- Chirry (EMP001) - HE: $1,852,000
-- Chirry es por día ($141,000/día), su base es por días trabajados
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, 0, 13, 1852000, 0, 1852000, 'borrador',
       'HE quincena: $1,852,000. Chirry cobra por día, no tiene base quincenal fija.'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP001' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 1852000, 1852000, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP001' AND pp.period_number = 3 AND pp.year = 2026;

-- Daniel Gañán (EMP004) - HE: $1,057,900
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 1057900, 0, (e.salary / 2) + 1057900, 'borrador',
       'HE quincena: $1,057,900'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP004' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 1057900, 1057900, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP004' AND pp.period_number = 3 AND pp.year = 2026;

-- Sebastián (EMP014) - HE: $780,600
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 780600, 0, (e.salary / 2) + 780600, 'borrador',
       'HE quincena: $780,600'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP014' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 780600, 780600, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP014' AND pp.period_number = 3 AND pp.year = 2026;

-- Wilmer (EMP010) - HE: $1,100,000
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 1100000, 0, (e.salary / 2) + 1100000, 'borrador',
       'HE quincena: $1,100,000'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP010' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 1100000, 1100000, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP010' AND pp.period_number = 3 AND pp.year = 2026;

-- Alejandro Súper (EMP013) - HE: $1,098,600
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, (e.salary / 2) + 1098600, 0, (e.salary / 2) + 1098600, 'borrador',
       'HE quincena: $1,098,600'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP013' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 1098600, 1098600, 'HE 1era quincena Feb 2026'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP013' AND pp.period_number = 3 AND pp.year = 2026;

-- Alejandro Nuevo (EMP015) - HE: $199,600 (solo 4 días, inició 09 Feb)
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, 0, 4, 199600, 0, 199600, 'borrador',
       'HE quincena: $199,600. Empleado nuevo, solo 4 días (09-14 Feb). Base = 0 porque no completó quincena.'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP015' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

INSERT INTO payroll_details (payroll_id, concept_id, concept_code, concept_name, type, quantity, unit_value, amount, notes)
SELECT p.id, pc.id, 'HORA_EXTRA', 'Hora Extra', 'ingreso', 1, 199600, 199600, 'HE 1era quincena Feb 2026. Solo 4 días (inició 09 Feb).'
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_concepts pc ON pc.code = 'HORA_EXTRA'
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE e.code = 'EMP015' AND pp.period_number = 3 AND pp.year = 2026;

-- =====================================================
-- 3. EMPLEADOS SIN HORAS EXTRAS ESTA QUINCENA
-- Crear registros de nómina solo con base (sin HE)
-- =====================================================

-- Alejo (EMP003) - Sin HE
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, e.salary / 2, 0, e.salary / 2, 'borrador',
       'Sin horas extras esta quincena'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP003' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

-- Esteban (EMP005) - Sin HE
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, e.salary / 2, 0, e.salary / 2, 'borrador',
       'Sin horas extras esta quincena'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP005' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

-- Moricet (EMP006) - Sin HE
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, e.salary / 2, 0, e.salary / 2, 'borrador',
       'Sin horas extras esta quincena'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP006' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

-- Jhoan (EMP007) - Sin HE
INSERT INTO payroll (employee_id, period_id, base_salary, days_worked, total_earnings, total_deductions, net_pay, status, notes)
SELECT e.id, pp.id, e.salary / 2, 13, e.salary / 2, 0, e.salary / 2, 'borrador',
       'Sin horas extras esta quincena'
FROM employees e, payroll_periods pp
WHERE e.code = 'EMP007' AND pp.period_type = 'quincenal' AND pp.period_number = 3 AND pp.year = 2026
ON CONFLICT (employee_id, period_id) DO NOTHING;

-- =====================================================
-- 4. VERIFICACIÓN
-- =====================================================

-- Resumen de horas extras por empleado
SELECT 
    e.code, 
    e.first_name,
    p.base_salary,
    COALESCE(pd.amount, 0) AS horas_extras,
    p.total_earnings,
    p.net_pay,
    p.days_worked,
    p.notes
FROM payroll p
JOIN employees e ON p.employee_id = e.id
JOIN payroll_periods pp ON p.period_id = pp.id
LEFT JOIN payroll_details pd ON pd.payroll_id = p.id AND pd.concept_code = 'HORA_EXTRA'
WHERE pp.period_number = 3 AND pp.year = 2026
ORDER BY e.code;

-- Total HE de la quincena
SELECT 
    SUM(pd.amount) AS total_horas_extras,
    COUNT(DISTINCT p.employee_id) AS empleados_con_he
FROM payroll p
JOIN payroll_periods pp ON p.period_id = pp.id
JOIN payroll_details pd ON pd.payroll_id = p.id AND pd.concept_code = 'HORA_EXTRA'
WHERE pp.period_number = 3 AND pp.year = 2026;

-- Total nómina de la quincena
SELECT 
    COUNT(*) AS total_empleados,
    SUM(base_salary) AS total_base,
    SUM(total_earnings) AS total_bruto,
    SUM(total_deductions) AS total_descuentos,
    SUM(net_pay) AS total_neto
FROM payroll p
JOIN payroll_periods pp ON p.period_id = pp.id
WHERE pp.period_number = 3 AND pp.year = 2026;

-- =====================================================
-- SIGUIENTE PASO: Insertar adelantos (DESC_ADELANTO)
-- para completar los descuentos de la quincena
-- =====================================================
