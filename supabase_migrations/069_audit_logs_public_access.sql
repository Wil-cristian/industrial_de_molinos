-- ============================================
-- 069: Permitir que todos los usuarios vean logs de auditoría
-- ============================================

-- Agregar política adicional: cualquier usuario autenticado puede ver todos los logs
-- Esto NO causa recursión porque no toca user_profiles
CREATE POLICY "All authenticated can view audit logs" ON audit_logs
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Actualizar función get_audit_logs para permitir acceso a todos
CREATE OR REPLACE FUNCTION get_audit_logs(
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
  -- Cualquier usuario autenticado puede consultar logs
  RETURN QUERY
  SELECT 
    al.id,
    al.user_id,
    al.user_email,
    al.user_display_name,
    al.user_role,
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
