-- ============================================================
-- 100: Romper ciclo de RLS entre conversaciones y participantes
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_chat_participant(
  p_conversation_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.chat_participants cp
    WHERE cp.conversation_id = p_conversation_id
      AND cp.user_id = p_user_id
  );
$$;

REVOKE ALL ON FUNCTION public.is_chat_participant(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_chat_participant(uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS "chat_participants_select" ON chat_participants;
DROP POLICY IF EXISTS "chat_participants_insert" ON chat_participants;
DROP POLICY IF EXISTS "chat_conversations_select" ON chat_conversations;
DROP POLICY IF EXISTS "chat_conversations_update" ON chat_conversations;
DROP POLICY IF EXISTS "chat_messages_select" ON chat_messages;
DROP POLICY IF EXISTS "chat_messages_update" ON chat_messages;

CREATE POLICY "chat_participants_select" ON chat_participants
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_chat_participant(conversation_id, auth.uid())
  );

CREATE POLICY "chat_participants_insert" ON chat_participants
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.chat_conversations c
      WHERE c.id = conversation_id
        AND c.created_by = auth.uid()
    )
  );

CREATE POLICY "chat_conversations_select" ON chat_conversations
  FOR SELECT USING (
    auth.uid() = created_by
    OR auth.uid() = assigned_to
    OR public.is_chat_participant(id, auth.uid())
  );

CREATE POLICY "chat_conversations_update" ON chat_conversations
  FOR UPDATE USING (
    auth.uid() = created_by
    OR auth.uid() = assigned_to
    OR public.is_chat_participant(id, auth.uid())
  );

CREATE POLICY "chat_messages_select" ON chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM public.chat_conversations c
      WHERE c.id = conversation_id
        AND (
          auth.uid() = c.created_by
          OR auth.uid() = c.assigned_to
          OR public.is_chat_participant(c.id, auth.uid())
        )
    )
  );

CREATE POLICY "chat_messages_update" ON chat_messages
  FOR UPDATE USING (
    EXISTS (
      SELECT 1
      FROM public.chat_conversations c
      WHERE c.id = conversation_id
        AND (
          auth.uid() = c.created_by
          OR auth.uid() = c.assigned_to
          OR public.is_chat_participant(c.id, auth.uid())
        )
    )
  );