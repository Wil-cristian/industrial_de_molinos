-- =====================================================
-- MIGRACIÓN 058: User Profiles & Roles
-- =====================================================
-- Sistema de roles para diferenciar admin vs empleado:
--   1. Tabla user_profiles: vincula auth.users con employees
--   2. Función RPC para obtener perfil del usuario actual
--   3. Función RPC para crear usuario empleado (solo admin)
--   4. RLS policies
-- =====================================================

-- 1. Tabla de perfiles de usuario
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'employee')),
    display_name VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user ON user_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_employee ON user_profiles(employee_id) WHERE employee_id IS NOT NULL;

-- 2. Auto-crear perfil admin para usuarios existentes que no tienen perfil
INSERT INTO user_profiles (user_id, role, display_name)
SELECT 
    au.id,
    'admin',
    COALESCE(au.raw_user_meta_data->>'full_name', au.email)
FROM auth.users au
LEFT JOIN user_profiles up ON up.user_id = au.id
WHERE up.id IS NULL;

-- 3. Trigger: auto-crear perfil admin cuando se registra un usuario nuevo via signup normal
CREATE OR REPLACE FUNCTION handle_new_user_profile()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo crear si no existe ya (para evitar duplicados con la creación manual)
    INSERT INTO user_profiles (user_id, role, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'role', 'admin'),
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email)
    )
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user_profile();

-- 4. RPC: obtener perfil del usuario actual
CREATE OR REPLACE FUNCTION get_my_profile()
RETURNS JSONB AS $$
DECLARE
    v_profile RECORD;
    v_employee RECORD;
    v_result JSONB;
BEGIN
    SELECT * INTO v_profile
    FROM user_profiles
    WHERE user_id = auth.uid();

    IF NOT FOUND THEN
        -- Auto-crear perfil admin si no existe
        INSERT INTO user_profiles (user_id, role, display_name)
        VALUES (auth.uid(), 'admin', (SELECT email FROM auth.users WHERE id = auth.uid()))
        RETURNING * INTO v_profile;
    END IF;

    v_result := jsonb_build_object(
        'id', v_profile.id,
        'user_id', v_profile.user_id,
        'role', v_profile.role,
        'display_name', v_profile.display_name,
        'is_active', v_profile.is_active,
        'employee_id', v_profile.employee_id
    );

    -- Si tiene empleado vinculado, agregar info del empleado
    IF v_profile.employee_id IS NOT NULL THEN
        SELECT id, first_name, last_name, position, department, 
               document_type, document_number, email, phone
        INTO v_employee
        FROM employees
        WHERE id = v_profile.employee_id;

        IF FOUND THEN
            v_result := v_result || jsonb_build_object(
                'employee_name', v_employee.first_name || ' ' || v_employee.last_name,
                'employee_position', v_employee.position,
                'employee_department', v_employee.department
            );
        END IF;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: crear cuenta de empleado (solo puede llamar un admin)
CREATE OR REPLACE FUNCTION create_employee_account(
    p_email VARCHAR,
    p_password VARCHAR,
    p_employee_id UUID,
    p_display_name VARCHAR DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
    v_new_user_id UUID;
    v_employee RECORD;
BEGIN
    -- Verificar que el caller es admin
    SELECT role INTO v_caller_role
    FROM user_profiles
    WHERE user_id = auth.uid();

    IF v_caller_role IS NULL OR v_caller_role != 'admin' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'UNAUTHORIZED',
            'message', 'Solo administradores pueden crear cuentas de empleado'
        );
    END IF;

    -- Verificar que el empleado existe
    SELECT id, first_name, last_name INTO v_employee
    FROM employees
    WHERE id = p_employee_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'EMPLOYEE_NOT_FOUND',
            'message', 'Empleado no encontrado'
        );
    END IF;

    -- Verificar que el empleado no tiene ya una cuenta
    IF EXISTS (SELECT 1 FROM user_profiles WHERE employee_id = p_employee_id) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ALREADY_EXISTS',
            'message', 'Este empleado ya tiene una cuenta vinculada'
        );
    END IF;

    -- Crear usuario en auth.users via extensión
    v_new_user_id := extensions.uuid_generate_v4();
    
    INSERT INTO auth.users (
        id, instance_id, email, encrypted_password, 
        email_confirmed_at, aud, role,
        raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token
    ) VALUES (
        v_new_user_id,
        '00000000-0000-0000-0000-000000000000',
        p_email,
        crypt(p_password, gen_salt('bf')),
        NOW(), 'authenticated', 'authenticated',
        jsonb_build_object(
            'role', 'employee',
            'display_name', COALESCE(p_display_name, v_employee.first_name || ' ' || v_employee.last_name),
            'employee_id', p_employee_id
        ),
        NOW(), NOW(),
        '', ''
    );

    -- Crear identidad
    INSERT INTO auth.identities (
        id, provider_id, user_id, identity_data, provider, 
        last_sign_in_at, created_at, updated_at
    ) VALUES (
        v_new_user_id, v_new_user_id, v_new_user_id,
        jsonb_build_object('sub', v_new_user_id, 'email', p_email),
        'email', NOW(), NOW(), NOW()
    );

    -- Crear perfil con rol empleado
    INSERT INTO user_profiles (user_id, employee_id, role, display_name)
    VALUES (
        v_new_user_id, 
        p_employee_id, 
        'employee',
        COALESCE(p_display_name, v_employee.first_name || ' ' || v_employee.last_name)
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Cuenta creada exitosamente',
        'user_id', v_new_user_id,
        'email', p_email,
        'employee_name', v_employee.first_name || ' ' || v_employee.last_name
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: listar cuentas de usuarios (solo admin)
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

-- 7. RPC: desactivar/activar cuenta
CREATE OR REPLACE FUNCTION toggle_user_account(p_profile_id UUID, p_active BOOLEAN)
RETURNS JSONB AS $$
DECLARE
    v_caller_role VARCHAR;
BEGIN
    SELECT role INTO v_caller_role
    FROM user_profiles WHERE user_id = auth.uid();

    IF v_caller_role != 'admin' THEN
        RETURN jsonb_build_object('success', false, 'error', 'UNAUTHORIZED');
    END IF;

    UPDATE user_profiles SET is_active = p_active, updated_at = NOW()
    WHERE id = p_profile_id;

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RLS para user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Usuarios pueden ver su propio perfil
CREATE POLICY "Users can view own profile" ON user_profiles
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Admins pueden ver todos los perfiles
CREATE POLICY "Admins can view all profiles" ON user_profiles
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Admins pueden insertar/actualizar
CREATE POLICY "Admins can manage profiles" ON user_profiles
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM user_profiles 
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );
