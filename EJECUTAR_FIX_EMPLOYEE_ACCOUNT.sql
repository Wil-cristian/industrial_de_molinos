-- ============================================================
-- FIX: create_employee_account duplicate key en user_profiles
-- ============================================================
-- Ejecutar en Supabase SQL Editor (Dashboard > SQL)
-- Corrige el conflicto entre el trigger on_auth_user_created
-- y la función create_employee_account.
-- ============================================================

-- Primero limpiar el perfil huérfano del intento fallido anterior
-- (el trigger creó el perfil pero la función falló al duplicar)
DELETE FROM user_profiles
WHERE user_id NOT IN (SELECT id FROM auth.users)
  AND employee_id IS NULL;

-- Recrear la función con ON CONFLICT
CREATE OR REPLACE FUNCTION create_employee_account(p_employee_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_new_user_id UUID;
    v_employee RECORD;
    v_email TEXT;
    v_password TEXT;
    v_encrypted TEXT;
BEGIN
    -- Verificar que el caller es admin
    SELECT role INTO v_caller_role
    FROM user_profiles WHERE user_id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role != 'admin' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'UNAUTHORIZED',
            'message', 'Solo administradores pueden crear cuentas'
        );
    END IF;

    -- Verificar que el empleado existe
    SELECT id, first_name, last_name INTO v_employee
    FROM employees WHERE id = p_employee_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'NOT_FOUND',
            'message', 'Empleado no encontrado'
        );
    END IF;

    -- Verificar que no tiene cuenta ya
    IF EXISTS (SELECT 1 FROM user_profiles WHERE employee_id = p_employee_id) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ALREADY_EXISTS',
            'message', 'Este empleado ya tiene una cuenta vinculada'
        );
    END IF;

    -- Auto-generar credenciales
    v_email := _gen_email(v_employee.first_name, v_employee.last_name);
    v_password := _gen_pwd();
    v_encrypted := encode(pgp_sym_encrypt(v_password, _cred_key()), 'base64');
    v_new_user_id := extensions.uuid_generate_v4();

    -- Crear usuario en auth.users
    -- (el trigger on_auth_user_created creará un user_profiles básico)
    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password,
        email_confirmed_at, aud, role,
        raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token
    ) VALUES (
        v_new_user_id,
        '00000000-0000-0000-0000-000000000000',
        v_email,
        crypt(v_password, gen_salt('bf')),
        NOW(), 'authenticated', 'authenticated',
        jsonb_build_object(
            'role', 'employee',
            'display_name', v_employee.first_name || ' ' || v_employee.last_name,
            'employee_id', p_employee_id
        ),
        NOW(), NOW(), '', ''
    );

    -- Crear identidad
    INSERT INTO auth.identities (
        id, provider_id, user_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_new_user_id, v_new_user_id, v_new_user_id,
        jsonb_build_object('sub', v_new_user_id, 'email', v_email),
        'email', NOW(), NOW(), NOW()
    );

    -- Crear/actualizar perfil con credencial encriptada
    -- Usa ON CONFLICT porque el trigger ya pudo haber creado el registro
    INSERT INTO user_profiles (user_id, employee_id, role, display_name, encrypted_credential)
    VALUES (
        v_new_user_id,
        p_employee_id,
        'employee',
        v_employee.first_name || ' ' || v_employee.last_name,
        v_encrypted
    )
    ON CONFLICT (user_id) DO UPDATE SET
        employee_id = EXCLUDED.employee_id,
        role = EXCLUDED.role,
        display_name = EXCLUDED.display_name,
        encrypted_credential = EXCLUDED.encrypted_credential;

    -- Retornar credenciales al admin (única vez que se muestran en texto plano)
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cuenta creada exitosamente',
        'email', v_email,
        'password', v_password,
        'user_id', v_new_user_id
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'DB_ERROR',
        'message', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
