-- =====================================================
-- MIGRACIÓN: Agregar estado 'Anulada' a cotizaciones
-- Fecha: 2024-12-26
-- =====================================================

-- Agregar valor 'Anulada' al enum quotation_status
ALTER TYPE quotation_status ADD VALUE IF NOT EXISTS 'Anulada';

-- Verificar que se agregó
SELECT enum_range(NULL::quotation_status);
