-- Agregar campo de cantidad a activos fijos
-- Permite registrar múltiples unidades del mismo activo (ej: 30 varillas)
ALTER TABLE assets ADD COLUMN IF NOT EXISTS quantity INTEGER NOT NULL DEFAULT 1;
