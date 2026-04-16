-- =====================================================
-- MIGRACIÓN 043: Insertar empleados reales
-- Industrial de Molinos - Supía, Caldas, Colombia
-- =====================================================
-- Datos tomados de registros del cuaderno (pág. 49)
-- Salarios mensuales en COP
-- Bono por asistencia: $300,000/mes ($150,000/quincena) si no faltó
-- Tasa horaria legal Colombia: salario / 240
-- =====================================================

-- =====================================================
-- 1. AGREGAR CONCEPTO DE BONO POR ASISTENCIA
-- =====================================================
INSERT INTO payroll_concepts (code, name, type, category, is_percentage, default_value, description) VALUES
('BONO_ASISTENCIA', 'Bono por Asistencia', 'ingreso', 'bonificacion', FALSE, 150000, 
 'Bono de $150,000 por quincena ($300,000/mes) si el empleado no faltó durante la quincena')
ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- 2. INSERTAR EMPLEADOS
-- =====================================================
-- Nota: Los nombres son los que aparecen en el cuaderno.
-- Algunos son apodos o solo apellidos.
-- Actualizar con nombres completos y cédulas reales.
-- document_type = 'cc' (cédula de ciudadanía - Colombia)
-- =====================================================

INSERT INTO employees (
    code, first_name, last_name, 
    document_type, document_number,
    position, department, 
    salary, hourly_rate, 
    hire_date, is_active, notes
) VALUES

-- 1. Chirry - Pago por día: $141,000/día
('EMP001', 'Chirry', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 0, 17625.00,  -- Pago por día $141,000, hora = $141,000/8
 CURRENT_DATE, TRUE, 
 'Pago por día: $141,000. No tiene salario mensual fijo. Calcular por días trabajados.'),

-- 2. Barón - Salario mensual: $3,200,000
('EMP002', 'Barón', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 3200000, 13333.33,  -- $3,200,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $3,200,000'),

-- 3. Alejo - Salario mensual: $2,200,000
('EMP003', 'Alejo', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 2200000, 9166.67,  -- $2,200,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $2,200,000'),

-- 4. Daniel Gañán - Salario mensual: $2,200,000
-- Detalle del cuaderno: Quincena $861,500, Día $59,450, Hora $7,150
-- Ingresó: Sep 3
('EMP004', 'Daniel', 'Gañán', 
 'cc', NULL,
 'Operario', 'Producción', 
 2200000, 9166.67,  -- Lista dice $2,200,000 / 240
 '2025-09-03', TRUE, 
 'Salario lista: $2,200,000. Detalle cuaderno: Quincena $861,500, Día $59,450, Hora $7,150. Ingresó Sep 3.'),

-- 5. Esteban - Salario mensual: $2,000,000
('EMP005', 'Esteban', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 2000000, 8333.33,  -- $2,000,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $2,000,000'),

-- 6. Moricet - Salario mensual: $2,300,000
('EMP006', 'Moricet', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 2300000, 9583.33,  -- $2,300,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $2,300,000'),

-- 7. Jhoan - Salario mensual: $3,000,000
('EMP007', 'Jhoan', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 3000000, 12500.00,  -- $3,000,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $3,000,000. Cuaderno dice "quincenal" - verificar si es mensual o quincenal.'),

-- 8. Gabriel - Salario mensual: $4,000,000
('EMP008', 'Gabriel', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 4000000, 16666.67,  -- $4,000,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $4,000,000. Salario más alto del equipo.'),

-- 9. Franklin - Salario mensual: $2,200,000
('EMP009', 'Franklin', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 2200000, 9166.67,  -- $2,200,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $2,200,000'),

-- 10. Wilmer - Salario mensual: $2,000,000
('EMP010', 'Wilmer', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 2000000, 8333.33,  -- $2,000,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $2,000,000'),

-- 11. Carlos - Salario mensual: $2,200,000
('EMP011', 'Carlos', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 2200000, 9166.67,  -- $2,200,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $2,200,000'),

-- 12. Jhon Davio - Salario mensual: $1,600,000
('EMP012', 'Jhon Davio', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 1600000, 6666.67,  -- $1,600,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $1,600,000. Salario más bajo del equipo (por debajo del SMLV - verificar).'),

-- 13. Alejandro "Súper" - Salario mensual: $2,000,000
('EMP013', 'Alejandro', 'Súper', 
 'cc', NULL,
 'Operario', 'Producción', 
 2000000, 8333.33,  -- $2,000,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $2,000,000. Apodo: Súper. Diferenciar de Alejandro Nuevo (EMP015).'),

-- 14. Sebastián - Salario mensual: $2,000,000 (SMLV)
('EMP014', 'Sebastián', '(por confirmar)', 
 'cc', NULL,
 'Operario', 'Producción', 
 2000000, 8333.33,  -- $2,000,000 / 240
 CURRENT_DATE, TRUE, 
 'Salario mensual: $2,000,000 (SMLV). Re-agregado a la lista.'),

-- 15. Alejandro Nuevo - Salario mensual: $2,000,000 (estimado)
-- Inició el 09 de febrero 2026
('EMP015', 'Alejandro', 'Nuevo', 
 'cc', NULL,
 'Operario', 'Producción', 
 2000000, 8333.33,  -- $2,000,000 / 240 (estimado, verificar)
 '2026-02-09', TRUE, 
 'Empleado nuevo. Inició 09 Feb 2026. Apodo: Nuevo. Verificar salario real.');

-- =====================================================
-- 3. VERIFICACIÓN
-- =====================================================
SELECT 
    code, 
    first_name || ' ' || last_name AS nombre_completo,
    salary AS salario_mensual,
    hourly_rate AS tasa_hora,
    CASE WHEN salary > 0 
         THEN ROUND(salary / 30, 0) 
         ELSE hourly_rate * 8 
    END AS valor_dia,
    notes
FROM employees 
ORDER BY code;

-- =====================================================
-- RESUMEN DE SALARIOS
-- =====================================================
SELECT 
    COUNT(*) AS total_empleados,
    SUM(salary) AS nomina_mensual_total,
    ROUND(AVG(CASE WHEN salary > 0 THEN salary END), 0) AS salario_promedio,
    MIN(CASE WHEN salary > 0 THEN salary END) AS salario_minimo,
    MAX(salary) AS salario_maximo
FROM employees 
WHERE is_active = TRUE;

-- =====================================================
-- DATOS PENDIENTES POR COMPLETAR:
-- =====================================================
-- 1. Apellidos reales de todos (marcados como "por confirmar")
-- 2. Números de cédula (document_number)
-- 3. Fechas reales de ingreso (hire_date)
-- 4. Cargos específicos si hay diferencia (position)
-- 5. Teléfonos, direcciones, contacto emergencia
-- 6. Datos bancarios (bank_name, bank_account)
-- 7. Verificar salario de Jhon Davio ($1,600,000 < SMLV)
-- 8. Verificar si Jhoan gana $3,000,000/mes o $6,000,000/mes
-- 9. Chirry: confirmar si es exclusivamente por día
-- NOTA: Sebastián y Daniel B. fueron removidos de la lista
-- =====================================================
