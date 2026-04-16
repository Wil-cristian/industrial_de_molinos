-- =====================================================
-- 053: CAMPOS DE FACTURA EN ÓRDENES DE COMPRA
-- =====================================================
-- Agrega campos faltantes para almacenar información completa
-- de facturas de compra colombianas (DIAN) y vincular con IVA.
--
-- Campos nuevos en purchase_orders:
--   - supplier_invoice_number: Número de factura del proveedor (FE 4196)
--   - supplier_invoice_date: Fecha de la factura del proveedor
--   - cufe: Código Único de Facturación Electrónica (DIAN Colombia)
--   - tax_rate: Tasa de IVA aplicada (19%, 5%, 0%)
--   - retention_rte_fte: Retención en la Fuente
--   - retention_ica: Retención de ICA (municipal)
--   - retention_iva: Retención de IVA
--   - freight_amount: Valor de fletes
--   - attachments: Archivos adjuntos (fotos/PDFs de la factura)
--   - iva_invoice_id: Vínculo con tabla iva_invoices para liquidación IVA
--   - credit_days: Días de crédito
--   - due_date: Fecha de vencimiento (calculada o manual)
--
-- Campos nuevos en purchase_order_items:
--   - tax_rate: Tasa de IVA por ítem (pueden variar)
--   - tax_amount: Monto de IVA del ítem
--   - discount: Descuento por ítem
--   - reference_code: Código/referencia del proveedor para el ítem
--   - description: Descripción libre del ítem

-- ═══════════════════════════════════════════════════
-- 1. PURCHASE_ORDERS: campos de factura de proveedor
-- ═══════════════════════════════════════════════════

-- Número de factura del proveedor (ej: "FE 4196")
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS supplier_invoice_number VARCHAR(50);

-- Fecha de la factura del proveedor (puede diferir de created_at)
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS supplier_invoice_date DATE;

-- Código Único de Facturación Electrónica (DIAN Colombia)
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS cufe TEXT;

-- Tasa de IVA general aplicada (default 19% Colombia)
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5,2) DEFAULT 19.00;

-- Retención en la Fuente
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS retention_rte_fte DECIMAL(12,2) DEFAULT 0;

-- Retención de ICA (municipal)
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS retention_ica DECIMAL(12,2) DEFAULT 0;

-- Retención de IVA (ReteIVA)
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS retention_iva DECIMAL(12,2) DEFAULT 0;

-- Valor de fletes
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS freight_amount DECIMAL(12,2) DEFAULT 0;

-- Archivos adjuntos (fotos, PDFs de la factura)
-- Formato: [{"name": "factura_FE4196.jpg", "path": "purchase_orders/uuid/factura.jpg", "size": 12345, "type": "image/jpeg"}]
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb;

-- Vínculo con tabla de IVA para liquidación bimestral
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS iva_invoice_id UUID REFERENCES iva_invoices(id) ON DELETE SET NULL;

-- Días de crédito (ej: 15, 30, 60)
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS credit_days INTEGER DEFAULT 0;

-- Fecha de vencimiento
ALTER TABLE purchase_orders 
ADD COLUMN IF NOT EXISTS due_date DATE;

-- Índices
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_invoice 
ON purchase_orders(supplier_invoice_number);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_due_date 
ON purchase_orders(due_date) 
WHERE due_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_purchase_orders_iva_invoice 
ON purchase_orders(iva_invoice_id) 
WHERE iva_invoice_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_purchase_orders_has_attachments 
ON purchase_orders ((attachments != '[]'::jsonb))
WHERE attachments != '[]'::jsonb;

-- ═══════════════════════════════════════════════════
-- 2. PURCHASE_ORDER_ITEMS: campos de IVA y detalle
-- ═══════════════════════════════════════════════════

-- Tasa de IVA individual por ítem (puede ser 19%, 5%, 0%)
ALTER TABLE purchase_order_items 
ADD COLUMN IF NOT EXISTS tax_rate DECIMAL(5,2) DEFAULT 19.00;

-- Monto de IVA calculado del ítem
ALTER TABLE purchase_order_items 
ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(12,2) DEFAULT 0;

-- Descuento por ítem
ALTER TABLE purchase_order_items 
ADD COLUMN IF NOT EXISTS discount DECIMAL(12,2) DEFAULT 0;

-- Código de referencia del proveedor (ej: "BALLDIA1.5")
ALTER TABLE purchase_order_items 
ADD COLUMN IF NOT EXISTS reference_code VARCHAR(50);

-- Descripción libre del ítem
ALTER TABLE purchase_order_items 
ADD COLUMN IF NOT EXISTS description TEXT;

