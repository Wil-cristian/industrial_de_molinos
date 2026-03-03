-- =====================================================
-- MIGRACIÓN 042: Zona Horaria Colombia (America/Bogota)
-- =====================================================
-- Configura la zona horaria de la base de datos a Colombia (UTC-5)
-- para que todas las funciones NOW(), CURRENT_TIMESTAMP, 
-- CURRENT_DATE usen hora colombiana.
-- =====================================================

-- Establecer zona horaria del servidor a Colombia
ALTER DATABASE postgres SET timezone TO 'America/Bogota';

-- Aplicar inmediatamente en esta sesión
SET timezone TO 'America/Bogota';

-- Verificar
DO $$
DECLARE
    v_tz TEXT;
    v_now TIMESTAMPTZ;
BEGIN
    SHOW timezone INTO v_tz;
    v_now := NOW();
    RAISE NOTICE '✅ Zona horaria: %', v_tz;
    RAISE NOTICE '   Hora actual: %', v_now;
    RAISE NOTICE '   Colombia debe ser UTC-5 (no aplica horario de verano)';
END $$;
