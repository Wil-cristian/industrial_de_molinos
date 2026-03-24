-- RPC para que un admin pueda cambiar el rol de un usuario
CREATE OR REPLACE FUNCTION update_user_role(p_profile_id UUID, p_new_role TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_role TEXT;
  v_target_profile RECORD;
BEGIN
  -- Verificar que el caller sea admin
  SELECT role INTO v_caller_role
  FROM user_profiles
  WHERE user_id = auth.uid();

  IF v_caller_role IS NULL OR v_caller_role != 'admin' THEN
    RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED', 'message', 'Solo administradores pueden cambiar roles');
  END IF;

  -- Verificar que el perfil objetivo exista
  SELECT * INTO v_target_profile
  FROM user_profiles
  WHERE id = p_profile_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND', 'message', 'Perfil no encontrado');
  END IF;

  -- No permitir cambiarse el rol a sí mismo
  IF v_target_profile.user_id = auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'SELF_CHANGE', 'message', 'No puedes cambiar tu propio rol');
  END IF;

  -- Validar el nuevo rol
  IF p_new_role NOT IN ('admin', 'tecnico', 'dueno', 'employee') THEN
    RETURN jsonb_build_object('success', false, 'error', 'INVALID_ROLE', 'message', 'Rol inválido: ' || p_new_role);
  END IF;

  -- Actualizar el rol
  UPDATE user_profiles
  SET role = p_new_role, updated_at = NOW()
  WHERE id = p_profile_id;

  -- También actualizar raw_app_meta_data en auth.users para que el rol quede en el JWT
  UPDATE auth.users
  SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', p_new_role)
  WHERE id = v_target_profile.user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Rol actualizado a ' || p_new_role,
    'profile_id', p_profile_id,
    'new_role', p_new_role
  );
END;
$$;
