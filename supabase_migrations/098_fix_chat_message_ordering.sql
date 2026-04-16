-- ============================================================
-- 098: Ajustar orden de mensajes y preview de conversación
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