-- =====================================================
-- SCRIPT: Insertar Empleados de Prueba
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- Insertar empleados de prueba
INSERT INTO employees (
  first_name, 
  last_name, 
  position, 
  department, 
  phone, 
  email, 
  salary, 
  is_active, 
  hire_date
) VALUES 
  ('Juan', 'Pérez García', 'Operador de Molino', 'Producción', '809-555-0101', 'juan.perez@molinos.com', 35000, TRUE, '2023-01-15'),
  ('María', 'González Rodríguez', 'Supervisora', 'Producción', '809-555-0102', 'maria.gonzalez@molinos.com', 55000, TRUE, '2022-06-01'),
  ('Carlos', 'Martínez López', 'Técnico de Mantenimiento', 'Mantenimiento', '809-555-0103', 'carlos.martinez@molinos.com', 40000, TRUE, '2023-03-20'),
  ('Ana', 'Sánchez Díaz', 'Asistente Administrativa', 'Administración', '809-555-0104', 'ana.sanchez@molinos.com', 30000, TRUE, '2023-08-10'),
  ('Pedro', 'Ramírez Hernández', 'Operador de Molino', 'Producción', '809-555-0105', 'pedro.ramirez@molinos.com', 35000, TRUE, '2024-02-01'),
  ('Laura', 'Torres Vega', 'Contadora', 'Finanzas', '809-555-0106', 'laura.torres@molinos.com', 50000, TRUE, '2022-01-10'),
  ('Miguel', 'Flores Castro', 'Chofer', 'Logística', '809-555-0107', 'miguel.flores@molinos.com', 28000, TRUE, '2023-05-15'),
  ('Carmen', 'Ruiz Morales', 'Auxiliar de Almacén', 'Almacén', '809-555-0108', 'carmen.ruiz@molinos.com', 25000, TRUE, '2024-01-08')
ON CONFLICT DO NOTHING;

-- Obtener IDs de los empleados insertados
DO $$
DECLARE
  emp_juan UUID;
  emp_maria UUID;
  emp_carlos UUID;
  emp_ana UUID;
  emp_pedro UUID;
