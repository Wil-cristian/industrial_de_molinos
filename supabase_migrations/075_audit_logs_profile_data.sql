-- ============================================================
-- 075: Enriquecer audit_logs con datos completos de perfil
-- Agrega employee_name, employee_position, employee_department
-- y actualiza log_audit() para capturar toda la info de perfil
-- ============================================================

-- 1. Agregar columnas de empleado al audit log
ALTER TABLE audit_logs
  ADD COLUMN IF NOT EXISTS employee_name TEXT,
  ADD COLUMN IF NOT EXISTS employee_position TEXT,
  ADD COLUMN IF NOT EXISTS employee_department TEXT,
  ADD COLUMN IF NOT EXISTS platform TEXT;

-- 2. Actualizar función log_audit para capturar datos completos
CREATE OR REPLACE FUNCTION log_audit(
  p_action TEXT,
  p_module TEXT,
  p_record_id TEXT DEFAULT NULL,
  p_description TEXT DEFAULT '',
  p_details JSONB DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_email TEXT;
  v_display_name TEXT;
  v_role TEXT;
  v_employee_name TEXT;
  v_employee_position TEXT;
  v_employee_department TEXT;
  v_log_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  -- Obtener datos completos del usuario + perfil + empleado
  SELECT 
    au.email,
    COALESCE(up.display_name, au.email),
    up.role,
    (e.first_name || ' ' || e.last_name),
    e.position,
    e.department
  INTO v_email, v_display_name, v_role, v_employee_name, v_employee_position, v_employee_department
  FROM auth.users au
  LEFT JOIN user_profiles up ON up.user_id = au.id
  LEFT JOIN employees e ON e.id = up.employee_id
  WHERE au.id = v_user_id;

  INSERT INTO audit_logs (
    user_id, user_email, user_display_name, user_role,
    employee_name, employee_position, employee_department,
    action, module, record_id, description, details
  )
  VALUES (
    v_user_id, v_email, COALESCE(v_display_name, v_email), v_role,
    v_employee_name, v_employee_position, v_employee_department,
    p_action, p_module, p_record_id, p_description, p_details
  )
  RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$;

-- 3. DROP y recrear get_audit_logs con nuevos campos
DROP FUNCTION IF EXISTS get_audit_logs(TEXT, TEXT, UUID, TIMESTAMPTZ, TIMESTAMPTZ, INT, INT);

CREATE FUNCTION get_audit_logs(
  p_module TEXT DEFAULT NULL,
  p_action TEXT DEFAULT NULL,
  p_user_id UUID DEFAULT NULL,
  p_from_date TIMESTAMPTZ DEFAULT NULL,
  p_to_date TIMESTAMPTZ DEFAULT NULL,
  p_limit INT DEFAULT 100,
  p_offset INT DEFAULT 0
) RETURNS TABLE (
  id UUID,
  user_id UUID,
  user_email TEXT,
  user_display_name TEXT,
  user_role TEXT,
  employee_name TEXT,
  employee_position TEXT,
  employee_department TEXT,
  action TEXT,
  module TEXT,
  record_id TEXT,
  description TEXT,
  details JSONB,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    al.id,
    al.user_id,
    al.user_email,
    al.user_display_name,
    al.user_role,
    al.employee_name,
    al.employee_position,
    al.employee_department,
    al.action,
    al.module,
    al.record_id,
    al.description,
    al.details,
    al.created_at
  FROM audit_logs al
  WHERE (p_module IS NULL OR al.module = p_module)
    AND (p_action IS NULL OR al.action = p_action)
    AND (p_user_id IS NULL OR al.user_id = p_user_id)
    AND (p_from_date IS NULL OR al.created_at >= p_from_date)
    AND (p_to_date IS NULL OR al.created_at <= p_to_date)
  ORDER BY al.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- 4. Rellenar datos de empleado en registros existentes (backfill)
UPDATE audit_logs al
SET 
  employee_name = (e.first_name || ' ' || e.last_name),
  employee_position = e.position,
  employee_department = e.department
FROM user_profiles up
JOIN employees e ON e.id = up.employee_id
WHERE al.user_id = up.user_id
  AND al.employee_name IS NULL
  AND up.employee_id IS NOT NULL;
