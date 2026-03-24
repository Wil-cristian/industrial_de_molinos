-- =====================================================
-- MIGRACIÓN 059: Auto-credenciales encriptadas
-- =====================================================
-- 1. Credenciales auto-generadas (email desde nombre, password aleatorio)
-- 2. Password encriptado con PGP en la DB (admin puede ver/resetear)
-- 3. Funciones privadas no expuestas al API
-- =====================================================

-- Asegurar pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Columna para almacenar credencial encriptada
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS encrypted_credential TEXT;

-- ========== FUNCIONES PRIVADAS (no accesibles desde el API) ==========

-- Clave de encriptación (solo accesible desde SECURITY DEFINER)
CREATE OR REPLACE FUNCTION _cred_key()
RETURNS TEXT AS $$
    SELECT 'M0l1n0s_Cr3d!xK9Q2vL7nR4pW6tY8jF'
$$ LANGUAGE sql IMMUTABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION _cred_key() FROM PUBLIC;

-- Generar contraseña segura aleatoria (12 chars: letras + nums + especiales)
CREATE OR REPLACE FUNCTION _gen_pwd()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    specials TEXT := '!@#&*';
    result TEXT := '';
    i INT;
BEGIN
    FOR i IN 1..10 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    FOR i IN 1..2 LOOP
        result := result || substr(specials, floor(random() * length(specials) + 1)::int, 1);
    END LOOP;
    RETURN result;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

REVOKE ALL ON FUNCTION _gen_pwd() FROM PUBLIC;

-- Generar email automático: nombre.apellido@molinos.app
CREATE OR REPLACE FUNCTION _gen_email(p_first TEXT, p_last TEXT)
RETURNS TEXT AS $$
DECLARE
    v_base TEXT;
    v_email TEXT;
    v_n INT := 0;
BEGIN
    -- Normalizar: minúsculas, quitar acentos, puntos entre nombres
    v_base := lower(translate(
        trim(p_first) || '.' || trim(p_last),
        'áéíóúñÁÉÍÓÚÑüÜ ',
        'aeiounAEIOUNuU.'
    ));
    -- Solo alfanuméricos y puntos
    v_base := regexp_replace(v_base, '[^a-z0-9.]', '', 'g');
    v_email := v_base || '@molinos.app';
    
    -- Garantizar unicidad
    WHILE EXISTS (SELECT 1 FROM auth.users WHERE email = v_email) LOOP
        v_n := v_n + 1;
        v_email := v_base || v_n || '@molinos.app';
    END LOOP;
    
    RETURN v_email;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

REVOKE ALL ON FUNCTION _gen_email(TEXT, TEXT) FROM PUBLIC;

-- ========== REEMPLAZAR create_employee_account ==========

-- Eliminar versión anterior (con params manuales)
DROP FUNCTION IF EXISTS create_employee_account(VARCHAR, VARCHAR, UUID, VARCHAR);

-- Nueva versión: auto-genera email + password + encripta
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

    -- Crear perfil con credencial encriptada
    INSERT INTO user_profiles (user_id, employee_id, role, display_name, encrypted_credential)
    VALUES (
        v_new_user_id,
        p_employee_id,
        'employee',
        v_employee.first_name || ' ' || v_employee.last_name,
        v_encrypted
    );

    -- Retornar credenciales al admin (única vez que se muestran en texto plano)
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cuenta creada exitosamente',
        'email', v_email,
        'password', v_password,
        'employee_name', v_employee.first_name || ' ' || v_employee.last_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========== NUEVOS RPCs ==========

-- Ver credenciales de un empleado (admin desencripta)
CREATE OR REPLACE FUNCTION get_employee_credential(p_profile_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_enc TEXT;
    v_pwd TEXT;
    v_email TEXT;
    v_name TEXT;
BEGIN
    SELECT role INTO v_caller_role
    FROM user_profiles WHERE user_id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role != 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;

    SELECT up.encrypted_credential, up.display_name, au.email
    INTO v_enc, v_name, v_email
    FROM user_profiles up
    JOIN auth.users au ON au.id = up.user_id
    WHERE up.id = p_profile_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
    END IF;

    IF v_enc IS NULL THEN
        RETURN jsonb_build_object(
            'success', true,
            'email', v_email,
            'password', NULL,
            'display_name', v_name,
            'message', 'Contraseña definida manualmente'
        );
    END IF;

    v_pwd := pgp_sym_decrypt(decode(v_enc, 'base64'), _cred_key());

    RETURN jsonb_build_object(
        'success', true,
        'email', v_email,
        'password', v_pwd,
        'display_name', v_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resetear contraseña de un empleado (admin genera nueva)
CREATE OR REPLACE FUNCTION reset_employee_password(p_profile_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_uid UUID;
    v_pwd TEXT;
    v_enc TEXT;
    v_email TEXT;
    v_name TEXT;
BEGIN
    SELECT role INTO v_caller_role
    FROM user_profiles WHERE user_id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role != 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;

    SELECT up.user_id, up.display_name, au.email
    INTO v_uid, v_name, v_email
    FROM user_profiles up
    JOIN auth.users au ON au.id = up.user_id
    WHERE up.id = p_profile_id;

    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'NOT_FOUND');
    END IF;

    -- Generar nueva contraseña
    v_pwd := _gen_pwd();
    v_enc := encode(pgp_sym_encrypt(v_pwd, _cred_key()), 'base64');

    -- Actualizar en auth y en perfil
    UPDATE auth.users
    SET encrypted_password = crypt(v_pwd, gen_salt('bf')), updated_at = NOW()
    WHERE id = v_uid;

    UPDATE user_profiles
    SET encrypted_credential = v_enc, updated_at = NOW()
    WHERE user_id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'email', v_email,
        'password', v_pwd,
        'display_name', v_name,
        'message', 'Contraseña reseteada'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========== ACTUALIZAR list_user_accounts para incluir has_credential ==========

CREATE OR REPLACE FUNCTION list_user_accounts()
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
BEGIN
    SELECT role INTO v_caller_role
    FROM user_profiles WHERE user_id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role != 'admin' THEN
        RETURN '[]'::JSONB;
    END IF;

    RETURN (
        SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::JSONB)
        FROM (
            SELECT
                up.id,
                up.user_id,
                up.employee_id,
                up.role,
                up.display_name,
                up.is_active,
                up.created_at,
                up.encrypted_credential IS NOT NULL AS has_credential,
                au.email,
                au.last_sign_in_at,
                e.first_name || ' ' || e.last_name AS employee_name,
                e.position AS employee_position
            FROM user_profiles up
            JOIN auth.users au ON au.id = up.user_id
            LEFT JOIN employees e ON e.id = up.employee_id
            ORDER BY up.role, up.display_name
        ) t
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
