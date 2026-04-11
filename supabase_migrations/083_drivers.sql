-- =============================================
-- 083: Tabla de Conductores / Transportistas
-- =============================================

CREATE TABLE IF NOT EXISTS drivers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(200) NOT NULL,
    document        VARCHAR(50) NOT NULL,
    phone           VARCHAR(50),
    vehicle_plate   VARCHAR(20),
    carrier_company VARCHAR(200),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_drivers_name ON drivers(name);
CREATE INDEX IF NOT EXISTS idx_drivers_document ON drivers(document);
CREATE INDEX IF NOT EXISTS idx_drivers_active ON drivers(is_active);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION update_drivers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_drivers_updated_at ON drivers;
CREATE TRIGGER trigger_update_drivers_updated_at
    BEFORE UPDATE ON drivers
    FOR EACH ROW
    EXECUTE FUNCTION update_drivers_updated_at();

-- RLS
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "drivers_all" ON drivers;
CREATE POLICY "drivers_all" ON drivers
    FOR ALL USING (true) WITH CHECK (true);
