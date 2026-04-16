-- ============================================================
-- 101: Cerrar brechas de privacidad en el sistema de chat
-- ============================================================
-- GAP 1: chat_messages INSERT no verificaba membresía en conversación
-- GAP 2: v_chat_conversations view sin security_invoker (bypass RLS)
-- GAP 3: approval_requests SELECT sin verificar participantes
-- ============================================================

-- ============================================================
-- 1. FIX: INSERT de mensajes debe verificar que el usuario
--    sea participante de la conversación
-- ============================================================

DROP POLICY IF EXISTS "chat_messages_insert" ON chat_messages;

CREATE POLICY "chat_messages_insert" ON chat_messages
    FOR INSERT WITH CHECK (
        -- El bot de IA siempre puede insertar
        sender_id = '00000000-0000-0000-0000-000000000000'::UUID
        OR (
            -- El sender debe ser el usuario autenticado
            auth.uid() = sender_id
            AND
            -- Y debe ser participante de la conversación
            EXISTS (
                SELECT 1 FROM chat_conversations c
                WHERE c.id = conversation_id
                AND (
                    c.created_by = auth.uid()
                    OR c.assigned_to = auth.uid()
                    OR public.is_chat_participant(c.id, auth.uid())
                )
            )
        )
    );

-- ============================================================
-- 2. FIX: Recrear la vista v_chat_conversations con
--    security_invoker = on para que respete RLS del usuario
-- ============================================================

DROP VIEW IF EXISTS v_chat_conversations;

CREATE VIEW v_chat_conversations
WITH (security_invoker = on)
AS
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
        SELECT content
        FROM chat_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC,
                 CASE WHEN m.message_type = 'ai_response' THEN 1 ELSE 0 END DESC,
                 m.id DESC
        LIMIT 1
    ) AS last_message,
    (
        SELECT created_at
        FROM chat_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC,
                 CASE WHEN m.message_type = 'ai_response' THEN 1 ELSE 0 END DESC,
                 m.id DESC
        LIMIT 1
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

-- ============================================================
-- 3. FIX: approval_requests SELECT debe incluir participantes
-- ============================================================

DROP POLICY IF EXISTS "approval_select" ON approval_requests;
DROP POLICY IF EXISTS "approval_requests_select" ON approval_requests;

CREATE POLICY "approval_requests_select" ON approval_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (
                c.created_by = auth.uid()
                OR c.assigned_to = auth.uid()
                OR public.is_chat_participant(c.id, auth.uid())
            )
        )
    );

-- ============================================================
-- Resumen de seguridad post-migración:
-- ============================================================
-- chat_conversations: SELECT/UPDATE → created_by OR assigned_to OR is_chat_participant
-- chat_messages:      SELECT/UPDATE → misma regla vía join a conversations
--                     INSERT → sender=auth.uid() + debe ser participante (o AI bot)
-- chat_participants:  SELECT → user_id=auth.uid() OR is_chat_participant
--                     INSERT → solo el creador de la conversación
-- approval_requests:  SELECT → participante de la conversación asociada
-- v_chat_conversations: security_invoker=on → respeta RLS del usuario que consulta
-- ============================================================
