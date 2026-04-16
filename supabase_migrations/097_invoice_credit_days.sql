-- ============================================================
-- Migration 097: Agregar credit_days a invoices
-- ============================================================
-- Almacena los días de crédito para poder recalcular due_date
-- cuando la entrega real difiere de la estimada.
-- El reloj de pago empieza desde la ENTREGA, no desde la emisión.
-- ============================================================

-- 1. Agregar columna credit_days
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS credit_days INTEGER DEFAULT 0;

-- 2. Poblar credit_days para facturas existentes de crédito/adelanto
--    basándose en la diferencia entre due_date y (delivery_date o issue_date)
UPDATE invoices
SET credit_days = GREATEST(
  (due_date - COALESCE(delivery_date, issue_date::date))::int,
  0
)
WHERE due_date IS NOT NULL
  AND sale_payment_type IN ('credit', 'advance')
  AND credit_days = 0;

-- 3. Comentario para documentar
COMMENT ON COLUMN invoices.credit_days IS 
  'Días de crédito desde entrega. El vencimiento se recalcula al confirmar entrega real.';
