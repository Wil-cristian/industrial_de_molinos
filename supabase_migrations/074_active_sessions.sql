-- ============================================================
-- 074: Sesiones Activas / Dispositivos Conectados
-- Permite al admin ver qué dispositivos están activos,
-- con qué perfil, y desde cuándo.
-- ============================================================

-- 1. Tabla de sesiones activas
CREATE TABLE IF NOT EXISTS user_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id      UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    
    -- Info del dispositivo
    platform        VARCHAR(30) NOT NULL DEFAULT 'unknown', -- 'windows', 'web', 'android', 'ios'
    device_name     VARCHAR(100),                            -- Ej: "Windows 10", "Chrome 120", "Samsung Galaxy S24"
    app_version     VARCHAR(20),                             -- Versión de la app
    
    -- Estado
    is_active       BOOLEAN DEFAULT true,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_heartbeat  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    
    -- IP (informativo, no se usa para decisiones)
    ip_address      TEXT
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON user_sessions(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_user_sessions_heartbeat ON user_sessions(last_heartbeat DESC);

-- Habilitar RLS
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- Policies: autenticados pueden ver, solo owner puede insertar/actualizar su sesión
CREATE POLICY "user_sessions_select_authenticated"
    ON user_sessions FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "user_sessions_insert_own"
    ON user_sessions FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_sessions_update_own"
    ON user_sessions FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- 2. RPC: Registrar o actualizar sesión (upsert por user + platform + device)
CREATE OR REPLACE FUNCTION register_session(
    p_platform TEXT,
    p_device_name TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile_id UUID;
    v_session_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No autenticado';
    END IF;
    
    -- Obtener profile_id
    SELECT id INTO v_profile_id FROM user_profiles WHERE user_id = v_user_id LIMIT 1;
    
    -- Buscar sesión activa existente del mismo user+platform
    SELECT id INTO v_session_id
    FROM user_sessions
    WHERE user_id = v_user_id
      AND platform = p_platform
      AND is_active = true
    LIMIT 1;
    
    IF v_session_id IS NOT NULL THEN
        -- Actualizar heartbeat
        UPDATE user_sessions
        SET last_heartbeat = NOW(),
            device_name = COALESCE(p_device_name, device_name),
            app_version = COALESCE(p_app_version, app_version),
            profile_id = COALESCE(v_profile_id, profile_id)
        WHERE id = v_session_id;
        
        RETURN v_session_id;
    ELSE
        -- Crear nueva sesión
        INSERT INTO user_sessions (user_id, profile_id, platform, device_name, app_version)
        VALUES (v_user_id, v_profile_id, p_platform, p_device_name, p_app_version)
        RETURNING id INTO v_session_id;
        
        RETURN v_session_id;
    END IF;
END;
$$;

-- 3. RPC: Cerrar sesión del dispositivo actual
CREATE OR REPLACE FUNCTION close_session(p_session_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    UPDATE user_sessions
    SET is_active = false, ended_at = NOW()
    WHERE id = p_session_id
      AND user_id = auth.uid();
    
    RETURN FOUND;
END;
$$;

-- 4. RPC: Listar sesiones activas (admin ve todas, usuario solo las suyas)
CREATE OR REPLACE FUNCTION list_active_sessions()
RETURNS TABLE (
    session_id UUID,
    user_id UUID,
    profile_id UUID,
    display_name TEXT,
    email TEXT,
    user_role TEXT,
    employee_name TEXT,
    employee_position TEXT,
    platform TEXT,
    device_name TEXT,
    app_version TEXT,
    started_at TIMESTAMPTZ,
    last_heartbeat TIMESTAMPTZ,
    is_online BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No autenticado';
    END IF;
    
    SELECT up.role INTO v_role FROM user_profiles up WHERE up.user_id = v_user_id;
    
    RETURN QUERY
    SELECT 
        us.id AS session_id,
        us.user_id,
        us.profile_id,
        COALESCE(up.display_name, au.email)::TEXT AS display_name,
        au.email::TEXT AS email,
        COALESCE(up.role, 'unknown')::TEXT AS user_role,
        (e.first_name || ' ' || e.last_name)::TEXT AS employee_name,
        e.position::TEXT AS employee_position,
        us.platform::TEXT,
        us.device_name::TEXT,
        us.app_version::TEXT,
        us.started_at,
        us.last_heartbeat,
        -- Consideramos "online" si heartbeat < 5 minutos
        (us.last_heartbeat > NOW() - INTERVAL '5 minutes') AS is_online
    FROM user_sessions us
    JOIN auth.users au ON au.id = us.user_id
    LEFT JOIN user_profiles up ON up.user_id = us.user_id
    LEFT JOIN employees e ON e.id = up.employee_id
    WHERE us.is_active = true
      -- Mostrar solo sesiones con heartbeat < 24h (limpiar stale)
      AND us.last_heartbeat > NOW() - INTERVAL '24 hours'
      -- Admin ve todo, otros solo lo suyo
      AND (v_role IN ('admin', 'dueno') OR us.user_id = v_user_id)
    ORDER BY us.last_heartbeat DESC;
END;
$$;

-- 5. Función de limpieza: marcar como inactivas sesiones sin heartbeat > 1 hora
CREATE OR REPLACE FUNCTION cleanup_stale_sessions()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE user_sessions
    SET is_active = false, ended_at = NOW()
    WHERE is_active = true
      AND last_heartbeat < NOW() - INTERVAL '1 hour';
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;
