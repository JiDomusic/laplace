-- Migración: Tabla de historial de cambios para sistema de deshacer
-- Almacena el estado anterior y nuevo de cada operación crítica

CREATE TABLE historial_cambios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tabla VARCHAR(50) NOT NULL,
    registro_id VARCHAR(100) NOT NULL,
    accion VARCHAR(30) NOT NULL,
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    descripcion TEXT,
    usuario VARCHAR(150),
    revertido BOOLEAN DEFAULT FALSE,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_historial_tabla ON historial_cambios(tabla);
CREATE INDEX idx_historial_registro ON historial_cambios(registro_id);
CREATE INDEX idx_historial_accion ON historial_cambios(accion);
CREATE INDEX idx_historial_fecha ON historial_cambios(fecha);

ALTER TABLE historial_cambios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir lectura de historial" ON historial_cambios
    FOR SELECT USING (true);

CREATE POLICY "Permitir insercion de historial" ON historial_cambios
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Permitir actualizacion de historial" ON historial_cambios
    FOR UPDATE USING (true);
