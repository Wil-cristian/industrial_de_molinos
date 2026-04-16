-- ============================================================
-- 095: Sistema de Chat y Aprobaciones
-- ============================================================

-- 1. Tabla de conversaciones
CREATE TABLE IF NOT EXISTS chat_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('transfer_approval', 'purchase_approval', 'expense_approval', 'general')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'pending', 'approved', 'rejected', 'closed')),
    created_by UUID NOT NULL REFERENCES auth.users(id),
    assigned_to UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- 2. Tabla de mensajes
CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    content TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'approval_request', 'approval_response', 'system')),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_read BOOLEAN NOT NULL DEFAULT false
);

-- 3. Tabla de solicitudes de aprobación
CREATE TABLE IF NOT EXISTS approval_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
    request_type TEXT NOT NULL CHECK (request_type IN ('transfer', 'material_purchase', 'expense', 'general')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_by UUID NOT NULL REFERENCES auth.users(id),
    resolved_by UUID REFERENCES auth.users(id),
    request_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT
);

-- ============================================================
-- ÍNDICES
-- ============================================================

CREATE INDEX idx_chat_conversations_created_by ON chat_conversations(created_by);
CREATE INDEX idx_chat_conversations_assigned_to ON chat_conversations(assigned_to);
CREATE INDEX idx_chat_conversations_status ON chat_conversations(status);
CREATE INDEX idx_chat_conversations_type ON chat_conversations(type);
CREATE INDEX idx_chat_conversations_updated_at ON chat_conversations(updated_at DESC);

CREATE INDEX idx_chat_messages_conversation_id ON chat_messages(conversation_id);
CREATE INDEX idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at);
CREATE INDEX idx_chat_messages_unread ON chat_messages(conversation_id, is_read) WHERE is_read = false;

CREATE INDEX idx_approval_requests_conversation_id ON approval_requests(conversation_id);
CREATE INDEX idx_approval_requests_requested_by ON approval_requests(requested_by);
CREATE INDEX idx_approval_requests_status ON approval_requests(status);

-- ============================================================
-- TRIGGER: auto-update updated_at en conversación
-- ============================================================

CREATE OR REPLACE FUNCTION trg_chat_conversation_updated()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chat_conversations
    SET updated_at = now()
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER chat_message_updates_conversation
    AFTER INSERT ON chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION trg_chat_conversation_updated();

-- ============================================================
-- RLS POLICIES
-- ============================================================

ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_requests ENABLE ROW LEVEL SECURITY;

-- Conversaciones: creador o asignado o admin/dueño pueden ver
CREATE POLICY "chat_conversations_select" ON chat_conversations
    FOR SELECT USING (
        auth.uid() = created_by
        OR auth.uid() = assigned_to
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin', 'dueno', 'tecnico')
            AND is_active = true
        )
    );

CREATE POLICY "chat_conversations_insert" ON chat_conversations
    FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE POLICY "chat_conversations_update" ON chat_conversations
    FOR UPDATE USING (
        auth.uid() = created_by
        OR auth.uid() = assigned_to
        OR EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin', 'dueno', 'tecnico')
            AND is_active = true
        )
    );

-- Mensajes: pertenecen a conversaciones visibles
CREATE POLICY "chat_messages_select" ON chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (
                c.created_by = auth.uid()
                OR c.assigned_to = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM user_profiles
                    WHERE user_id = auth.uid()
                    AND role IN ('admin', 'dueno', 'tecnico')
                    AND is_active = true
                )
            )
        )
    );

CREATE POLICY "chat_messages_insert" ON chat_messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "chat_messages_update" ON chat_messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (
                c.created_by = auth.uid()
                OR c.assigned_to = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM user_profiles
                    WHERE user_id = auth.uid()
                    AND role IN ('admin', 'dueno', 'tecnico')
                    AND is_active = true
                )
            )
        )
    );

-- Approval requests: misma lógica
CREATE POLICY "approval_requests_select" ON approval_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_conversations c
            WHERE c.id = conversation_id
            AND (
                c.created_by = auth.uid()
                OR c.assigned_to = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM user_profiles
                    WHERE user_id = auth.uid()
                    AND role IN ('admin', 'dueno', 'tecnico')
                    AND is_active = true
                )
            )
        )
    );

CREATE POLICY "approval_requests_insert" ON approval_requests
    FOR INSERT WITH CHECK (auth.uid() = requested_by);

CREATE POLICY "approval_requests_update" ON approval_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND role IN ('admin', 'dueno', 'tecnico')
            AND is_active = true
        )
    );

-- ============================================================
-- VISTA: conversaciones con info extra
-- ============================================================

CREATE OR REPLACE VIEW v_chat_conversations AS
SELECT
    c.*,
    up_creator.display_name AS creator_name,
    up_creator.role AS creator_role,
    up_assigned.display_name AS assigned_name,
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

-- ============================================================
-- RPC: Crear solicitud completa (conversación + mensaje + approval)
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
-- RPC: Resolver solicitud (aprobar/rechazar)
-- ============================================================

CREATE OR REPLACE FUNCTION resolve_approval_request(
    p_conversation_id UUID,
    p_status TEXT,  -- 'approved' o 'rejected'
    p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_status_label TEXT;
BEGIN
    -- Verificar rol
    SELECT role INTO v_role FROM user_profiles WHERE user_id = v_user_id AND is_active = true;
    IF v_role NOT IN ('admin', 'dueno', 'tecnico') THEN
        RAISE EXCEPTION 'No tiene permisos para aprobar/rechazar solicitudes';
    END IF;

    -- Actualizar solicitud
    UPDATE approval_requests
    SET status = p_status,
        resolved_by = v_user_id,
        resolved_at = now(),
        notes = p_notes
    WHERE conversation_id = p_conversation_id
    AND status = 'pending';

    -- Actualizar conversación
    UPDATE chat_conversations
    SET status = p_status,
        resolved_at = now(),
        updated_at = now()
    WHERE id = p_conversation_id;

    -- Agregar mensaje del sistema
    IF p_status = 'approved' THEN
        v_status_label := '✅ Solicitud aprobada';
    ELSE
        v_status_label := '❌ Solicitud rechazada';
    END IF;

    IF p_notes IS NOT NULL AND p_notes != '' THEN
        v_status_label := v_status_label || ': ' || p_notes;
    END IF;

    INSERT INTO chat_messages (conversation_id, sender_id, content, message_type)
    VALUES (p_conversation_id, v_user_id, v_status_label, 'approval_response');
END;
$$;
