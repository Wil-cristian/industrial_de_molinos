-- Agregar campo 'label' a product_components para título de pieza
-- Ejemplo: "tapa lateral", "fondo", "cuerpo principal"
ALTER TABLE product_components ADD COLUMN IF NOT EXISTS label VARCHAR(200);
