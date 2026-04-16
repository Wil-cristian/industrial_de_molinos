-- ============================================================
-- 097: Chat grupal + Integración IA en conversaciones
-- ============================================================

-- ============================================================
-- 1. Nuevos tipos de conversación: ai_chat, group
-- ============================================================

ALTER TABLE chat_conversations
    DROP CONSTRAINT IF EXISTS chat_conversations_type_check;

ALTER TABLE chat_conversations
    ADD CONSTRAINT chat_conversations_type_check
    CHECK (type IN ('transfer_approval', 'purchase_approval', 'expense_approval', 'general', 'ai_chat', 'group'));

-- ============================================================
-- 2. Nuevos tipos de mensaje: ai_response, ai_request
-- ============================================================

ALTER TABLE chat_messages
    DROP CONSTRAINT IF EXISTS chat_messages_message_type_check;

ALTER TABLE chat_messages
    ADD CONSTRAINT chat_messages_message_type_check
    CHECK (message_type IN ('text', 'approval_request', 'approval_response', 'system', 'ai_request', 'ai_response'));

-- ============================================================
-- 3. Tabla de participantes (para grupo y futura expansión)
-- ============================================================

CREATE TABLE IF NOT EXISTS chat_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    UNIQUE(conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_participants_conversation ON chat_participants(conversation_id);
CREATE INDEX IF NOT EXISTS idx_chat_participants_user ON chat_participants(user_id);

-- Habilitar RLS
ALTER TABLE chat_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chat_participants_select" ON chat_participants;
DROP POLICY IF EXISTS "chat_participants_insert" ON chat_participants;

CREATE POLICY "chat_participants_select" ON chat_participants
    FOR SELECT USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM chat_participants cp
            WHERE cp.conversation_id = chat_participants.conversation_id
            AND cp.user_id = auth.uid()
        )
    );

CREATE POLICY "chat_participants_insert" ON chat_participants
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (c.created_by = auth.uid())
        )
    );

-- Habilitar realtime
ALTER PUBLICATION supabase_realtime ADD TABLE chat_participants;

-- ============================================================
-- 4. Actualizar RLS de conversaciones para incluir grupo
-- ============================================================

DROP POLICY IF EXISTS "chat_conversations_select" ON chat_conversations;
DROP POLICY IF EXISTS "chat_conversations_update" ON chat_conversations;

CREATE POLICY "chat_conversations_select" ON chat_conversations
    FOR SELECT USING (
        auth.uid() = created_by
        OR auth.uid() = assigned_to
        OR EXISTS (
            SELECT 1 FROM chat_participants cp
            WHERE cp.conversation_id = id
            AND cp.user_id = auth.uid()
        )
    );

CREATE POLICY "chat_conversations_update" ON chat_conversations
    FOR UPDATE USING (
        auth.uid() = created_by
        OR auth.uid() = assigned_to
        OR EXISTS (
            SELECT 1 FROM chat_participants cp
            WHERE cp.conversation_id = id
            AND cp.user_id = auth.uid()
        )
    );

-- Mensajes: participantes de grupo también pueden ver/enviar
DROP POLICY IF EXISTS "chat_messages_select" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_update" ON chat_messages;

CREATE POLICY "chat_messages_select" ON chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (
                c.created_by = auth.uid()
                OR c.assigned_to = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM chat_participants cp
                    WHERE cp.conversation_id = c.id
                    AND cp.user_id = auth.uid()
                )
            )
        )
    );

CREATE POLICY "chat_messages_insert" ON chat_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id
        OR sender_id = '00000000-0000-0000-0000-000000000000'::UUID -- AI bot
    );

CREATE POLICY "chat_messages_update" ON chat_messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (
                c.created_by = auth.uid()
                OR c.assigned_to = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM chat_participants cp
                    WHERE cp.conversation_id = c.id
                    AND cp.user_id = auth.uid()
                )
            )
        )
    );

-- ============================================================
-- 5. RPC: Crear chat grupal (con todos los empleados activos)
-- ============================================================

