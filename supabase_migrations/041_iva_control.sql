-- ============================================================
-- MIGRACIÓN 041: Sistema de Control de IVA
-- Régimen Simple de Tributación (Colombia)
-- ============================================================

-- ─────────────────────────────────────────────────
-- 1. Configuración IVA (valor UVT, grupo, tarifa)
-- ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS iva_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    year INT NOT NULL,
    uvt_value DECIMAL(12,2) NOT NULL DEFAULT 49799,
    grupo_rst INT NOT NULL DEFAULT 2,            -- Grupo Régimen Simple (1..4)
    tarifa_simple DECIMAL(5,4) NOT NULL DEFAULT 0.02, -- 2% para grupo 2
    iva_rate DECIMAL(5,4) NOT NULL DEFAULT 0.19,  -- IVA general 19%
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(year)
);

-- Insertar configuración por defecto para 2025 y 2026
INSERT INTO iva_config (year, uvt_value, grupo_rst, tarifa_simple, iva_rate)
VALUES 
    (2025, 49799, 2, 0.02, 0.19),
    (2026, 49799, 2, 0.02, 0.19)
ON CONFLICT (year) DO NOTHING;

-- ─────────────────────────────────────────────────
-- 2. Facturas IVA (compra y venta)
-- ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS iva_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number TEXT NOT NULL,
    invoice_date DATE NOT NULL,
    company TEXT NOT NULL,                       -- Nombre empresa/persona
    invoice_type TEXT NOT NULL CHECK (invoice_type IN ('COMPRA', 'VENTA')),
    base_amount DECIMAL(14,2) NOT NULL DEFAULT 0, -- Valor base (sin IVA)
    iva_amount DECIMAL(14,2) NOT NULL DEFAULT 0,  -- Monto IVA
    total_amount DECIMAL(14,2) NOT NULL DEFAULT 0, -- Total factura
    has_reteiva BOOLEAN DEFAULT FALSE,           -- ¿Aplica ReteIVA?
    reteiva_amount DECIMAL(14,2) DEFAULT 0,      -- Monto ReteIVA (15% del IVA)
    bimonthly_period TEXT NOT NULL,              -- Periodo: '2025-6' (nov-dic 2025), '2026-1' (ene-feb 2026)
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_iva_invoices_period ON iva_invoices(bimonthly_period);
CREATE INDEX IF NOT EXISTS idx_iva_invoices_type ON iva_invoices(invoice_type);
CREATE INDEX IF NOT EXISTS idx_iva_invoices_date ON iva_invoices(invoice_date);
CREATE INDEX IF NOT EXISTS idx_iva_invoices_company ON iva_invoices(company);

-- ─────────────────────────────────────────────────
-- 3. Liquidaciones bimestrales
-- ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS iva_bimonthly_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bimonthly_period TEXT NOT NULL UNIQUE,       -- '2025-6', '2026-1', etc.
    year INT NOT NULL,
    bimester INT NOT NULL CHECK (bimester BETWEEN 1 AND 6), -- 1=ene-feb ... 6=nov-dic
    -- Ventas
    total_base_ventas DECIMAL(14,2) DEFAULT 0,
    total_iva_ventas DECIMAL(14,2) DEFAULT 0,
    -- Compras
    total_base_compras DECIMAL(14,2) DEFAULT 0,
    total_iva_compras DECIMAL(14,2) DEFAULT 0,
    -- Cálculos
    iva_neto DECIMAL(14,2) DEFAULT 0,           -- IVA ventas - IVA compras
    anticipo_simple DECIMAL(14,2) DEFAULT 0,    -- tarifa_simple * base_ventas
    reteiva_total DECIMAL(14,2) DEFAULT 0,      -- Total ReteIVA del periodo
    total_a_pagar DECIMAL(14,2) DEFAULT 0,      -- iva_neto + anticipo_simple - reteiva
    is_settled BOOLEAN DEFAULT FALSE,            -- ¿Ya se declaró?
    settled_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────────────
-- 4. Función: calcular periodo bimestral
-- ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_bimonthly_period(p_date DATE)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_year INT;
    v_month INT;
    v_bimester INT;
BEGIN
    v_year := EXTRACT(YEAR FROM p_date);
    v_month := EXTRACT(MONTH FROM p_date);
    v_bimester := CEIL(v_month::DECIMAL / 2);
    RETURN v_year || '-' || v_bimester;
END;
$$;

-- ─────────────────────────────────────────────────
-- 5. Función: obtener nombre del bimestre
-- ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_bimester_name(p_bimester INT)
RETURNS TEXT
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    RETURN CASE p_bimester
        WHEN 1 THEN 'Ene-Feb'
        WHEN 2 THEN 'Mar-Abr'
        WHEN 3 THEN 'May-Jun'
        WHEN 4 THEN 'Jul-Ago'
        WHEN 5 THEN 'Sep-Oct'
        WHEN 6 THEN 'Nov-Dic'
        ELSE 'Desconocido'
    END;
