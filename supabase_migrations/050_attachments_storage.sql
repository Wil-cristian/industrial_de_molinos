-- =====================================================
-- 050: SUPABASE STORAGE PARA ADJUNTOS DE MOVIMIENTOS
-- =====================================================
-- Agrega soporte para almacenar archivos adjuntos (fotos, PDFs, etc.)
-- en Supabase Storage vinculados a movimientos de caja.

-- 1. Agregar columna attachments (JSONB) a cash_movements
-- Formato: [{"name": "foto.jpg", "path": "movements/uuid/foto.jpg", "size": 12345, "type": "image/jpeg"}]
ALTER TABLE cash_movements 
ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]'::jsonb;

-- 2. Crear bucket de Storage para adjuntos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'attachments',
  'attachments',
  true,  -- público para poder ver las imágenes directamente
  10485760,  -- 10MB max por archivo
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 
        'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 3. Políticas de Storage - permitir lectura y escritura
-- Permitir a cualquiera leer archivos (bucket público)
DROP POLICY IF EXISTS "Allow public read attachments" ON storage.objects;
CREATE POLICY "Allow public read attachments" ON storage.objects
  FOR SELECT USING (bucket_id = 'attachments');

-- Permitir a usuarios autenticados subir archivos
DROP POLICY IF EXISTS "Allow authenticated upload attachments" ON storage.objects;
CREATE POLICY "Allow authenticated upload attachments" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'attachments');

-- Permitir a usuarios autenticados actualizar archivos
DROP POLICY IF EXISTS "Allow authenticated update attachments" ON storage.objects;
CREATE POLICY "Allow authenticated update attachments" ON storage.objects
  FOR UPDATE USING (bucket_id = 'attachments');

-- Permitir a usuarios autenticados eliminar archivos
DROP POLICY IF EXISTS "Allow authenticated delete attachments" ON storage.objects;
CREATE POLICY "Allow authenticated delete attachments" ON storage.objects
  FOR DELETE USING (bucket_id = 'attachments');

-- 4. Índice para búsqueda en attachments
CREATE INDEX IF NOT EXISTS idx_cash_movements_has_attachments 
ON cash_movements ((attachments != '[]'::jsonb))
WHERE attachments != '[]'::jsonb;

-- Verificación
DO $$
BEGIN
  -- Verificar columna attachments
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'cash_movements' AND column_name = 'attachments'
  ) THEN
    RAISE NOTICE '✅ Columna attachments agregada a cash_movements';
  ELSE
    RAISE EXCEPTION '❌ Error: No se pudo agregar columna attachments';
  END IF;

  -- Verificar bucket
  IF EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'attachments') THEN
    RAISE NOTICE '✅ Bucket attachments creado en Storage';
  ELSE
    RAISE EXCEPTION '❌ Error: No se pudo crear bucket attachments';
  END IF;
END $$;
