-- =============================================
-- 056: Insertar conceptos de nómina faltantes
-- Algunos conceptos que usa la app no existían en payroll_concepts,
-- causando que los detalles de nómina no se guardaran.
-- =============================================

-- BONO_EXTRA: bonos manuales agregados por el usuario
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('BONO_EXTRA', 'Bono Extra', 'ingreso', 'bonificaciones', true)
ON CONFLICT (code) DO NOTHING;

-- BONO_ASISTENCIA: bono por asistencia perfecta
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('BONO_ASISTENCIA', 'Bono por Asistencia', 'ingreso', 'bonificaciones', true)
ON CONFLICT (code) DO NOTHING;

-- HORA_EXTRA: horas extra normales (sin recargo)
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('HORA_EXTRA', 'Hora Extra Normal', 'ingreso', 'horas_extra', true)
ON CONFLICT (code) DO NOTHING;

-- HORA_EXTRA_25: horas extra diurnas (+25%)
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('HORA_EXTRA_25', 'Hora Extra Diurna', 'ingreso', 'horas_extra', true)
ON CONFLICT (code) DO NOTHING;

-- HORA_EXTRA_75: horas extra nocturnas (+75%)
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('HORA_EXTRA_75', 'Hora Extra Nocturna', 'ingreso', 'horas_extra', true)
ON CONFLICT (code) DO NOTHING;

-- HORA_EXTRA_100: horas extra dom/fest diurna (+100%)
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('HORA_EXTRA_100', 'Hora Extra Dom/Fest Diurna', 'ingreso', 'horas_extra', true)
ON CONFLICT (code) DO NOTHING;

-- HORA_EXTRA_150: horas extra dom/fest nocturna (+150%)
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('HORA_EXTRA_150', 'Hora Extra Dom/Fest Nocturna', 'ingreso', 'horas_extra', true)
ON CONFLICT (code) DO NOTHING;

-- DESC_HORAS_FALTANTES: descuento por horas no trabajadas
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('DESC_HORAS_FALTANTES', 'Descuento Horas Faltantes', 'descuento', 'deducciones', true)
ON CONFLICT (code) DO NOTHING;

-- DESC_PRESTAMO: descuento por cuota de préstamo
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('DESC_PRESTAMO', 'Cuota Préstamo', 'descuento', 'deducciones', true)
ON CONFLICT (code) DO NOTHING;

-- DESC_ADELANTO: descuento por adelanto de salario
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES ('DESC_ADELANTO', 'Descuento Adelanto', 'descuento', 'deducciones', true)
ON CONFLICT (code) DO NOTHING;

-- Verificar conceptos insertados
SELECT code, name, type, category FROM payroll_concepts WHERE is_active = true ORDER BY type, code;
