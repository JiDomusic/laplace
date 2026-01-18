-- =====================================================
-- POLITICAS DE STORAGE PARA LAPLACE
-- =====================================================
-- Solo el ADMIN usa el sistema (inscripcion presencial)
-- Permitir subida y lectura sin restriccion de auth
-- =====================================================

-- Borrar politicas existentes
DROP POLICY IF EXISTS "Lectura fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Subida fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Actualizar fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Eliminar fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Acceso publico lectura fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede actualizar fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede eliminar fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Admin subida fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Admin actualizar fotos-alumnos" ON storage.objects;
DROP POLICY IF EXISTS "Admin eliminar fotos-alumnos" ON storage.objects;

DROP POLICY IF EXISTS "Lectura documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Subida documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Actualizar documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Eliminar documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Acceso publico lectura documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede actualizar documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede eliminar documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Admin subida documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Admin actualizar documentos-dni" ON storage.objects;
DROP POLICY IF EXISTS "Admin eliminar documentos-dni" ON storage.objects;

DROP POLICY IF EXISTS "Lectura documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Subida documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Actualizar documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Eliminar documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Acceso publico lectura documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede actualizar documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede eliminar documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Admin subida documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Admin actualizar documentos-titulos" ON storage.objects;
DROP POLICY IF EXISTS "Admin eliminar documentos-titulos" ON storage.objects;

DROP POLICY IF EXISTS "Lectura documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Subida documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Actualizar documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Eliminar documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Acceso publico lectura documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede actualizar documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede eliminar documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Admin subida documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Admin actualizar documentos-certificados" ON storage.objects;
DROP POLICY IF EXISTS "Admin eliminar documentos-certificados" ON storage.objects;

DROP POLICY IF EXISTS "Lectura documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Subida documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Actualizar documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Eliminar documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Acceso publico lectura documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede actualizar documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede eliminar documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Admin subida documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Admin actualizar documentos-partidas" ON storage.objects;
DROP POLICY IF EXISTS "Admin eliminar documentos-partidas" ON storage.objects;

DROP POLICY IF EXISTS "Lectura galeria" ON storage.objects;
DROP POLICY IF EXISTS "Subida galeria" ON storage.objects;
DROP POLICY IF EXISTS "Actualizar galeria" ON storage.objects;
DROP POLICY IF EXISTS "Eliminar galeria" ON storage.objects;
DROP POLICY IF EXISTS "Acceso publico lectura galeria" ON storage.objects;
DROP POLICY IF EXISTS "Permitir subida galeria" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede actualizar galeria" ON storage.objects;
DROP POLICY IF EXISTS "Admin puede eliminar galeria" ON storage.objects;
DROP POLICY IF EXISTS "Admin subida galeria" ON storage.objects;
DROP POLICY IF EXISTS "Admin actualizar galeria" ON storage.objects;
DROP POLICY IF EXISTS "Admin eliminar galeria" ON storage.objects;

-- =====================================================
-- FOTOS-ALUMNOS
-- =====================================================
CREATE POLICY "fotos-alumnos SELECT" ON storage.objects FOR SELECT USING (bucket_id = 'fotos-alumnos');
CREATE POLICY "fotos-alumnos INSERT" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'fotos-alumnos');
CREATE POLICY "fotos-alumnos UPDATE" ON storage.objects FOR UPDATE USING (bucket_id = 'fotos-alumnos');
CREATE POLICY "fotos-alumnos DELETE" ON storage.objects FOR DELETE USING (bucket_id = 'fotos-alumnos');

-- =====================================================
-- DOCUMENTOS-DNI
-- =====================================================
CREATE POLICY "documentos-dni SELECT" ON storage.objects FOR SELECT USING (bucket_id = 'documentos-dni');
CREATE POLICY "documentos-dni INSERT" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'documentos-dni');
CREATE POLICY "documentos-dni UPDATE" ON storage.objects FOR UPDATE USING (bucket_id = 'documentos-dni');
CREATE POLICY "documentos-dni DELETE" ON storage.objects FOR DELETE USING (bucket_id = 'documentos-dni');

-- =====================================================
-- DOCUMENTOS-TITULOS
-- =====================================================
CREATE POLICY "documentos-titulos SELECT" ON storage.objects FOR SELECT USING (bucket_id = 'documentos-titulos');
CREATE POLICY "documentos-titulos INSERT" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'documentos-titulos');
CREATE POLICY "documentos-titulos UPDATE" ON storage.objects FOR UPDATE USING (bucket_id = 'documentos-titulos');
CREATE POLICY "documentos-titulos DELETE" ON storage.objects FOR DELETE USING (bucket_id = 'documentos-titulos');

-- =====================================================
-- DOCUMENTOS-CERTIFICADOS
-- =====================================================
CREATE POLICY "documentos-certificados SELECT" ON storage.objects FOR SELECT USING (bucket_id = 'documentos-certificados');
CREATE POLICY "documentos-certificados INSERT" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'documentos-certificados');
CREATE POLICY "documentos-certificados UPDATE" ON storage.objects FOR UPDATE USING (bucket_id = 'documentos-certificados');
CREATE POLICY "documentos-certificados DELETE" ON storage.objects FOR DELETE USING (bucket_id = 'documentos-certificados');

-- =====================================================
-- DOCUMENTOS-PARTIDAS
-- =====================================================
CREATE POLICY "documentos-partidas SELECT" ON storage.objects FOR SELECT USING (bucket_id = 'documentos-partidas');
CREATE POLICY "documentos-partidas INSERT" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'documentos-partidas');
CREATE POLICY "documentos-partidas UPDATE" ON storage.objects FOR UPDATE USING (bucket_id = 'documentos-partidas');
CREATE POLICY "documentos-partidas DELETE" ON storage.objects FOR DELETE USING (bucket_id = 'documentos-partidas');

-- =====================================================
-- GALERIA
-- =====================================================
CREATE POLICY "galeria SELECT" ON storage.objects FOR SELECT USING (bucket_id = 'galeria');
CREATE POLICY "galeria INSERT" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'galeria');
CREATE POLICY "galeria UPDATE" ON storage.objects FOR UPDATE USING (bucket_id = 'galeria');
CREATE POLICY "galeria DELETE" ON storage.objects FOR DELETE USING (bucket_id = 'galeria');
