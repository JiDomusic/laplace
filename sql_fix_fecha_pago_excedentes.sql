-- =====================================================
-- Fix: Cuotas pagadas/parciales sin fecha_pago
-- (pagos por excedente que no grabaron la fecha)
-- Ejecutar en Supabase SQL Editor
-- =====================================================

-- 1. VER cuáles están afectadas
SELECT id, alumno_id, concepto, monto_pagado, estado, fecha_pago, detalle_pago
FROM cuotas
WHERE (estado = 'pagada' OR estado = 'parcial')
  AND fecha_pago IS NULL;

-- 2. CORREGIR: poner fecha de hoy a cuotas pagadas/parciales sin fecha
UPDATE cuotas
SET fecha_pago = NOW()
WHERE (estado = 'pagada' OR estado = 'parcial')
  AND fecha_pago IS NULL;
