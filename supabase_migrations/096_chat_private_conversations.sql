-- ============================================================
-- 096: Conversaciones privadas entre perfiles
-- Cada conversación es visible SOLO para sus 2 participantes
-- ============================================================

-- ============================================================
-- 1. CORREGIR RLS — Solo participantes ven sus conversaciones
-- ============================================================

-- Conversaciones
DROP POLICY IF EXISTS "chat_conversations_select" ON chat_conversations;
DROP POLICY IF EXISTS "chat_conversations_update" ON chat_conversations;

CREATE POLICY "chat_conversations_select" ON chat_conversations
    FOR SELECT USING (
        auth.uid() = created_by
        OR auth.uid() = assigned_to
    );

CREATE POLICY "chat_conversations_update" ON chat_conversations
    FOR UPDATE USING (
        auth.uid() = created_by
        OR auth.uid() = assigned_to
    );

-- Mensajes
DROP POLICY IF EXISTS "chat_messages_select" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_update" ON chat_messages;

CREATE POLICY "chat_messages_select" ON chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (c.created_by = auth.uid() OR c.assigned_to = auth.uid())
        )
    );

CREATE POLICY "chat_messages_update" ON chat_messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (c.created_by = auth.uid() OR c.assigned_to = auth.uid())
        )
    );

-- Solicitudes de aprobación
DROP POLICY IF EXISTS "approval_requests_select" ON approval_requests;

CREATE POLICY "approval_requests_select" ON approval_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (c.created_by = auth.uid() OR c.assigned_to = auth.uid())
        )
    );

-- ============================================================
-- 2. RPC: Listar usuarios disponibles para chatear
-- ============================================================

CREATE OR REPLACE FUNCTION list_chat_users()
RETURNS TABLE(user_id UUID, display_name TEXT, role TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT up.user_id, up.display_name::TEXT, up.role::TEXT
    FROM user_profiles up
    WHERE up.user_id != auth.uid()
    AND up.is_active = true
    ORDER BY up.display_name;
END;
$$;

-- ============================================================
-- 3. RPC: Crear conversación directa (reutiliza si ya existe)
-- ============================================================

CREATE OR REPLACE FUNCTION create_direct_conversation(
    p_to_user UUID,
    p_message TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conversation_id UUID;
    v_user_id UUID := auth.uid();
    v_my_name TEXT;
    v_other_name TEXT;
BEGIN
    -- Buscar si ya existe conversación directa entre estos dos usuarios
    SELECT id INTO v_conversation_id
    FROM chat_conversations
    WHERE type = 'general'
    AND (
        (created_by = v_user_id AND assigned_to = p_to_user)
        OR (created_by = p_to_user AND assigned_to = v_user_id)
    )
    LIMIT 1;

    -- Si no existe, crear nueva
    IF v_conversation_id IS NULL THEN
        SELECT display_name INTO v_my_name FROM user_profiles WHERE user_id = v_user_id;
        SELECT display_name INTO v_other_name FROM user_profiles WHERE user_id = p_to_user;

        INSERT INTO chat_conversations (title, type, status, created_by, assigned_to)
        VALUES (
            COALESCE(v_my_name, 'Usuario') || ' ↔ ' || COALESCE(v_other_name, 'Usuario'),
            'general',
            'open',
            v_user_id,
            p_to_user
        )
        RETURNING id INTO v_conversation_id;
    END IF;

    -- Enviar mensaje
    INSERT INTO chat_messages (conversation_id, sender_id, content, message_type)
    VALUES (v_conversation_id, v_user_id, p_message, 'text');

    RETURN v_conversation_id;
END;
$$;

-- ============================================================
-- 4. Actualizar RPC create_approval_request para requerir assigned_to
-- ============================================================

CREATE OR REPLACE FUNCTION create_approval_request(
    p_title TEXT,
    p_type TEXT,
    p_request_type TEXT,
    p_request_data JSONB,
    p_message TEXT,
    p_assigned_to UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conversation_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    -- Crear conversación
    INSERT INTO chat_conversations (title, type, status, created_by, assigned_to, metadata)
    VALUES (p_title, p_type, 'pending', v_user_id, p_assigned_to, p_request_data)
    RETURNING id INTO v_conversation_id;

    -- Crear solicitud de aprobación
    INSERT INTO approval_requests (conversation_id, request_type, requested_by, request_data)
    VALUES (v_conversation_id, p_request_type, v_user_id, p_request_data);

    -- Crear mensaje inicial
    INSERT INTO chat_messages (conversation_id, sender_id, content, message_type, metadata)
    VALUES (v_conversation_id, v_user_id, p_message, 'approval_request', p_request_data);

    RETURN v_conversation_id;
END;
$$;

-- ============================================================
-- 5. Actualizar vista — mostrar nombre del otro participante
-- ============================================================

CREATE OR REPLACE VIEW v_chat_conversations AS
SELECT
    c.*,
    up_creator.display_name AS creator_name,
    up_creator.role AS creator_role,
    up_assigned.display_name AS assigned_name,
    up_assigned.role AS assigned_role,
    -- Nombre del otro participante (el que NO es el usuario actual)
    CASE
        WHEN c.created_by = auth.uid() THEN up_assigned.display_name
        ELSE up_creator.display_name
    END AS other_participant_name,
    CASE
        WHEN c.created_by = auth.uid() THEN up_assigned.role
        ELSE up_creator.role
    END AS other_participant_role,
    (
        SELECT content FROM chat_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1
    ) AS last_message,
    (
        SELECT created_at FROM chat_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1
    ) AS last_message_at,
    (
        SELECT COUNT(*)::int FROM chat_messages m
        WHERE m.conversation_id = c.id
        AND m.is_read = false
        AND m.sender_id != auth.uid()
    ) AS unread_count,
    ar.id AS approval_id,
    ar.request_type,
    ar.status AS approval_status,
    ar.request_data
FROM chat_conversations c
LEFT JOIN user_profiles up_creator ON up_creator.user_id = c.created_by
LEFT JOIN user_profiles up_assigned ON up_assigned.user_id = c.assigned_to
LEFT JOIN approval_requests ar ON ar.conversation_id = c.id
ORDER BY c.updated_at DESC;
