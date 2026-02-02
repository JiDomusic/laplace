-- =============================================================
-- Script para limpiar cuotas duplicadas y prevenir futuros duplicados
-- Ejecutar en Supabase SQL Editor
-- =============================================================

-- 1. Ver cuotas duplicadas antes de eliminar (verificación)
SELECT alumno_id, concepto, fecha_vencimiento, COUNT(*) as cantidad
FROM cuotas
GROUP BY alumno_id, concepto, fecha_vencimiento
HAVING COUNT(*) > 1
ORDER BY cantidad DESC;

-- 2. Eliminar duplicados, manteniendo la cuota con mayor monto_pagado
--    Si ambas tienen el mismo monto_pagado, se queda la más reciente (mayor id)
DELETE FROM cuotas
WHERE id IN (
  SELECT id FROM (
    SELECT id,
      ROW_NUMBER() OVER (
        PARTITION BY alumno_id, concepto, fecha_vencimiento
        ORDER BY monto_pagado DESC, id DESC
      ) AS rn
    FROM cuotas
  ) ranked
  WHERE rn > 1
);

-- 3. Verificar que no queden duplicados
SELECT alumno_id, concepto, fecha_vencimiento, COUNT(*) as cantidad
FROM cuotas
GROUP BY alumno_id, concepto, fecha_vencimiento
HAVING COUNT(*) > 1;

-- 4. Agregar constraint UNIQUE para prevenir futuros duplicados
ALTER TABLE cuotas
ADD CONSTRAINT cuotas_alumno_concepto_vencimiento_unique
UNIQUE (alumno_id, concepto, fecha_vencimiento);
