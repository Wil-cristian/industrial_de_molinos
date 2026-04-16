-- ============================================================
-- 091: Fix create_employee_account — agregar parámetro p_role
-- ============================================================
-- La migración 066 agregó roles (admin, tecnico, dueno, employee)
-- pero no actualizó la función para recibir p_role.
-- El frontend envía (p_employee_id, p_role) → PGRST202.
-- Fix: recrear función con p_role DEFAULT 'employee'.
-- ============================================================

-- Eliminar la versión vieja (solo 1 parámetro)
DROP FUNCTION IF EXISTS create_employee_account(UUID);

CREATE OR REPLACE FUNCTION create_employee_account(
    p_employee_id UUID,
    p_role VARCHAR DEFAULT 'employee'
)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_new_user_id UUID;
    v_employee RECORD;
    v_email TEXT;
    v_password TEXT;
    v_encrypted TEXT;
    v_safe_role VARCHAR;
BEGIN
    -- Sanitizar rol (solo valores permitidos)
    IF p_role NOT IN ('admin', 'employee', 'tecnico', 'dueno') THEN
        v_safe_role := 'employee';
    ELSE
        v_safe_role := p_role;
    END IF;

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
    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password,
        email_confirmed_at, aud, role,
        raw_user_meta_data, raw_app_meta_data,
        created_at, updated_at,
        confirmation_token, recovery_token
    ) VALUES (
        v_new_user_id,
        '00000000-0000-0000-0000-000000000000',
        v_email,
        crypt(v_password, gen_salt('bf')),
        NOW(), 'authenticated', 'authenticated',
        jsonb_build_object(
            'role', v_safe_role,
            'display_name', v_employee.first_name || ' ' || v_employee.last_name,
            'employee_id', p_employee_id
        ),
        jsonb_build_object(
            'provider', 'email',
            'providers', ARRAY['email'],
            'role', v_safe_role
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
    INSERT INTO user_profiles (user_id, employee_id, role, display_name, encrypted_credential)
    VALUES (
        v_new_user_id,
        p_employee_id,
        v_safe_role,
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
        'user_id', v_new_user_id,
        'role', v_safe_role,
        'employee_name', v_employee.first_name || ' ' || v_employee.last_name
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'DB_ERROR',
        'message', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
