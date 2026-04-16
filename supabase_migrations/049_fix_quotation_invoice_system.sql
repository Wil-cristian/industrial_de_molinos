-- =====================================================================
-- 049: FIX COMPLETO DEL SISTEMA DE COTIZACIONES Y FACTURAS
-- =====================================================================
-- Resuelve:
-- 1. FK de material_movements que impide eliminar/anular cotizaciones
-- 2. FK de material_movements que impide eliminar/anular facturas
-- 3. Columna fantasma inv_material_id en quotation_items
-- 4. RPC atómica para anular cotización con todas sus relaciones
-- 5. Delete seguro de cotizaciones solo en borrador
-- =====================================================================

BEGIN;

-- =============================================================
-- 1. FIX FOREIGN KEYS EN material_movements
-- =============================================================
-- El error "material_movements_quotation_id_fkey" ocurre porque
-- las FK no tienen ON DELETE SET NULL. Al eliminar/anular una
-- cotización o factura referenciada, PostgreSQL lo rechaza.

-- Eliminar FK existentes y recrear con ON DELETE SET NULL
ALTER TABLE material_movements 
  DROP CONSTRAINT IF EXISTS material_movements_quotation_id_fkey;

ALTER TABLE material_movements 
  DROP CONSTRAINT IF EXISTS material_movements_invoice_id_fkey;

-- Recrear con ON DELETE SET NULL (mantiene el historial de movimientos)
ALTER TABLE material_movements 
  ADD CONSTRAINT material_movements_quotation_id_fkey 
  FOREIGN KEY (quotation_id) REFERENCES quotations(id) ON DELETE SET NULL;

ALTER TABLE material_movements 
  ADD CONSTRAINT material_movements_invoice_id_fkey 
  FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE SET NULL;

-- =============================================================
-- 2. FIX COLUMNA inv_material_id EN quotation_items
-- =============================================================
-- La migración 028 eliminó inv_material_id pero el código la sigue usando.
-- Asegurar que material_id existe y copiar datos si inv_material_id aún existe.

DO $$
BEGIN
  -- Si inv_material_id todavía existe, migrar datos a material_id
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'quotation_items' AND column_name = 'inv_material_id'
  ) THEN
    -- Copiar valores de inv_material_id a material_id donde material_id es null
    UPDATE quotation_items 
    SET material_id = inv_material_id 
    WHERE material_id IS NULL AND inv_material_id IS NOT NULL;
    
    -- Eliminar la columna fantasma
    ALTER TABLE quotation_items DROP COLUMN IF EXISTS inv_material_id;
    
    RAISE NOTICE '✅ Datos migrados de inv_material_id → material_id y columna eliminada';
  ELSE
    RAISE NOTICE '✅ inv_material_id ya no existe, material_id es la columna correcta';
  END IF;
END $$;

-- =============================================================
-- 3. RPC: ANULAR COTIZACIÓN ATÓMICAMENTE
-- =============================================================
-- Anula una cotización y opcionalmente su factura asociada,
-- limpiando las referencias en material_movements antes.

