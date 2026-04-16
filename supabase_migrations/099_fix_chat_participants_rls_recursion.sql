-- ============================================================
-- 099: Corregir recursión RLS en chat_participants
-- ============================================================

DROP POLICY IF EXISTS "chat_participants_select" ON chat_participants;
DROP POLICY IF EXISTS "chat_participants_insert" ON chat_participants;

CREATE POLICY "chat_participants_select" ON chat_participants
    FOR SELECT USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1
            FROM chat_conversations c
            WHERE c.id = chat_participants.conversation_id
              AND (c.created_by = auth.uid() OR c.assigned_to = auth.uid())
        )
    );

CREATE POLICY "chat_participants_insert" ON chat_participants
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1
            FROM chat_conversations c
            WHERE c.id = conversation_id
              AND c.created_by = auth.uid()
        )
    );