-- =============================================================
-- FIX: Consolidar periodos duplicados y reasignar nóminas
-- =============================================================
-- Este script:
-- 1. Identifica periodos duplicados (mismo period_type, period_number, year)
-- 2. Reasigna todas las nóminas al periodo más antiguo (canónico)
-- 3. Reasigna todos los detalles de nómina correspondientes
-- 4. Elimina los periodos duplicados vacíos
-- =============================================================

-- Paso 1: Ver periodos duplicados (solo consulta)
SELECT period_type, period_number, year, COUNT(*) as duplicates,
       array_agg(id ORDER BY created_at) as period_ids
FROM payroll_periods
GROUP BY period_type, period_number, year
HAVING COUNT(*) > 1;

-- Paso 2: Reasignar nóminas de periodos duplicados al periodo canónico (el más antiguo)
DO $$
DECLARE
    rec RECORD;
    canonical_id UUID;
    dup_id UUID;
    dup_ids UUID[];
BEGIN
    -- Iterar sobre cada grupo de periodos duplicados
    FOR rec IN
        SELECT period_type, period_number, year,
               array_agg(id ORDER BY created_at) as ids
        FROM payroll_periods
        GROUP BY period_type, period_number, year
        HAVING COUNT(*) > 1
    LOOP
        -- El primer ID (más antiguo) es el canónico
        canonical_id := rec.ids[1];
        dup_ids := rec.ids[2:array_length(rec.ids, 1)];
        
        RAISE NOTICE 'Consolidando periodo % #% año %: canónico=%, duplicados=%',
            rec.period_type, rec.period_number, rec.year, canonical_id, dup_ids;
        
        -- Reasignar nóminas de cada duplicado al canónico
        FOREACH dup_id IN ARRAY dup_ids
        LOOP
            UPDATE payroll
            SET period_id = canonical_id
            WHERE period_id = dup_id;
            
            RAISE NOTICE '  Reasignadas nóminas de % a %', dup_id, canonical_id;
        END LOOP;
        
        -- Eliminar periodos duplicados (ya no tienen nóminas)
        FOREACH dup_id IN ARRAY dup_ids
        LOOP
            DELETE FROM payroll_periods WHERE id = dup_id;
            RAISE NOTICE '  Eliminado periodo duplicado %', dup_id;
        END LOOP;
    END LOOP;
END $$;

-- Paso 3: Verificar que ya no hay duplicados
SELECT period_type, period_number, year, COUNT(*) as count
FROM payroll_periods
GROUP BY period_type, period_number, year
HAVING COUNT(*) > 1;

-- Paso 4: Agregar constraint único para prevenir futuros duplicados
-- (Descomentar solo si la limpieza fue exitosa y no hay duplicados)
-- ALTER TABLE payroll_periods
--   ADD CONSTRAINT unique_period UNIQUE (period_type, period_number, year);

-- Paso 5: Verificar nóminas existentes después de la limpieza
SELECT p.id as payroll_id, 
       e.first_name || ' ' || e.last_name as employee,
       pp.period_type, pp.period_number, pp.year,
       p.net_pay, p.status
FROM payroll p
JOIN employees e ON e.id = p.employee_id
JOIN payroll_periods pp ON pp.id = p.period_id
ORDER BY pp.year DESC, pp.period_number DESC, e.first_name;
