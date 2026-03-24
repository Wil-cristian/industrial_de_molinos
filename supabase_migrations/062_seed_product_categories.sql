-- ============================================================
-- 062: Seed product categories + migrate existing product tags
-- ============================================================

-- Insert default categories if not exist
INSERT INTO categories (name, description, is_active)
SELECT name, description, true
FROM (VALUES
  ('Molinos',          'Molinos de bolas y equipos de molienda'),
  ('Transportadores',  'Transportadores de banda y cadena'),
  ('Tanques',          'Tanques de almacenamiento y proceso'),
  ('Estructuras',      'Estructuras metálicas y soportes'),
  ('Maquinaria',       'Maquinaria industrial general'),
  ('Otros',            'Otros productos no categorizados')
) AS v(name, description)
WHERE NOT EXISTS (
  SELECT 1 FROM categories c WHERE c.name = v.name
);

-- Migrate old lowercase tags to display names
UPDATE products SET description = regexp_replace(description, '^\[molino\]',         '[Molinos]')         WHERE description LIKE '[molino]%';
UPDATE products SET description = regexp_replace(description, '^\[transportador\]',  '[Transportadores]') WHERE description LIKE '[transportador]%';
UPDATE products SET description = regexp_replace(description, '^\[tanque\]',         '[Tanques]')         WHERE description LIKE '[tanque]%';
UPDATE products SET description = regexp_replace(description, '^\[estructura\]',     '[Estructuras]')     WHERE description LIKE '[estructura]%';
UPDATE products SET description = regexp_replace(description, '^\[maquinaria\]',     '[Maquinaria]')      WHERE description LIKE '[maquinaria]%';
UPDATE products SET description = regexp_replace(description, '^\[otros\]',          '[Otros]')           WHERE description LIKE '[otros]%';
