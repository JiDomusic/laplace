-- Migración: Políticas RLS para gestión de administradores
-- Permite INSERT, UPDATE, DELETE desde la app

CREATE POLICY "Permitir insercion de administradores" ON administradores
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Permitir actualizacion de administradores" ON administradores
    FOR UPDATE USING (true);

CREATE POLICY "Permitir eliminacion de administradores" ON administradores
    FOR DELETE USING (true);