-- Total con IVA por ítem
ALTER TABLE purchase_order_items 
ADD COLUMN IF NOT EXISTS total DECIMAL(12,2) DEFAULT 0;

-- ═══════════════════════════════════════════════════
-- 3. IVA_INVOICES: campos adicionales para trazabilidad
-- ═══════════════════════════════════════════════════

-- NIT/documento del emisor de la factura
ALTER TABLE iva_invoices 
ADD COLUMN IF NOT EXISTS company_document VARCHAR(20);

-- CUFE para cruce con DIAN
ALTER TABLE iva_invoices 
ADD COLUMN IF NOT EXISTS cufe TEXT;

-- Vínculo inverso: de qué orden de compra viene
ALTER TABLE iva_invoices 
ADD COLUMN IF NOT EXISTS purchase_order_id UUID REFERENCES purchase_orders(id) ON DELETE SET NULL;

-- Retención en la Fuente (para cálculos IVA más completos)
ALTER TABLE iva_invoices 
ADD COLUMN IF NOT EXISTS rte_fte_amount DECIMAL(14,2) DEFAULT 0;

-- Retención ICA
ALTER TABLE iva_invoices 
ADD COLUMN IF NOT EXISTS rete_ica_amount DECIMAL(14,2) DEFAULT 0;

-- Índice
CREATE INDEX IF NOT EXISTS idx_iva_invoices_purchase_order 
ON iva_invoices(purchase_order_id) 
WHERE purchase_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_iva_invoices_company_document 
ON iva_invoices(company_document) 
WHERE company_document IS NOT NULL;

-- ═══════════════════════════════════════════════════
-- 4. FUNCIÓN: Crear registro IVA desde orden de compra
-- ═══════════════════════════════════════════════════
-- Cuando se recibe/aprueba una orden de compra con factura,
-- automáticamente crear el registro en iva_invoices para la
-- liquidación bimestral.

CREATE OR REPLACE FUNCTION create_iva_from_purchase_order(
    p_order_id UUID
)
RETURNS UUID
LANGUAGE plpgsql AS $$
DECLARE
    v_order RECORD;
    v_supplier RECORD;
    v_iva_id UUID;
    v_period TEXT;
    v_base DECIMAL(14,2);
    v_iva DECIMAL(14,2);
    v_has_reteiva BOOLEAN;
    v_reteiva DECIMAL(14,2);
BEGIN
    -- Obtener datos de la OC
    SELECT po.*, p.name AS supplier_name, p.document_number AS supplier_nit
    INTO v_order
    FROM purchase_orders po
    JOIN proveedores p ON p.id = po.supplier_id
    WHERE po.id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden de compra % no encontrada', p_order_id;
    END IF;

    -- Si no tiene número de factura, no crear registro IVA
    IF v_order.supplier_invoice_number IS NULL THEN
        RETURN NULL;
    END IF;

    -- Calcular periodo bimestral
    v_period := get_bimonthly_period(
        COALESCE(v_order.supplier_invoice_date, v_order.created_at::DATE)
    );

    -- Base = subtotal (sin IVA)
    v_base := v_order.subtotal;
    v_iva := v_order.tax_amount;

    -- ReteIVA: si hay retención de IVA registrada
    v_has_reteiva := COALESCE(v_order.retention_iva, 0) > 0;
    v_reteiva := COALESCE(v_order.retention_iva, 0);

    -- Crear o actualizar factura IVA
    INSERT INTO iva_invoices (
        invoice_number, invoice_date, company, company_document,
        invoice_type, base_amount, iva_amount, total_amount,
        has_reteiva, reteiva_amount, bimonthly_period,
        cufe, purchase_order_id, rte_fte_amount, rete_ica_amount,
        notes
    ) VALUES (
        v_order.supplier_invoice_number,
        COALESCE(v_order.supplier_invoice_date, v_order.created_at::DATE),
        v_order.supplier_name,
        v_order.supplier_nit,
        'COMPRA',
        v_base,
        v_iva,
        v_order.total,
        v_has_reteiva,
        v_reteiva,
        v_period,
        v_order.cufe,
        p_order_id,
        COALESCE(v_order.retention_rte_fte, 0),
        COALESCE(v_order.retention_ica, 0),
        'Generado automáticamente desde OC ' || v_order.order_number
    )
    RETURNING id INTO v_iva_id;

    -- Vincular la OC con el registro IVA
    UPDATE purchase_orders 
    SET iva_invoice_id = v_iva_id
    WHERE id = p_order_id;

    RETURN v_iva_id;
END;
$$;

