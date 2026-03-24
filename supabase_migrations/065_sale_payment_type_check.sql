-- ============================================================
-- 065: Agregar CHECK constraint para sale_payment_type
-- Asegura que solo los valores válidos se puedan insertar
-- ============================================================

-- Agregar CHECK constraint (solo si no existe)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'invoices_sale_payment_type_check'
  ) THEN
    ALTER TABLE invoices
      ADD CONSTRAINT invoices_sale_payment_type_check
      CHECK (sale_payment_type IN ('cash', 'credit', 'advance'));
  END IF;
END $$;

-- Actualizar comentario del campo
COMMENT ON COLUMN invoices.sale_payment_type IS 'Tipo de venta: cash (contado), credit (crédito), advance (adelanto parcial)';
