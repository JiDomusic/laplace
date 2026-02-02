-- =====================================================
-- MIGRACIÓN: Sistema de cuotas con 3 montos enteros
-- =====================================================

-- 1. Agregar nuevas columnas a la tabla cuotas (una por una)
ALTER TABLE cuotas ADD COLUMN IF NOT EXISTS monto_al_dia INTEGER DEFAULT 0;
ALTER TABLE cuotas ADD COLUMN IF NOT EXISTS monto_1er_vto INTEGER DEFAULT 0;
ALTER TABLE cuotas ADD COLUMN IF NOT EXISTS monto_2do_vto INTEGER DEFAULT 0;

-- 2. Migrar datos existentes: copiar 'monto' a las nuevas columnas
UPDATE cuotas
SET
  monto_al_dia = COALESCE(monto::integer, 0),
  monto_1er_vto = COALESCE(monto::integer, 0),
  monto_2do_vto = COALESCE(monto::integer, 0)
WHERE monto_al_dia = 0 OR monto_al_dia IS NULL;

-- 3. Crear tabla para configuración de montos por período/nivel
CREATE TABLE IF NOT EXISTS config_cuotas_periodo (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nivel VARCHAR(50) NOT NULL,
  bimestre INTEGER NOT NULL CHECK (bimestre >= 1 AND bimestre <= 6),
  anio INTEGER NOT NULL,
  monto_al_dia INTEGER NOT NULL DEFAULT 0,
  monto_1er_vto INTEGER NOT NULL DEFAULT 0,
  monto_2do_vto INTEGER NOT NULL DEFAULT 0,
  dia_fin_rango_a INTEGER DEFAULT 10,
  dia_fin_rango_b INTEGER DEFAULT 20,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(nivel, bimestre, anio)
);

-- 4. Índice para búsqueda rápida
CREATE INDEX IF NOT EXISTS idx_config_cuotas_periodo_lookup
ON config_cuotas_periodo(nivel, bimestre, anio);

-- 5. Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_config_cuotas_periodo_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS config_cuotas_periodo_updated_at ON config_cuotas_periodo;
CREATE TRIGGER config_cuotas_periodo_updated_at
  BEFORE UPDATE ON config_cuotas_periodo
  FOR EACH ROW
  EXECUTE FUNCTION update_config_cuotas_periodo_updated_at();

-- 6. Habilitar RLS en la nueva tabla
ALTER TABLE config_cuotas_periodo ENABLE ROW LEVEL SECURITY;

-- 7. Políticas de acceso para config_cuotas_periodo
-- Permitir lectura a usuarios autenticados
CREATE POLICY "Allow read config_cuotas_periodo" ON config_cuotas_periodo
  FOR SELECT USING (true);

-- Permitir escritura a usuarios autenticados (admins)
CREATE POLICY "Allow write config_cuotas_periodo" ON config_cuotas_periodo
  FOR ALL USING (true) WITH CHECK (true);
