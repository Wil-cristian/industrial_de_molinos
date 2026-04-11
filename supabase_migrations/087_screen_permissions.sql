-- =====================================================
-- 087: Tabla de permisos de pantalla por usuario
-- Sobrescribe los defaults del rol definidos en código
-- =====================================================

CREATE TABLE IF NOT EXISTS screen_permissions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  screen_key TEXT NOT NULL,
  is_allowed BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, screen_key)
);

-- RLS
ALTER TABLE screen_permissions ENABLE ROW LEVEL SECURITY;

-- Usuarios pueden ver sus propios permisos
CREATE POLICY "Users can view own permissions" ON screen_permissions
  FOR SELECT USING (auth.uid() = user_id);

-- Admin puede gestionar todos los permisos
CREATE POLICY "Admins can manage all permissions" ON screen_permissions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE user_profiles.user_id = auth.uid() 
      AND user_profiles.role IN ('admin', 'dueno')
    )
  );

COMMENT ON TABLE screen_permissions IS 'Permisos de pantalla por usuario. Sobrescriben los defaults del rol.';

-- Seed: Solo Wil (admin) tiene acceso a auditoría
INSERT INTO screen_permissions (user_id, screen_key, is_allowed)
VALUES ('79c224df-dba2-44aa-a95d-3015f89567f1', 'audit-panel', true)
ON CONFLICT (user_id, screen_key) DO NOTHING;

-- Johan es dueno (todo excepto auditoría por defecto)
-- Wil es admin (todo excepto auditoría por defecto + override de auditoría en screen_permissions)
