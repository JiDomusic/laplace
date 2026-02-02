-- =====================================================
-- Script para eliminar alumnos con cuotas decimales
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- 1. VERIFICAR: Ver alumnos que tienen cuotas con montos decimales
SELECT DISTINCT a.id, a.nombre, a.apellido, a.dni,
  c.concepto, c.monto, c.monto_al_dia, c.monto_1er_vto, c.monto_2do_vto
FROM alumnos a
JOIN cuotas c ON c.alumno_id = a.id
WHERE c.monto != FLOOR(c.monto)
   OR c.monto_al_dia != FLOOR(c.monto_al_dia)
   OR c.monto_1er_vto != FLOOR(c.monto_1er_vto)
   OR c.monto_2do_vto != FLOOR(c.monto_2do_vto)
   OR c.monto_pagado != FLOOR(c.monto_pagado)
ORDER BY a.apellido, a.nombre;

-- 2. EJECUTAR: Eliminar alumnos con cuotas decimales (cuotas + legajos + alumno)
-- Como hay ON DELETE CASCADE en cuotas y legajos, basta con eliminar de alumnos
DELETE FROM alumnos
WHERE id IN (
  SELECT DISTINCT alumno_id FROM cuotas
  WHERE monto != FLOOR(monto)
     OR monto_al_dia != FLOOR(monto_al_dia)
     OR monto_1er_vto != FLOOR(monto_1er_vto)
     OR monto_2do_vto != FLOOR(monto_2do_vto)
     OR monto_pagado != FLOOR(monto_pagado)
);