CREATE OR REPLACE FUNCTION create_group_chat(
    p_title TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conversation_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    -- Crear conversación de grupo
    INSERT INTO chat_conversations (title, type, status, created_by, metadata)
    VALUES (
        p_title,
        'group',
        'open',
        v_user_id,
        jsonb_build_object('description', COALESCE(p_description, ''))
    )
    RETURNING id INTO v_conversation_id;

    -- Agregar a TODOS los usuarios activos como participantes
    INSERT INTO chat_participants (conversation_id, user_id, role)
    SELECT v_conversation_id, up.user_id,
        CASE WHEN up.user_id = v_user_id THEN 'admin' ELSE 'member' END
    FROM user_profiles up
    WHERE up.is_active = true;

    -- Mensaje de sistema
    INSERT INTO chat_messages (conversation_id, sender_id, content, message_type)
    VALUES (
        v_conversation_id,
        v_user_id,
        '🎉 Grupo "' || p_title || '" creado',
        'system'
    );

    RETURN v_conversation_id;
END;
$$;

-- ============================================================
-- 6. RPC: Crear chat individual con IA
-- ============================================================

CREATE OR REPLACE FUNCTION create_ai_chat()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_conversation_id UUID;
    v_user_id UUID := auth.uid();
    v_existing_id UUID;
BEGIN
    -- Buscar si ya tiene un chat con IA
    SELECT id INTO v_existing_id
    FROM chat_conversations
    WHERE type = 'ai_chat'
    AND created_by = v_user_id
    LIMIT 1;

    IF v_existing_id IS NOT NULL THEN
        RETURN v_existing_id;
    END IF;

    -- Crear conversación de IA
    INSERT INTO chat_conversations (title, type, status, created_by)
    VALUES ('Asistente IA', 'ai_chat', 'open', v_user_id)
    RETURNING id INTO v_conversation_id;

    -- Mensaje de bienvenida
    INSERT INTO chat_messages (
        conversation_id,
        sender_id,
        content,
        message_type
    ) VALUES (
        v_conversation_id,
        v_user_id,
        '🤖 ¡Hola! Soy tu asistente IA. Puedo ayudarte con consultas del negocio, inventario, facturas, calendario y más. ¿En qué te puedo ayudar?',
        'ai_response'
    );

    RETURN v_conversation_id;
END;
$$;

-- ============================================================
-- 7. RPC: Enviar mensaje de IA a una conversación
--    (se llama desde el Edge Function o el cliente)
-- ============================================================

CREATE OR REPLACE FUNCTION send_ai_message(
    p_conversation_id UUID,
    p_content TEXT,
    p_user_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_msg_id UUID;
    v_user_id UUID := auth.uid();
BEGIN
    -- Si hay mensaje del usuario, insertarlo primero como ai_request
    IF p_user_message IS NOT NULL THEN
        INSERT INTO chat_messages (conversation_id, sender_id, content, message_type)
        VALUES (p_conversation_id, v_user_id, p_user_message, 'ai_request');
    END IF;

    -- Insertar respuesta de IA
    INSERT INTO chat_messages (conversation_id, sender_id, content, message_type)
    VALUES (
        p_conversation_id,
        v_user_id, -- El sender es quien invocó la IA
        p_content,
        'ai_response'
    )
    RETURNING id INTO v_msg_id;

    RETURN v_msg_id;
END;
$$;

-- ============================================================
-- 8. Actualizar vista con soporte grupo + IA
-- ============================================================

DROP VIEW IF EXISTS v_chat_conversations;

CREATE VIEW v_chat_conversations AS
SELECT
    c.*,
    up_creator.display_name AS creator_name,
    up_creator.role AS creator_role,
    up_assigned.display_name AS assigned_name,
    up_assigned.role AS assigned_role,
    CASE
        WHEN c.type = 'ai_chat' THEN 'Asistente IA'
        WHEN c.type = 'group' THEN c.title
        WHEN c.created_by = auth.uid() THEN up_assigned.display_name
        ELSE up_creator.display_name
    END AS other_participant_name,
    CASE
        WHEN c.type = 'ai_chat' THEN 'ai'
        WHEN c.type = 'group' THEN 'group'
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
    ar.request_data,
    (
        SELECT COUNT(*)::int FROM chat_participants cp
        WHERE cp.conversation_id = c.id
    ) AS participant_count
FROM chat_conversations c
LEFT JOIN user_profiles up_creator ON up_creator.user_id = c.created_by
LEFT JOIN user_profiles up_assigned ON up_assigned.user_id = c.assigned_to
LEFT JOIN approval_requests ar ON ar.conversation_id = c.id
ORDER BY c.updated_at DESC;