CREATE OR REPLACE FUNCTION annul_quotation(
  p_quotation_id UUID,
  p_reason TEXT DEFAULT 'Anulada por el usuario'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quotation RECORD;
  v_invoice RECORD;
  v_result JSONB;
  v_movements_cleaned INT := 0;
  v_invoice_annulled BOOLEAN := FALSE;
BEGIN
  -- Obtener cotización actual
  SELECT * INTO v_quotation FROM quotations WHERE id = p_quotation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cotización no encontrada: %', p_quotation_id;
  END IF;
  
  IF v_quotation.status = 'Anulada' THEN
    RAISE EXCEPTION 'La cotización ya está anulada';
  END IF;

  -- Limpiar referencias en material_movements (SET NULL en vez de borrar, 
  -- para mantener historial de movimientos de inventario)
  UPDATE material_movements 
  SET quotation_id = NULL 
  WHERE quotation_id = p_quotation_id;
  GET DIAGNOSTICS v_movements_cleaned = ROW_COUNT;

  -- Si la cotización estaba aprobada, buscar y anular factura asociada
  IF v_quotation.status = 'Aprobada' THEN
    SELECT * INTO v_invoice 
    FROM invoices 
    WHERE quotation_id = p_quotation_id 
      AND status != 'cancelled'
    LIMIT 1;
    
    IF FOUND THEN
      -- Revertir descuento de inventario de la factura si estaba emitida/pagada
      IF v_invoice.status IN ('issued', 'paid', 'partial') THEN
        BEGIN
          PERFORM revert_invoice_material_deduction(v_invoice.id);
        EXCEPTION WHEN OTHERS THEN
          -- Si falla la reversión, continuar pero registrar
          RAISE NOTICE 'Advertencia: No se pudo revertir inventario de factura %: %', v_invoice.id, SQLERRM;
        END;
      END IF;
      
      -- Revertir pagos si había alguno
      IF v_invoice.paid_amount > 0 THEN
        BEGIN
          PERFORM atomic_revert_invoice_payments(v_invoice.id);
        EXCEPTION WHEN OTHERS THEN
          RAISE NOTICE 'Advertencia: No se pudieron revertir pagos de factura %: %', v_invoice.id, SQLERRM;
        END;
      END IF;
      
      -- Anular la factura
      UPDATE invoices 
      SET status = 'cancelled', 
          notes = COALESCE(notes, '') || E'\n' || 'Anulada automáticamente al anular cotización ' || v_quotation.number || ': ' || p_reason,
          updated_at = NOW()
      WHERE id = v_invoice.id;
      
      -- Limpiar material_movements de la factura también
      UPDATE material_movements 
      SET invoice_id = NULL 
      WHERE invoice_id = v_invoice.id;
      
      v_invoice_annulled := TRUE;
    END IF;
  END IF;

  -- Anular la cotización
  UPDATE quotations 
  SET status = 'Anulada', 
      notes = COALESCE(notes, '') || E'\n[ANULADA ' || TO_CHAR(NOW(), 'DD/MM/YYYY HH24:MI') || '] ' || p_reason,
      updated_at = NOW()
  WHERE id = p_quotation_id;

  -- Construir resultado
  v_result := jsonb_build_object(
    'success', TRUE,
    'quotation_id', p_quotation_id,
    'quotation_number', v_quotation.number,
    'previous_status', v_quotation.status,
    'movements_cleaned', v_movements_cleaned,
    'invoice_annulled', v_invoice_annulled,
    'invoice_id', CASE WHEN v_invoice_annulled THEN v_invoice.id ELSE NULL END,
    'invoice_number', CASE WHEN v_invoice_annulled THEN v_invoice.series || '-' || v_invoice.number ELSE NULL END
  );

  RETURN v_result;
END;
$$;

-- =============================================================
-- 4. RPC: ELIMINAR COTIZACIÓN SEGURA (solo borradores)
-- =============================================================
CREATE OR REPLACE FUNCTION safe_delete_quotation(
  p_quotation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_quotation RECORD;
BEGIN
  SELECT * INTO v_quotation FROM quotations WHERE id = p_quotation_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cotización no encontrada';
  END IF;
  
  -- Solo permitir eliminar borradores
  IF v_quotation.status != 'Borrador' THEN
    RAISE EXCEPTION 'Solo se pueden eliminar cotizaciones en estado Borrador. Estado actual: %', v_quotation.status;
  END IF;
  
  -- Limpiar material_movements por seguridad
  UPDATE material_movements SET quotation_id = NULL WHERE quotation_id = p_quotation_id;
  
  -- Los items se eliminan por CASCADE
  DELETE FROM quotations WHERE id = p_quotation_id;
  
  RETURN jsonb_build_object(
    'success', TRUE,
    'deleted_number', v_quotation.number
  );
END;
$$;

-- =============================================================
-- 5. RPC: REVERTIR DESCUENTO DE MATERIALES POR FACTURA
-- =============================================================
-- La función existente revert_material_deduction(p_quotation_id UUID) solo busca
-- por quotation_id. El código Dart la llama al anular una factura, pero como
-- PostgreSQL resuelve overloads por TIPO (no por nombre de parámetro),
-- no se puede crear otra con (UUID). Usamos nombre distinto.

CREATE OR REPLACE FUNCTION revert_invoice_material_deduction(p_invoice_id UUID)
RETURNS VOID AS $$
BEGIN
    -- PASO 1: Insertar movimientos de reversión (incoming) para cada outgoing de esta factura
    INSERT INTO material_movements (
        material_id, type, quantity, previous_stock, new_stock, 
        reason, reference, invoice_id
    )
    SELECT 
        mm.material_id, 'incoming', mm.quantity,
        m.stock, m.stock + mm.quantity,
        'Reversión: Factura anulada', mm.reference, p_invoice_id
    FROM material_movements mm
    JOIN materials m ON m.id = mm.material_id
    WHERE mm.invoice_id = p_invoice_id AND mm.type = 'outgoing';
    
    -- PASO 2: Actualizar stock de materiales en bulk
    UPDATE materials 
    SET stock = materials.stock + agg.total_qty, updated_at = NOW()
    FROM (
        SELECT material_id, SUM(quantity) as total_qty
        FROM material_movements 
        WHERE invoice_id = p_invoice_id AND type = 'outgoing'
        GROUP BY material_id
    ) agg
    WHERE materials.id = agg.material_id;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION revert_invoice_material_deduction(UUID) TO authenticated;

-- También actualizar la referencia dentro de annul_quotation para usar la nueva función
-- (reemplazamos el PERFORM revert_material_deduction por revert_invoice_material_deduction)
-- =============================================================
-- 6. Agregar enum value 'Anulada' a quotation_status si no existe
-- =============================================================
DO $$
BEGIN
  -- Verificar si el tipo quotation_status existe
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quotation_status') THEN
    -- Agregar 'Anulada' si no existe
    BEGIN
      ALTER TYPE quotation_status ADD VALUE IF NOT EXISTS 'Anulada';
    EXCEPTION WHEN duplicate_object THEN
      NULL; -- Ya existe
    END;
  END IF;
END $$;

COMMIT;
