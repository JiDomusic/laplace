-- =====================================================
-- SISTEMA DE INSCRIPCION - INSTITUTO LAPLACE ROSARIO
-- Base de Datos PostgreSQL para Supabase
-- =====================================================

-- Habilitar extensión UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- TABLA DE ALUMNOS
-- =====================================================
CREATE TABLE IF NOT EXISTS alumnos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Datos Personales
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    dni VARCHAR(15) NOT NULL UNIQUE,
    sexo VARCHAR(20) NOT NULL CHECK (sexo IN ('Masculino', 'Femenino', 'Otro')),
    fecha_nacimiento DATE NOT NULL,
    nacionalidad VARCHAR(50) NOT NULL,

    -- Domicilio
    calle VARCHAR(150) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    piso VARCHAR(10) DEFAULT NULL,
    departamento VARCHAR(10) DEFAULT NULL,
    localidad VARCHAR(100) NOT NULL,
    codigo_postal VARCHAR(10) NOT NULL,
    provincia VARCHAR(50) DEFAULT 'Santa Fe',

    -- Contacto
    email VARCHAR(150) NOT NULL,
    telefono VARCHAR(30),
    celular VARCHAR(30) NOT NULL,

    -- Situacion Laboral
    trabaja BOOLEAN DEFAULT FALSE,
    certificado_trabajo TEXT DEFAULT NULL,

    -- Contacto de Urgencia
    contacto_urgencia_nombre VARCHAR(150) DEFAULT NULL,
    contacto_urgencia_telefono VARCHAR(30) DEFAULT NULL,
    contacto_urgencia_vinculo VARCHAR(50) DEFAULT NULL,

    -- Foto del alumno
    foto_alumno TEXT DEFAULT NULL,

    -- Nivel de inscripcion
    nivel_inscripcion VARCHAR(20) NOT NULL CHECK (nivel_inscripcion IN ('Primer Año', 'Segundo Año', 'Tercer Año')),

    -- Estado de inscripcion
    estado VARCHAR(20) DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aprobado', 'rechazado', 'completo')),
    observaciones TEXT,

    -- Metadatos
    codigo_inscripcion VARCHAR(20) UNIQUE,
    fecha_inscripcion TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para alumnos
CREATE INDEX idx_alumnos_dni ON alumnos(dni);
CREATE INDEX idx_alumnos_estado ON alumnos(estado);
CREATE INDEX idx_alumnos_nivel ON alumnos(nivel_inscripcion);
CREATE INDEX idx_alumnos_fecha ON alumnos(fecha_inscripcion);

-- =====================================================
-- TABLA DE LEGAJO (DOCUMENTOS)
-- =====================================================
CREATE TABLE IF NOT EXISTS legajo_documentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alumno_id UUID NOT NULL REFERENCES alumnos(id) ON DELETE CASCADE,

    -- DNI
    dni_frente TEXT DEFAULT NULL,
    dni_dorso TEXT DEFAULT NULL,

    -- Partida de Nacimiento
    partida_nacimiento TEXT DEFAULT NULL,
    nacido_fuera_santa_fe BOOLEAN DEFAULT FALSE,

    -- Titulo Secundario
    estado_titulo VARCHAR(20) NOT NULL CHECK (estado_titulo IN ('terminado', 'en_tramite', 'debe_materias')),

    -- Archivos segun estado
    titulo_archivo TEXT DEFAULT NULL,
    tramite_constancia TEXT DEFAULT NULL,
    materias_adeudadas TEXT DEFAULT NULL,
    materias_constancia TEXT DEFAULT NULL,

    -- Tipo de legalizacion del titulo
    tipo_legalizacion VARCHAR(20) DEFAULT NULL CHECK (tipo_legalizacion IN ('tribunales', 'institucion', 'digital')),

    fecha_carga TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- TABLA DE CUOTAS
-- =====================================================
CREATE TABLE IF NOT EXISTS cuotas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alumno_id UUID NOT NULL REFERENCES alumnos(id) ON DELETE CASCADE,

    concepto VARCHAR(100) NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    monto_pagado DECIMAL(10,2) DEFAULT 0,
    mes INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
    anio INTEGER NOT NULL,

    fecha_vencimiento DATE NOT NULL,
    fecha_pago DATE DEFAULT NULL,

    estado VARCHAR(20) DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'pagada', 'vencida', 'parcial')),
    metodo_pago VARCHAR(50) DEFAULT NULL,
    comprobante TEXT DEFAULT NULL,

    notificacion_enviada BOOLEAN DEFAULT FALSE,
    fecha_notificacion TIMESTAMP WITH TIME ZONE DEFAULT NULL,

    observaciones TEXT,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para cuotas
CREATE INDEX idx_cuotas_alumno ON cuotas(alumno_id);
CREATE INDEX idx_cuotas_estado ON cuotas(estado);
CREATE INDEX idx_cuotas_vencimiento ON cuotas(fecha_vencimiento);

