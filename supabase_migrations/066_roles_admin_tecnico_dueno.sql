-- ============================================================
-- 066: Agregar roles admin, tecnico, dueno
-- ============================================================

-- 1. Actualizar CHECK constraint
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check 
  CHECK (role IN ('admin', 'employee', 'tecnico', 'dueno'));

-- 2. Fix create_employee_account: raw_app_meta_data + parámetro p_role
-- (función completa recreada en Supabase via apply_migration)

-- 3. Comentar columna
COMMENT ON COLUMN user_profiles.role IS 'Rol: admin, tecnico, dueno, employee';
