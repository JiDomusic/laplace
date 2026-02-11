  -- Asegurar columna mes
  ALTER TABLE config_cuotas_periodo ADD COLUMN IF NOT EXISTS mes integer;

  -- Expandir bimestres a mes par si aún falta
  INSERT INTO config_cuotas_periodo (nivel, mes, anio, monto_al_dia, monto_1er_vto, monto_2do_vto, dia_fin_rango_a, dia_fin_rango_b)
  SELECT
    nivel,
    (bimestre - 1) * 2 + 2 AS mes,
    anio,
    monto_al_dia,
    monto_1er_vto,
    monto_2do_vto,
    dia_fin_rango_a,
    dia_fin_rango_b
  FROM config_cuotas_periodo
  WHERE bimestre IS NOT NULL AND mes IS NULL
  ON CONFLICT DO NOTHING;

  -- Actualizar filas originales a mes impar
  UPDATE config_cuotas_periodo
  SET mes = (bimestre - 1) * 2 + 1
  WHERE bimestre IS NOT NULL AND mes IS NULL;

  -- Unique por nivel/mes/año (dropear si ya existe)
  DO $$
  BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'config_cuotas_periodo_nivel_mes_anio_key') THEN
      ALTER TABLE config_cuotas_periodo DROP CONSTRAINT config_cuotas_periodo_nivel_mes_anio_key;
    END IF;
  END$$;

  ALTER TABLE config_cuotas_periodo ADD CONSTRAINT config_cuotas_periodo_nivel_mes_anio_key UNIQUE (nivel, mes, anio);

  -- Índice
  CREATE INDEX IF NOT EXISTS idx_config_cuotas_periodo_nivel_mes_anio ON config_cuotas_periodo (nivel, mes, anio);

  -- Mes NOT NULL
  ALTER TABLE config_cuotas_periodo ALTER COLUMN mes SET NOT NULL;

  -- Recalcular bimestre desde mes (compatibilidad)
  UPDATE config_cuotas_periodo
  SET bimestre = ((mes - 1) / 2)::int + 1
  WHERE mes IS NOT NULL;

  COMMIT;