BEGIN
  SELECT id INTO emp_juan FROM employees WHERE first_name = 'Juan' AND last_name = 'Pérez García' LIMIT 1;
  SELECT id INTO emp_maria FROM employees WHERE first_name = 'María' AND last_name = 'González Rodríguez' LIMIT 1;
  SELECT id INTO emp_carlos FROM employees WHERE first_name = 'Carlos' AND last_name = 'Martínez López' LIMIT 1;
  SELECT id INTO emp_ana FROM employees WHERE first_name = 'Ana' AND last_name = 'Sánchez Díaz' LIMIT 1;
  SELECT id INTO emp_pedro FROM employees WHERE first_name = 'Pedro' AND last_name = 'Ramírez Hernández' LIMIT 1;

  -- Insertar algunas tareas de ejemplo
  IF emp_juan IS NOT NULL THEN
    INSERT INTO employee_tasks (employee_id, title, description, status, priority, category, assigned_date)
    VALUES 
      (emp_juan, 'Calibrar molino #3', 'Realizar calibración completa del molino número 3', 'pendiente', 'alta', 'Mantenimiento', CURRENT_DATE),
      (emp_juan, 'Revisión de filtros', 'Inspeccionar y limpiar filtros de polvo', 'en_progreso', 'media', 'Mantenimiento', CURRENT_DATE - INTERVAL '1 day');
  END IF;

  IF emp_maria IS NOT NULL THEN
    INSERT INTO employee_tasks (employee_id, title, description, status, priority, category, assigned_date)
    VALUES 
      (emp_maria, 'Reporte semanal producción', 'Generar reporte de producción semanal', 'pendiente', 'alta', 'Reportes', CURRENT_DATE),
      (emp_maria, 'Capacitación nuevo personal', 'Capacitar a Pedro en operación de molinos', 'en_progreso', 'media', 'Capacitación', CURRENT_DATE - INTERVAL '2 days');
  END IF;

  IF emp_carlos IS NOT NULL THEN
    INSERT INTO employee_tasks (employee_id, title, description, status, priority, category, assigned_date)
    VALUES 
      (emp_carlos, 'Mantenimiento preventivo', 'Realizar mantenimiento preventivo mensual', 'pendiente', 'media', 'Mantenimiento', CURRENT_DATE),
      (emp_carlos, 'Reparar cinta transportadora', 'Arreglar banda de cinta transportadora #2', 'completada', 'alta', 'Reparación', CURRENT_DATE - INTERVAL '3 days');
  END IF;

  -- Insertar registros de tiempo (últimos 7 días)
  IF emp_juan IS NOT NULL THEN
    INSERT INTO employee_time_entries (employee_id, entry_date, check_in, check_out, worked_minutes, scheduled_minutes, overtime_minutes, status)
    VALUES 
      (emp_juan, CURRENT_DATE - INTERVAL '1 day', (CURRENT_DATE - INTERVAL '1 day') + TIME '07:00', (CURRENT_DATE - INTERVAL '1 day') + TIME '16:30', 570, 528, 42, 'aprobado'),
      (emp_juan, CURRENT_DATE - INTERVAL '2 days', (CURRENT_DATE - INTERVAL '2 days') + TIME '07:05', (CURRENT_DATE - INTERVAL '2 days') + TIME '16:00', 535, 528, 7, 'aprobado'),
      (emp_juan, CURRENT_DATE - INTERVAL '3 days', (CURRENT_DATE - INTERVAL '3 days') + TIME '07:00', (CURRENT_DATE - INTERVAL '3 days') + TIME '15:30', 510, 528, 0, 'aprobado'),
      (emp_juan, CURRENT_DATE - INTERVAL '4 days', (CURRENT_DATE - INTERVAL '4 days') + TIME '06:55', (CURRENT_DATE - INTERVAL '4 days') + TIME '17:00', 605, 528, 77, 'aprobado'),
      (emp_juan, CURRENT_DATE - INTERVAL '5 days', (CURRENT_DATE - INTERVAL '5 days') + TIME '07:10', (CURRENT_DATE - INTERVAL '5 days') + TIME '16:00', 530, 528, 2, 'tardanza');
  END IF;

  IF emp_maria IS NOT NULL THEN
    INSERT INTO employee_time_entries (employee_id, entry_date, check_in, check_out, worked_minutes, scheduled_minutes, overtime_minutes, status)
    VALUES 
      (emp_maria, CURRENT_DATE - INTERVAL '1 day', (CURRENT_DATE - INTERVAL '1 day') + TIME '08:00', (CURRENT_DATE - INTERVAL '1 day') + TIME '17:30', 570, 528, 42, 'aprobado'),
      (emp_maria, CURRENT_DATE - INTERVAL '2 days', (CURRENT_DATE - INTERVAL '2 days') + TIME '08:00', (CURRENT_DATE - INTERVAL '2 days') + TIME '17:00', 540, 528, 12, 'aprobado'),
      (emp_maria, CURRENT_DATE - INTERVAL '3 days', (CURRENT_DATE - INTERVAL '3 days') + TIME '08:15', (CURRENT_DATE - INTERVAL '3 days') + TIME '17:00', 525, 528, 0, 'tardanza');
  END IF;

  IF emp_carlos IS NOT NULL THEN
    INSERT INTO employee_time_entries (employee_id, entry_date, check_in, check_out, worked_minutes, scheduled_minutes, overtime_minutes, status)
    VALUES 
      (emp_carlos, CURRENT_DATE - INTERVAL '1 day', (CURRENT_DATE - INTERVAL '1 day') + TIME '07:00', (CURRENT_DATE - INTERVAL '1 day') + TIME '18:00', 660, 528, 132, 'aprobado'),
      (emp_carlos, CURRENT_DATE - INTERVAL '2 days', (CURRENT_DATE - INTERVAL '2 days') + TIME '07:00', (CURRENT_DATE - INTERVAL '2 days') + TIME '16:00', 540, 528, 12, 'aprobado');
  END IF;

  -- Insertar algunos ajustes de tiempo
  IF emp_juan IS NOT NULL THEN
    INSERT INTO employee_time_adjustments (employee_id, type, minutes, reason, adjustment_date, status)
    VALUES 
      (emp_juan, 'overtime', 60, 'Trabajo extra por pedido urgente', CURRENT_DATE - INTERVAL '5 days', 'aprobado'),
      (emp_juan, 'descuento', -30, 'Llegada tarde sin justificación', CURRENT_DATE - INTERVAL '10 days', 'aprobado');
  END IF;

  IF emp_pedro IS NOT NULL THEN
    INSERT INTO employee_time_adjustments (employee_id, type, minutes, reason, adjustment_date, status)
    VALUES 
      (emp_pedro, 'overtime', 120, 'Horas extra fin de semana', CURRENT_DATE - INTERVAL '3 days', 'aprobado');
  END IF;

END $$;

-- Verificar datos insertados
SELECT 'Empleados insertados:' as info, COUNT(*) as total FROM employees;
SELECT 'Tareas insertadas:' as info, COUNT(*) as total FROM employee_tasks;
SELECT 'Registros de tiempo:' as info, COUNT(*) as total FROM employee_time_entries;
SELECT 'Ajustes de tiempo:' as info, COUNT(*) as total FROM employee_time_adjustments;
