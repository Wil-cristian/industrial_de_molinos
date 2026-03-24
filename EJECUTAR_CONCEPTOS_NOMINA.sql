-- =============================================
-- EJECUTAR AHORA: Insertar conceptos de nómina faltantes
-- Ejecutar este script en el SQL Editor de Supabase
-- para que los bonos y horas extras se guarden correctamente
-- =============================================

-- Verificar qué conceptos existen antes
SELECT 'ANTES' as estado, code, name, type FROM payroll_concepts WHERE is_active = true ORDER BY type, code;

-- Insertar conceptos faltantes
INSERT INTO payroll_concepts (code, name, type, category, is_active)
VALUES 
  ('BONO_EXTRA', 'Bono Extra', 'ingreso', 'bonificaciones', true),
  ('BONO_ASISTENCIA', 'Bono por Asistencia', 'ingreso', 'bonificaciones', true),
  ('HORA_EXTRA', 'Hora Extra Normal', 'ingreso', 'horas_extra', true),
  ('HORA_EXTRA_25', 'Hora Extra Diurna', 'ingreso', 'horas_extra', true),
  ('HORA_EXTRA_75', 'Hora Extra Nocturna', 'ingreso', 'horas_extra', true),
  ('HORA_EXTRA_100', 'Hora Extra Dom/Fest Diurna', 'ingreso', 'horas_extra', true),
  ('HORA_EXTRA_150', 'Hora Extra Dom/Fest Nocturna', 'ingreso', 'horas_extra', true),
  ('DESC_HORAS_FALTANTES', 'Descuento Horas Faltantes', 'descuento', 'deducciones', true),
  ('DESC_PRESTAMO', 'Cuota Préstamo', 'descuento', 'deducciones', true),
  ('DESC_ADELANTO', 'Descuento Adelanto', 'descuento', 'deducciones', true)
ON CONFLICT (code) DO NOTHING;

-- Verificar qué conceptos existen después
SELECT 'DESPUES' as estado, code, name, type FROM payroll_concepts WHERE is_active = true ORDER BY type, code;
