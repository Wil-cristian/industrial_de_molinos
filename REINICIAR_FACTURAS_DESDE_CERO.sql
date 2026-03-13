-- =====================================================
-- REINICIAR_FACTURAS_DESDE_CERO.sql
-- Limpia informacion relacionada con facturas para iniciar de cero.
--
-- Incluye:
-- 1) Facturas de ventas/comprobantes y sus items/pagos/intereses
-- 2) Facturas de IVA (iva_invoices)
-- 3) Movimientos de inventario creados por escaneo de facturas
-- 4) Materiales auto-creados desde facturas escaneadas
-- 5) Movimientos de caja creados por facturas de compra escaneadas
-- 6) Deuda de proveedores (current_debt) reseteada a 0
--
-- Ejecutar en Supabase SQL Editor.
-- =====================================================

BEGIN;

-- -----------------------------------------------------
-- A) INVENTARIO: revertir impacto de movimientos por factura
-- -----------------------------------------------------
-- Ajusta stock restando entradas registradas por factura escaneada
-- (referencia FAC-* o reason "Ingreso por factura ...").
DO $$
BEGIN
  IF to_regclass('public.material_movements') IS NOT NULL
     AND to_regclass('public.materials') IS NOT NULL THEN

    WITH qty_by_material AS (
      SELECT
        material_id,
        SUM(COALESCE(quantity, 0)) AS total_qty
      FROM material_movements
      WHERE material_id IS NOT NULL
        AND (
          COALESCE(reason, '') ILIKE 'Ingreso por factura %'
          OR COALESCE(reference, '') LIKE 'FAC-%'
        )
      GROUP BY material_id
    )
    UPDATE materials m
    SET
      stock = GREATEST(0, COALESCE(m.stock, 0) - q.total_qty),
      updated_at = NOW()
    FROM qty_by_material q
    WHERE m.id = q.material_id;

    DELETE FROM material_movements
    WHERE (
      COALESCE(reason, '') ILIKE 'Ingreso por factura %'
      OR COALESCE(reference, '') LIKE 'FAC-%'
    );

    -- Borra materiales auto-creados por el escaner de factura.
    DELETE FROM materials
    WHERE COALESCE(description, '') ILIKE 'Creado autom% desde factura %';
  END IF;
END $$;

-- -----------------------------------------------------
-- B) IVA: borrar facturas IVA y liquidaciones
-- -----------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.iva_invoices') IS NOT NULL THEN
    TRUNCATE TABLE iva_invoices CASCADE;
  END IF;

  IF to_regclass('public.iva_bimonthly_settlements') IS NOT NULL THEN
    TRUNCATE TABLE iva_bimonthly_settlements CASCADE;
  END IF;
END $$;

-- -----------------------------------------------------
-- C) FACTURAS CORE: ventas/comprobantes y dependencias
-- -----------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.invoice_interests') IS NOT NULL THEN
    TRUNCATE TABLE invoice_interests CASCADE;
  END IF;

  IF to_regclass('public.invoice_items') IS NOT NULL THEN
    TRUNCATE TABLE invoice_items CASCADE;
  END IF;

  IF to_regclass('public.payments') IS NOT NULL THEN
    TRUNCATE TABLE payments CASCADE;
  END IF;

  IF to_regclass('public.invoices') IS NOT NULL THEN
    TRUNCATE TABLE invoices CASCADE;
  END IF;

  IF to_regclass('public.cancellation_audit_log') IS NOT NULL THEN
    TRUNCATE TABLE cancellation_audit_log CASCADE;
  END IF;
END $$;

-- -----------------------------------------------------
-- D) CONTABILIDAD/SUPPLIERS relacionados a facturas compra IA
-- -----------------------------------------------------
DO $$
BEGIN
  IF to_regclass('public.cash_movements') IS NOT NULL THEN
    DELETE FROM cash_movements
    WHERE COALESCE(description, '') ILIKE 'Factura % - %';
  END IF;

  IF to_regclass('public.proveedores') IS NOT NULL THEN
    UPDATE proveedores
    SET current_debt = 0
    WHERE COALESCE(current_debt, 0) <> 0;
  END IF;
END $$;

COMMIT;

-- -----------------------------------------------------
-- RESUMEN RAPIDO (post-limpieza)
-- -----------------------------------------------------
SELECT 'invoices' AS tabla, COUNT(*) AS total FROM invoices
UNION ALL
SELECT 'invoice_items', COUNT(*) FROM invoice_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'invoice_interests', COUNT(*) FROM invoice_interests
UNION ALL
SELECT 'iva_invoices', COUNT(*) FROM iva_invoices
UNION ALL
SELECT 'material_movements', COUNT(*) FROM material_movements;
