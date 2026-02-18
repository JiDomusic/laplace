-- Agregar policy de DELETE para alumnos (faltaba)
CREATE POLICY "Permitir eliminacion de alumnos" ON alumnos
  FOR DELETE USING (true);

-- Agregar policy de DELETE para cuotas (por si también falta)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'cuotas' AND cmd = 'd'
  ) THEN
    EXECUTE 'CREATE POLICY "Permitir eliminacion de cuotas" ON cuotas FOR DELETE USING (true)';
  END IF;
END $$;