-- ═══════════════════════════════════════════════════
-- 5. ACTUALIZAR vista bimestral para incluir retenciones
-- ═══════════════════════════════════════════════════
-- Hay que eliminar la vista primero porque se agregan columnas nuevas
-- y PostgreSQL no permite cambiar nombres de columnas con CREATE OR REPLACE.
DROP VIEW IF EXISTS v_iva_bimonthly_summary;

CREATE VIEW v_iva_bimonthly_summary AS
SELECT 
    bimonthly_period,
    SPLIT_PART(bimonthly_period, '-', 1)::INT AS year,
    SPLIT_PART(bimonthly_period, '-', 2)::INT AS bimester,
    get_bimester_name(SPLIT_PART(bimonthly_period, '-', 2)::INT) AS bimester_name,
    -- Ventas
    COALESCE(SUM(CASE WHEN invoice_type = 'VENTA' THEN base_amount ELSE 0 END), 0) AS base_ventas,
    COALESCE(SUM(CASE WHEN invoice_type = 'VENTA' THEN iva_amount ELSE 0 END), 0) AS iva_ventas,
    COALESCE(SUM(CASE WHEN invoice_type = 'VENTA' THEN total_amount ELSE 0 END), 0) AS total_ventas,
    COUNT(CASE WHEN invoice_type = 'VENTA' THEN 1 END) AS num_ventas,
    -- Compras
    COALESCE(SUM(CASE WHEN invoice_type = 'COMPRA' THEN base_amount ELSE 0 END), 0) AS base_compras,
    COALESCE(SUM(CASE WHEN invoice_type = 'COMPRA' THEN iva_amount ELSE 0 END), 0) AS iva_compras,
    COALESCE(SUM(CASE WHEN invoice_type = 'COMPRA' THEN total_amount ELSE 0 END), 0) AS total_compras,
    COUNT(CASE WHEN invoice_type = 'COMPRA' THEN 1 END) AS num_compras,
    -- Retenciones
    COALESCE(SUM(CASE WHEN has_reteiva THEN reteiva_amount ELSE 0 END), 0) AS total_reteiva,
    COALESCE(SUM(rte_fte_amount), 0) AS total_rte_fte,
    COALESCE(SUM(rete_ica_amount), 0) AS total_rete_ica,
    -- Totales
    COUNT(*) AS total_facturas
FROM iva_invoices
GROUP BY bimonthly_period
ORDER BY bimonthly_period DESC;

