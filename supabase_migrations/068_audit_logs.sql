-- ============================================
-- 068: Tabla de auditoría (audit_logs)
-- Registra todos los movimientos del sistema
-- con quién los hizo y cuándo
-- ============================================

-- Tabla principal de auditoría
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  user_email TEXT,
  user_display_name TEXT,
  user_role TEXT,
  action TEXT NOT NULL,        -- 'create', 'update', 'delete', 'approve', 'cancel', 'print', etc.
  module TEXT NOT NULL,        -- 'invoices', 'expenses', 'materials', 'inventory', 'cash', 'production', etc.
  record_id TEXT,              -- ID del registro afectado
  description TEXT NOT NULL,   -- Descripción legible: "Creó factura FAC-001 por $5,000"
  details JSONB,               -- Datos adicionales (valores anteriores, nuevos valores, etc.)
  ip_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_module ON audit_logs(module);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_record_id ON audit_logs(record_id);

-- RLS: solo admin, dueño y técnico pueden ver logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Política de lectura: admin, dueño y técnico ven todo
CREATE POLICY "audit_logs_select_policy" ON audit_logs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.user_id = auth.uid()
        AND user_profiles.role IN ('admin', 'dueno', 'tecnico')
        AND user_profiles.is_active = true
    )
  );

-- Política de inserción: cualquier usuario autenticado puede insertar
CREATE POLICY "audit_logs_insert_policy" ON audit_logs
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Función RPC para registrar un log (callable desde Flutter)
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
  v_log_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  -- Obtener datos del usuario
  SELECT 
    au.email,
    up.display_name,
    up.role
  INTO v_email, v_display_name, v_role
  FROM auth.users au
  LEFT JOIN user_profiles up ON up.user_id = au.id
  WHERE au.id = v_user_id;

  INSERT INTO audit_logs (user_id, user_email, user_display_name, user_role, action, module, record_id, description, details)
  VALUES (v_user_id, v_email, COALESCE(v_display_name, v_email), v_role, p_action, p_module, p_record_id, p_description, p_details)
  RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$;

-- Función para consultar logs con filtros
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
  -- Verificar que el usuario sea admin, dueño o técnico
  IF NOT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_profiles.user_id = auth.uid()
      AND user_profiles.role IN ('admin', 'dueno', 'tecnico')
      AND user_profiles.is_active = true
  ) THEN
    RAISE EXCEPTION 'No autorizado para ver logs de auditoría';
  END IF;

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
