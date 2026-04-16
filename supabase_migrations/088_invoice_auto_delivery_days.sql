-- 088_invoice_auto_delivery_days.sql
-- Configuración de días automáticos para fecha de entrega en facturas.

ALTER TABLE company_settings
ADD COLUMN IF NOT EXISTS auto_delivery_days INTEGER NOT NULL DEFAULT 1;

-- Validación simple para evitar valores fuera de rango razonable.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'company_settings_auto_delivery_days_check'
  ) THEN
    ALTER TABLE company_settings
    ADD CONSTRAINT company_settings_auto_delivery_days_check
    CHECK (auto_delivery_days >= 0 AND auto_delivery_days <= 30);
  END IF;
END $$;
