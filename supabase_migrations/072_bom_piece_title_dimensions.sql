-- Agregar campos de título de pieza y dimensiones a materiales de OP
ALTER TABLE production_order_materials
    ADD COLUMN IF NOT EXISTS piece_title VARCHAR(200),
    ADD COLUMN IF NOT EXISTS dimensions VARCHAR(200);
