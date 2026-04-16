-- ============================================
-- 054: Tabla app_releases para sistema de auto-update
-- ============================================
-- Esta tabla almacena las versiones publicadas de la app.
-- La app consulta esta tabla al iniciar para verificar si hay actualizaciones.

CREATE TABLE IF NOT EXISTS app_releases (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    version TEXT NOT NULL,              -- Ej: '1.0.0'
    build_number INTEGER NOT NULL,      -- Ej: 1, 2, 3...
    download_url TEXT NOT NULL,         -- URL del instalador (.exe)
    release_notes TEXT,                 -- Notas del release en texto plano
    is_mandatory BOOLEAN DEFAULT false, -- Si true, el usuario DEBE actualizar
    is_active BOOLEAN DEFAULT true,     -- Si false, esta version no se muestra
    min_version TEXT,                   -- Version minima que puede actualizar a esta
    file_size_mb DECIMAL(10,2),        -- Tamano del instalador en MB
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Evitar versiones duplicadas
    CONSTRAINT unique_version UNIQUE (version, build_number)
);

-- Indice para buscar la ultima version activa rapidamente
CREATE INDEX idx_app_releases_active ON app_releases (is_active, created_at DESC);

-- RLS: Cualquier usuario autenticado puede leer releases (necesario para el check de update)
ALTER TABLE app_releases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Cualquier usuario puede ver releases activos"
    ON app_releases FOR SELECT
    USING (is_active = true);

-- Solo admins pueden insertar/modificar releases (via dashboard de Supabase)
-- No se necesita policy de INSERT/UPDATE porque se hace desde el dashboard

-- Insertar el release inicial
INSERT INTO app_releases (version, build_number, download_url, release_notes, is_mandatory, is_active)
VALUES (
    '1.0.0',
    1,
    '',  -- Se llenara cuando se suba el primer instalador
    'Release inicial - Sistema de Gestion Industrial de Molinos',
    false,
    true
);

COMMENT ON TABLE app_releases IS 'Versiones publicadas de la app para el sistema de auto-update';