-- ═══════════════════════════════════════════════════
-- 6. ACTUALIZAR liquidación bimestral con retenciones
-- ═══════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION liquidar_bimestre(
    p_period TEXT,
    p_year INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_year INT;
    v_bimester INT;
    v_base_ventas DECIMAL(14,2);
    v_iva_ventas DECIMAL(14,2);
    v_base_compras DECIMAL(14,2);
    v_iva_compras DECIMAL(14,2);
    v_reteiva DECIMAL(14,2);
    v_rte_fte DECIMAL(14,2);
    v_rete_ica DECIMAL(14,2);
    v_iva_neto DECIMAL(14,2);
    v_anticipo DECIMAL(14,2);
    v_total DECIMAL(14,2);
    v_tarifa DECIMAL(5,4);
    v_config_year INT;
BEGIN
    v_year := SPLIT_PART(p_period, '-', 1)::INT;
    v_bimester := SPLIT_PART(p_period, '-', 2)::INT;
    v_config_year := COALESCE(p_year, v_year);

    -- Obtener tarifa simple del año
    SELECT tarifa_simple INTO v_tarifa
    FROM iva_config
    WHERE year = v_config_year;
    
    IF v_tarifa IS NULL THEN
        v_tarifa := 0.02;
    END IF;

    -- Calcular totales del periodo (incluyendo retenciones)
    SELECT 
        COALESCE(SUM(CASE WHEN invoice_type = 'VENTA' THEN base_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN invoice_type = 'VENTA' THEN iva_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN invoice_type = 'COMPRA' THEN base_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN invoice_type = 'COMPRA' THEN iva_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN has_reteiva THEN reteiva_amount ELSE 0 END), 0),
        COALESCE(SUM(rte_fte_amount), 0),
        COALESCE(SUM(rete_ica_amount), 0)
    INTO v_base_ventas, v_iva_ventas, v_base_compras, v_iva_compras, 
         v_reteiva, v_rte_fte, v_rete_ica
    FROM iva_invoices
    WHERE bimonthly_period = p_period;

    -- Calcular IVA neto y anticipo simple
    v_iva_neto := v_iva_ventas - v_iva_compras;
    v_anticipo := v_base_ventas * v_tarifa;
    v_total := v_iva_neto + v_anticipo - v_reteiva;

    -- Upsert en la tabla de liquidaciones
    INSERT INTO iva_bimonthly_settlements (
        bimonthly_period, year, bimester,
        total_base_ventas, total_iva_ventas,
        total_base_compras, total_iva_compras,
        iva_neto, anticipo_simple, reteiva_total, total_a_pagar
    ) VALUES (
        p_period, v_year, v_bimester,
        v_base_ventas, v_iva_ventas,
        v_base_compras, v_iva_compras,
        v_iva_neto, v_anticipo, v_reteiva, v_total
    )
    ON CONFLICT (bimonthly_period) DO UPDATE SET
        total_base_ventas = EXCLUDED.total_base_ventas,
        total_iva_ventas = EXCLUDED.total_iva_ventas,
        total_base_compras = EXCLUDED.total_base_compras,
        total_iva_compras = EXCLUDED.total_iva_compras,
        iva_neto = EXCLUDED.iva_neto,
        anticipo_simple = EXCLUDED.anticipo_simple,
        reteiva_total = EXCLUDED.reteiva_total,
        total_a_pagar = EXCLUDED.total_a_pagar,
        updated_at = now();

    RETURN jsonb_build_object(
        'period', p_period,
        'bimester_name', get_bimester_name(v_bimester),
        'year', v_year,
        'base_ventas', v_base_ventas,
        'iva_ventas', v_iva_ventas,
        'base_compras', v_base_compras,
        'iva_compras', v_iva_compras,
        'iva_neto', v_iva_neto,
        'anticipo_simple', v_anticipo,
        'reteiva', v_reteiva,
        'rte_fte', v_rte_fte,
        'rete_ica', v_rete_ica,
        'total_a_pagar', v_total,
        'tarifa_simple', v_tarifa
    );
END;
$$;

-- ═══════════════════════════════════════════════════
-- 7. VERIFICACIÓN
-- ═══════════════════════════════════════════════════
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Verificar columnas en purchase_orders
    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns 
    WHERE table_name = 'purchase_orders' 
      AND column_name IN (
        'supplier_invoice_number', 'supplier_invoice_date', 'cufe',
        'tax_rate', 'retention_rte_fte', 'retention_ica', 'retention_iva',
        'freight_amount', 'attachments', 'iva_invoice_id', 'credit_days', 'due_date'
      );
    
    IF v_count >= 12 THEN
        RAISE NOTICE '✅ purchase_orders: 12 columnas nuevas agregadas';
    ELSE
        RAISE NOTICE '⚠️ purchase_orders: solo % de 12 columnas agregadas', v_count;
    END IF;

    -- Verificar columnas en purchase_order_items
    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns 
    WHERE table_name = 'purchase_order_items' 
      AND column_name IN (
        'tax_rate', 'tax_amount', 'discount', 'reference_code', 'description', 'total'
      );
    
    IF v_count >= 6 THEN
        RAISE NOTICE '✅ purchase_order_items: 6 columnas nuevas agregadas';
    ELSE
        RAISE NOTICE '⚠️ purchase_order_items: solo % de 6 columnas agregadas', v_count;
    END IF;

    -- Verificar columnas en iva_invoices
    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns 
    WHERE table_name = 'iva_invoices' 
      AND column_name IN (
        'company_document', 'cufe', 'purchase_order_id', 'rte_fte_amount', 'rete_ica_amount'
      );
    
    IF v_count >= 5 THEN
        RAISE NOTICE '✅ iva_invoices: 5 columnas nuevas agregadas';
    ELSE
        RAISE NOTICE '⚠️ iva_invoices: solo % de 5 columnas agregadas', v_count;
    END IF;

    -- Verificar función
    IF EXISTS (
        SELECT 1 FROM pg_proc WHERE proname = 'create_iva_from_purchase_order'
    ) THEN
        RAISE NOTICE '✅ Función create_iva_from_purchase_order creada';
    ELSE
        RAISE NOTICE '⚠️ Función create_iva_from_purchase_order NO encontrada';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '══════════════════════════════════════════════════';
    RAISE NOTICE '  MIGRACIÓN 053 COMPLETADA';
    RAISE NOTICE '  - purchase_orders: soporte completo facturas colombianas';
    RAISE NOTICE '  - purchase_order_items: IVA por ítem + descuento';
    RAISE NOTICE '  - iva_invoices: vinculación con órdenes de compra';
    RAISE NOTICE '  - Función automática: OC → registro IVA';
    RAISE NOTICE '  - Vista bimestral actualizada con retenciones';
    RAISE NOTICE '══════════════════════════════════════════════════';
END $$;
