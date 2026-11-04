-- =========================================================
-- maintenance.sql
-- TP Unidad 6 - Parte 3: Revision semanal de mantenimiento
-- =========================================================
-- Ejecutar conectado a foodstore:
--   psql -h localhost -U postgres -d foodstore -f postgres/mantenimiento/maintenance.sql
-- NO usa VACUUM FULL (bloquea las tablas con lock exclusivo; no es
-- mantenimiento periodico).
-- =========================================================

-- 1) Autovacuum activo?
SHOW autovacuum;

-- 2) Revision: tuplas muertas y ultimas ejecuciones, manuales y automaticas
SELECT relname,
       n_live_tup,
       n_dead_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS pct_muertas,
       n_mod_since_analyze,
       last_vacuum, last_autovacuum,
       last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

-- 3) Tablas candidatas a ANALYZE: nunca analizadas (ni manual ni automaticamente)
--    o con muchas modificaciones desde el ultimo analyze.
SELECT relname,
       n_live_tup,
       n_mod_since_analyze,
       CASE WHEN last_analyze IS NULL AND last_autoanalyze IS NULL
            THEN 'nunca analizada' ELSE 'muchas modificaciones' END AS motivo
FROM pg_stat_user_tables
WHERE (last_analyze IS NULL AND last_autoanalyze IS NULL)
   OR n_mod_since_analyze > GREATEST(50, 0.1 * n_live_tup)
ORDER BY relname;

-- 4) Accion de mantenimiento segura: ANALYZE (solo actualiza estadisticas del
--    planificador, toma un lock liviano y no bloquea lecturas ni escrituras).
--    Se aplica unicamente a las tablas que devolvio la consulta 3 (descomentar
--    y reemplazar <tabla>); si devolvio 0 filas, no se ejecuta nada. La
--    justificacion (tabla, motivo y valores observados) se copia al informe.
--    VACUUM manual NO se ejecuta salvo que pct_muertas de la consulta 2 sea
--    alto en una tabla con volumen relevante y autovacuum no lo haya resuelto
--    (ej.: categorias tiene 3 muertas sobre 5 vivas = 37,5 %, pero 1 pagina:
--    irrelevante, no se justifica).
-- ANALYZE VERBOSE <tabla>;
