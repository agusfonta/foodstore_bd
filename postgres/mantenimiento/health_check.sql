-- =========================================================
-- health_check.sql
-- TP Unidad 6 - Parte 3: Chequeo de salud diario de foodstore
-- =========================================================
-- Solo lectura. Devuelve 4 result sets. Ejecutar conectado a foodstore:
--   psql -h localhost -U postgres -d foodstore -f postgres/mantenimiento/health_check.sql
-- Compatible con PostgreSQL 16+.
-- =========================================================

-- 1) Tamano de la base
SELECT current_database() AS base,
       pg_size_pretty(pg_database_size(current_database())) AS tamano;

-- 2) Actividad de conexiones y transacciones
SELECT numbackends AS conexiones_activas,
       xact_commit,
       xact_rollback,
       round(100.0 * xact_rollback / NULLIF(xact_commit + xact_rollback, 0), 2) AS pct_rollback
FROM pg_stat_database
WHERE datname = current_database();

-- 3) Estado de tablas: tuplas vivas/muertas y ultimo autovacuum/autoanalyze
SELECT relname,
       n_live_tup,
       n_dead_tup,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS pct_muertas,
       last_autovacuum,
       last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

-- 4) Consultas activas (excluye esta misma sesion y las sesiones inactivas)
SELECT pid,
       state,
       now() - query_start AS duracion,
       query
FROM pg_stat_activity
WHERE datname = current_database()
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY query_start;