-- =====================================================
-- TABLA DE ADMINISTRADORES
-- =====================================================
CREATE TABLE IF NOT EXISTS administradores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    rol VARCHAR(20) DEFAULT 'admin' CHECK (rol IN ('superadmin', 'admin', 'secretaria')),
    activo BOOLEAN DEFAULT TRUE,
    ultimo_acceso TIMESTAMP WITH TIME ZONE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insertar administradores por defecto
INSERT INTO administradores (email, password, nombre, rol) VALUES
('programcionjjj@gmail.com', '123456', 'Programador', 'superadmin'),
('mirisarac@gmail.com', '987654', 'Miri', 'admin')
ON CONFLICT (email) DO NOTHING;

-- Índice para login
CREATE INDEX idx_admin_email ON administradores(email);

-- =====================================================
-- TABLA DE CONFIGURACION DEL SISTEMA
-- =====================================================
CREATE TABLE IF NOT EXISTS configuracion (
    id SERIAL PRIMARY KEY,
    clave VARCHAR(50) NOT NULL UNIQUE,
    valor TEXT NOT NULL,
    descripcion VARCHAR(255),
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Configuraciones iniciales
INSERT INTO configuracion (clave, valor, descripcion) VALUES
('nombre_instituto', 'Instituto Laplace', 'Nombre del instituto'),
('direccion_instituto', 'Rosario, Santa Fe', 'Direccion del instituto'),
('telefono_instituto', '3413513973', 'Telefono de contacto'),
('whatsapp_numero', '5493413513973', 'Numero de WhatsApp con codigo de pais'),
('email_instituto', 'info@laplace.edu.ar', 'Email de contacto'),
('monto_matricula', '50000', 'Monto de matricula por defecto'),
('monto_cuota', '35000', 'Monto de cuota mensual por defecto'),
('inscripciones_abiertas', 'true', 'Estado de inscripciones'),
('ciclo_lectivo_actual', '2026', 'Año lectivo actual')
ON CONFLICT (clave) DO NOTHING;

-- =====================================================
-- FUNCIONES
-- =====================================================

-- Función para generar código de inscripción
CREATE OR REPLACE FUNCTION generar_codigo_inscripcion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.codigo_inscripcion := 'LAP-' || EXTRACT(YEAR FROM NOW())::TEXT || '-' || LPAD(
        (SELECT COALESCE(MAX(SUBSTRING(codigo_inscripcion FROM '[0-9]+$')::INTEGER), 0) + 1 FROM alumnos)::TEXT,
        5, '0'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para generar código automáticamente
DROP TRIGGER IF EXISTS trigger_generar_codigo ON alumnos;
CREATE TRIGGER trigger_generar_codigo
    BEFORE INSERT ON alumnos
    FOR EACH ROW
    WHEN (NEW.codigo_inscripcion IS NULL)
    EXECUTE FUNCTION generar_codigo_inscripcion();

-- Función para actualizar fecha_actualizacion
CREATE OR REPLACE FUNCTION actualizar_fecha_modificacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_actualizacion = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para actualizar fechas
CREATE TRIGGER trigger_alumnos_updated
    BEFORE UPDATE ON alumnos
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_fecha_modificacion();

CREATE TRIGGER trigger_legajo_updated
    BEFORE UPDATE ON legajo_documentos
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_fecha_modificacion();

-- =====================================================
-- VISTAS
-- =====================================================

-- Vista de alumnos con sus documentos
CREATE OR REPLACE VIEW vista_alumnos_completa AS
SELECT
    a.*,
    ld.dni_frente,
    ld.dni_dorso,
    ld.partida_nacimiento,
    ld.estado_titulo,
    ld.titulo_archivo,
    ld.tramite_constancia,
    ld.materias_adeudadas
FROM alumnos a
LEFT JOIN legajo_documentos ld ON a.id = ld.alumno_id;

-- Vista de cuotas pendientes con datos del alumno
CREATE OR REPLACE VIEW vista_cuotas_pendientes AS
SELECT
    c.*,
    a.nombre,
    a.apellido,
    a.dni,
    a.celular,
    a.email
FROM cuotas c
INNER JOIN alumnos a ON c.alumno_id = a.id
WHERE c.estado IN ('pendiente', 'vencida')
ORDER BY c.fecha_vencimiento ASC;

-- Vista de estadísticas por nivel
CREATE OR REPLACE VIEW vista_inscripciones_nivel AS
SELECT
    nivel_inscripcion,
    COUNT(*) as total_alumnos,
    SUM(CASE WHEN estado = 'aprobado' THEN 1 ELSE 0 END) as aprobados,
    SUM(CASE WHEN estado = 'pendiente' THEN 1 ELSE 0 END) as pendientes
FROM alumnos
GROUP BY nivel_inscripcion;

-- Vista de estado de pagos por alumno (para admin)
CREATE OR REPLACE VIEW vista_estado_pagos_alumno AS
SELECT
    a.id as alumno_id,
    a.nombre,
    a.apellido,
    a.dni,
    a.celular,
    a.email,
    a.codigo_inscripcion,
    COUNT(c.id) as total_cuotas,
    SUM(c.monto) as monto_total,
    SUM(c.monto_pagado) as total_pagado,
    SUM(c.monto - c.monto_pagado) as deuda_total,
    SUM(CASE WHEN c.estado = 'pagada' THEN 1 ELSE 0 END) as cuotas_pagadas,
    SUM(CASE WHEN c.estado = 'parcial' THEN 1 ELSE 0 END) as cuotas_parciales,
    SUM(CASE WHEN c.estado IN ('pendiente', 'vencida') THEN 1 ELSE 0 END) as cuotas_pendientes
FROM alumnos a
LEFT JOIN cuotas c ON a.id = c.alumno_id
GROUP BY a.id, a.nombre, a.apellido, a.dni, a.celular, a.email, a.codigo_inscripcion;

-- Vista de cuotas parciales
CREATE OR REPLACE VIEW vista_cuotas_parciales AS
SELECT
    c.*,
    a.nombre,
    a.apellido,
    a.dni,
    a.celular,
    (c.monto - c.monto_pagado) as deuda_restante
FROM cuotas c
INNER JOIN alumnos a ON c.alumno_id = a.id
WHERE c.estado = 'parcial'
ORDER BY c.fecha_vencimiento ASC;

-- =====================================================
-- POLÍTICAS RLS (Row Level Security) para Supabase
-- =====================================================

-- Habilitar RLS
ALTER TABLE alumnos ENABLE ROW LEVEL SECURITY;
ALTER TABLE legajo_documentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE cuotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE configuracion ENABLE ROW LEVEL SECURITY;
ALTER TABLE administradores ENABLE ROW LEVEL SECURITY;

-- Política para administradores (solo lectura para verificar login)
CREATE POLICY "Permitir lectura de administradores" ON administradores
    FOR SELECT USING (true);

-- Políticas públicas de lectura (ajustar según necesidad)
CREATE POLICY "Permitir lectura pública de alumnos" ON alumnos
    FOR SELECT USING (true);

CREATE POLICY "Permitir inserción pública de alumnos" ON alumnos
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Permitir lectura pública de legajo" ON legajo_documentos
    FOR SELECT USING (true);

CREATE POLICY "Permitir inserción pública de legajo" ON legajo_documentos
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Permitir lectura pública de cuotas" ON cuotas
    FOR SELECT USING (true);

CREATE POLICY "Permitir insercion de cuotas" ON cuotas
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Permitir actualizacion de cuotas" ON cuotas
    FOR UPDATE USING (true);

CREATE POLICY "Permitir actualizacion de alumnos" ON alumnos
    FOR UPDATE USING (true);

CREATE POLICY "Permitir lectura pública de configuración" ON configuracion
    FOR SELECT USING (true);

CREATE POLICY "Permitir actualizacion de configuracion" ON configuracion
    FOR UPDATE USING (true);

-- =====================================================
-- TABLA DE GALERIA (fotos para el front)
-- =====================================================
CREATE TABLE IF NOT EXISTS galeria (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo VARCHAR(150),
    descripcion TEXT,
    url_imagen TEXT NOT NULL,
    orden INTEGER DEFAULT 0,
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para galería
CREATE INDEX idx_galeria_orden ON galeria(orden);
CREATE INDEX idx_galeria_activo ON galeria(activo);

-- RLS para galería
ALTER TABLE galeria ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir lectura publica de galeria" ON galeria
    FOR SELECT USING (activo = true);

CREATE POLICY "Permitir gestion de galeria" ON galeria
    FOR ALL USING (true);

-- =====================================================
-- TABLA DE BANNERS (mensajes para el front)
-- =====================================================
CREATE TABLE IF NOT EXISTS banners (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo VARCHAR(150) NOT NULL,
    mensaje TEXT NOT NULL,
    tipo VARCHAR(20) DEFAULT 'info' CHECK (tipo IN ('info', 'warning', 'success', 'error')),
    url_enlace TEXT,
    activo BOOLEAN DEFAULT TRUE,
    fecha_inicio DATE,
    fecha_fin DATE,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS para banners
ALTER TABLE banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir lectura publica de banners" ON banners
    FOR SELECT USING (activo = true);

CREATE POLICY "Permitir gestion de banners" ON banners
    FOR ALL USING (true);

-- =====================================================
-- STORAGE BUCKETS para Supabase (ejecutar en Dashboard)
-- =====================================================
-- Crear estos buckets manualmente en Supabase Dashboard:
-- 1. fotos-alumnos
-- 2. documentos-dni
-- 3. documentos-partidas
-- 4. documentos-titulos
-- 5. documentos-certificados
-- 6. galeria (para fotos de la galeria del front)