END;
$$;

-- ─────────────────────────────────────────────────
-- 6. Vista: resumen por periodo bimestral
-- ─────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_iva_bimonthly_summary AS
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
    -- ReteIVA
    COALESCE(SUM(CASE WHEN has_reteiva THEN reteiva_amount ELSE 0 END), 0) AS total_reteiva,
    -- Totales
    COUNT(*) AS total_facturas
FROM iva_invoices
GROUP BY bimonthly_period
ORDER BY bimonthly_period DESC;

-- ─────────────────────────────────────────────────
-- 7. RPC: liquidar bimestre
-- ─────────────────────────────────────────────────
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
    v_iva_neto DECIMAL(14,2);
    v_anticipo DECIMAL(14,2);
    v_total DECIMAL(14,2);
    v_tarifa DECIMAL(5,4);
    v_config_year INT;
BEGIN
    -- Extraer año y bimestre del periodo
    v_year := SPLIT_PART(p_period, '-', 1)::INT;
    v_bimester := SPLIT_PART(p_period, '-', 2)::INT;
    v_config_year := COALESCE(p_year, v_year);

    -- Obtener tarifa simple del año
    SELECT tarifa_simple INTO v_tarifa
    FROM iva_config
    WHERE year = v_config_year;
    
    IF v_tarifa IS NULL THEN
        v_tarifa := 0.02; -- Default 2%
    END IF;

    -- Calcular totales del periodo
    SELECT 
        COALESCE(SUM(CASE WHEN invoice_type = 'VENTA' THEN base_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN invoice_type = 'VENTA' THEN iva_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN invoice_type = 'COMPRA' THEN base_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN invoice_type = 'COMPRA' THEN iva_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN has_reteiva THEN reteiva_amount ELSE 0 END), 0)
    INTO v_base_ventas, v_iva_ventas, v_base_compras, v_iva_compras, v_reteiva
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
        'total_a_pagar', v_total,
        'tarifa_simple', v_tarifa
    );
END;
$$;

-- ─────────────────────────────────────────────────
-- 8. RPC: obtener resumen del periodo actual
-- ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_iva_current_summary()
RETURNS JSONB
LANGUAGE plpgsql AS $$
DECLARE
    v_period TEXT;
    v_result JSONB;
BEGIN
    v_period := get_bimonthly_period(CURRENT_DATE);
    v_result := liquidar_bimestre(v_period);
    RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────────────
-- 9. RPC: obtener todas las facturas IVA de un periodo
-- ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_iva_invoices(
    p_period TEXT DEFAULT NULL,
    p_type TEXT DEFAULT NULL,
    p_limit INT DEFAULT 500
)
RETURNS SETOF iva_invoices
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM iva_invoices i
    WHERE (p_period IS NULL OR i.bimonthly_period = p_period)
      AND (p_type IS NULL OR i.invoice_type = p_type)
    ORDER BY i.invoice_date DESC, i.created_at DESC
    LIMIT p_limit;
END;
$$;

-- ─────────────────────────────────────────────────
-- 10. RPC: obtener historial de liquidaciones
-- ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_iva_settlements(
    p_year INT DEFAULT NULL
)
RETURNS SETOF iva_bimonthly_settlements
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM iva_bimonthly_settlements s
    WHERE (p_year IS NULL OR s.year = p_year)
    ORDER BY s.bimonthly_period DESC;
END;
$$;

-- ─────────────────────────────────────────────────
-- 11. Trigger: actualizar updated_at
-- ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_iva_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_iva_invoices_updated ON iva_invoices;
CREATE TRIGGER trg_iva_invoices_updated
    BEFORE UPDATE ON iva_invoices
    FOR EACH ROW EXECUTE FUNCTION update_iva_updated_at();

DROP TRIGGER IF EXISTS trg_iva_config_updated ON iva_config;
CREATE TRIGGER trg_iva_config_updated
    BEFORE UPDATE ON iva_config
    FOR EACH ROW EXECUTE FUNCTION update_iva_updated_at();

DROP TRIGGER IF EXISTS trg_iva_settlements_updated ON iva_bimonthly_settlements;
CREATE TRIGGER trg_iva_settlements_updated
    BEFORE UPDATE ON iva_bimonthly_settlements
    FOR EACH ROW EXECUTE FUNCTION update_iva_updated_at();

-- ─────────────────────────────────────────────────
-- 12. RLS (acceso público para usuarios autenticados)
-- ─────────────────────────────────────────────────
ALTER TABLE iva_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE iva_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE iva_bimonthly_settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iva_invoices_all ON iva_invoices;
CREATE POLICY iva_invoices_all ON iva_invoices
    FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS iva_config_all ON iva_config;
CREATE POLICY iva_config_all ON iva_config
    FOR ALL USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS iva_settlements_all ON iva_bimonthly_settlements;
CREATE POLICY iva_settlements_all ON iva_bimonthly_settlements
    FOR ALL USING (auth.role() = 'authenticated');
