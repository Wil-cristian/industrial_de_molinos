-- Tabla de ubicaciones de almacenamiento
CREATE TABLE IF NOT EXISTS storage_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE storage_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "storage_locations_all" ON storage_locations
  FOR ALL USING (true) WITH CHECK (true);

INSERT INTO storage_locations (name, description) VALUES
  ('Bodega Principal', 'Almacén principal de materiales'),
  ('Taller', 'Área de producción y trabajo'),
  ('Patio', 'Área exterior de almacenamiento')
ON CONFLICT (name) DO NOTHING;
