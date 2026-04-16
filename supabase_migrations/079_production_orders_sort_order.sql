-- Migration 079: Add sort_order to production_orders for manual drag-reorder
ALTER TABLE production_orders ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0;

-- Populate sort_order based on current priority + due date ordering
WITH ranked AS (
  SELECT id,
    ROW_NUMBER() OVER (
      ORDER BY 
        CASE priority 
          WHEN 'urgente' THEN 0 
          WHEN 'alta' THEN 1 
          WHEN 'media' THEN 2 
          WHEN 'baja' THEN 3 
        END,
        due_date ASC NULLS LAST,
        created_at ASC
    ) as rn
  FROM production_orders
)
UPDATE production_orders SET sort_order = ranked.rn
FROM ranked WHERE production_orders.id = ranked.id;
