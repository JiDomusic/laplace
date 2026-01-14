-- =====================================================
-- POLÍTICAS DE STORAGE PARA LAPLACE
-- =====================================================
-- Usuarios anónimos: pueden subir y ver archivos
-- Admin autenticado: puede todo (subir, ver, editar, eliminar)
-- =====================================================

-- Lista de buckets
-- fotos-alumnos, documentos-dni, documentos-titulos,
-- documentos-certificados, documentos-partidas, galeria

-- =====================================================
-- FOTOS-ALUMNOS
-- =====================================================

-- Cualquiera puede ver las fotos
CREATE POLICY "Acceso público lectura fotos-alumnos"
ON storage.objects FOR SELECT
USING (bucket_id = 'fotos-alumnos');

-- Cualquiera puede subir fotos (formulario de inscripción)
CREATE POLICY "Permitir subida fotos-alumnos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'fotos-alumnos');

-- Solo admin autenticado puede actualizar
CREATE POLICY "Admin puede actualizar fotos-alumnos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'fotos-alumnos' AND auth.role() = 'authenticated');

-- Solo admin autenticado puede eliminar
CREATE POLICY "Admin puede eliminar fotos-alumnos"
ON storage.objects FOR DELETE
USING (bucket_id = 'fotos-alumnos' AND auth.role() = 'authenticated');

-- =====================================================
-- DOCUMENTOS-DNI
-- =====================================================

CREATE POLICY "Acceso público lectura documentos-dni"
ON storage.objects FOR SELECT
USING (bucket_id = 'documentos-dni');

CREATE POLICY "Permitir subida documentos-dni"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'documentos-dni');

CREATE POLICY "Admin puede actualizar documentos-dni"
ON storage.objects FOR UPDATE
USING (bucket_id = 'documentos-dni' AND auth.role() = 'authenticated');

CREATE POLICY "Admin puede eliminar documentos-dni"
ON storage.objects FOR DELETE
USING (bucket_id = 'documentos-dni' AND auth.role() = 'authenticated');

-- =====================================================
-- DOCUMENTOS-TITULOS
-- =====================================================

CREATE POLICY "Acceso público lectura documentos-titulos"
ON storage.objects FOR SELECT
USING (bucket_id = 'documentos-titulos');

CREATE POLICY "Permitir subida documentos-titulos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'documentos-titulos');

CREATE POLICY "Admin puede actualizar documentos-titulos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'documentos-titulos' AND auth.role() = 'authenticated');

CREATE POLICY "Admin puede eliminar documentos-titulos"
ON storage.objects FOR DELETE
USING (bucket_id = 'documentos-titulos' AND auth.role() = 'authenticated');

-- =====================================================
-- DOCUMENTOS-CERTIFICADOS
-- =====================================================

CREATE POLICY "Acceso público lectura documentos-certificados"
ON storage.objects FOR SELECT
USING (bucket_id = 'documentos-certificados');

CREATE POLICY "Permitir subida documentos-certificados"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'documentos-certificados');

CREATE POLICY "Admin puede actualizar documentos-certificados"
ON storage.objects FOR UPDATE
USING (bucket_id = 'documentos-certificados' AND auth.role() = 'authenticated');

CREATE POLICY "Admin puede eliminar documentos-certificados"
ON storage.objects FOR DELETE
USING (bucket_id = 'documentos-certificados' AND auth.role() = 'authenticated');

-- =====================================================
-- DOCUMENTOS-PARTIDAS
-- =====================================================

CREATE POLICY "Acceso público lectura documentos-partidas"
ON storage.objects FOR SELECT
USING (bucket_id = 'documentos-partidas');

CREATE POLICY "Permitir subida documentos-partidas"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'documentos-partidas');

CREATE POLICY "Admin puede actualizar documentos-partidas"
ON storage.objects FOR UPDATE
USING (bucket_id = 'documentos-partidas' AND auth.role() = 'authenticated');

CREATE POLICY "Admin puede eliminar documentos-partidas"
ON storage.objects FOR DELETE
USING (bucket_id = 'documentos-partidas' AND auth.role() = 'authenticated');

-- =====================================================
-- GALERIA (por si lo usas después)
-- =====================================================

CREATE POLICY "Acceso público lectura galeria"
ON storage.objects FOR SELECT
USING (bucket_id = 'galeria');

CREATE POLICY "Permitir subida galeria"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'galeria');

CREATE POLICY "Admin puede actualizar galeria"
ON storage.objects FOR UPDATE
USING (bucket_id = 'galeria' AND auth.role() = 'authenticated');

CREATE POLICY "Admin puede eliminar galeria"
ON storage.objects FOR DELETE
USING (bucket_id = 'galeria' AND auth.role() = 'authenticated');
