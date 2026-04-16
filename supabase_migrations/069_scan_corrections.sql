-- =====================================================
-- 069: Tabla scan_corrections – Aprendizaje por correcciones de escaneo IA
-- =====================================================
-- Almacena las diferencias entre lo que la IA leyó y lo que el usuario corrigió.
-- Se usan como few-shot examples para mejorar futuros escaneos.

CREATE TABLE IF NOT EXISTS scan_corrections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Tipo: 'purchase' o 'sale'
  correction_type TEXT NOT NULL CHECK (correction_type IN ('purchase', 'sale')),

  -- Contexto del documento
  supplier_name TEXT,
  document_type TEXT, -- factura, recibo, abono, etc.

  -- Datos originales de la IA (los campos key)
  original_total NUMERIC,
  original_subtotal NUMERIC,
  original_tax_rate NUMERIC,
  original_tax_amount NUMERIC,
  original_invoice_number TEXT,
  original_items_json JSONB,

  -- Datos corregidos por el usuario
  corrected_total NUMERIC,
  corrected_subtotal NUMERIC,
  corrected_tax_rate NUMERIC,
  corrected_tax_amount NUMERIC,
  corrected_invoice_number TEXT,
  corrected_items_json JSONB,

  -- Resumen legible de la corrección (para el prompt)
  corrections_summary TEXT NOT NULL,

  -- Referencia a la imagen (para debugging)
  image_ref TEXT
);

-- Índice para buscar correcciones recientes
CREATE INDEX idx_scan_corrections_created ON scan_corrections (created_at DESC);

-- RLS: permitir acceso autenticado
ALTER TABLE scan_corrections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read scan_corrections"
  ON scan_corrections FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert scan_corrections"
  ON scan_corrections FOR INSERT
  TO authenticated
  WITH CHECK (true);
