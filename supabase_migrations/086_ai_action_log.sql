-- ============================================
-- 086: Tabla de log de acciones para aprendizaje de IA
-- Registra cada acción del usuario para que la IA
-- aprenda los patrones de uso y pueda replicarlos.
-- ============================================

CREATE TABLE IF NOT EXISTS ai_action_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  action_type TEXT NOT NULL,        -- 'crear_factura', 'aprobar_oc', etc.
  module TEXT NOT NULL,             -- 'facturas', 'produccion', 'compras', etc.
  entity_id TEXT,                   -- ID del registro afectado
  entity_name TEXT,                 -- Nombre descriptivo (ej: "Factura FAC-001")
  parameters JSONB DEFAULT '{}',   -- Parametros usados en la accion
  context JSONB DEFAULT '{}',      -- Contexto adicional (pagina, filtros activos)
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Indice para consultas por usuario y fecha
CREATE INDEX idx_ai_action_log_user ON ai_action_log(user_id, created_at DESC);
CREATE INDEX idx_ai_action_log_type ON ai_action_log(action_type, created_at DESC);
CREATE INDEX idx_ai_action_log_module ON ai_action_log(module, created_at DESC);

-- RLS
ALTER TABLE ai_action_log ENABLE ROW LEVEL SECURITY;

-- Cada usuario solo ve sus propias acciones
CREATE POLICY "Users can view own action logs"
  ON ai_action_log FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own action logs"
  ON ai_action_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Limpiar logs antiguos (mas de 90 dias) - ejecutar periodicamente
-- DELETE FROM ai_action_log WHERE created_at < now() - INTERVAL '90 days';
