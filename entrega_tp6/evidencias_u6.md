# Evidencias — TP Unidad 6 (Food Store)

Salidas reales obtenidas el 2026-10-21 11:52 con PostgreSQL 17.11 sobre `foodstore_desarrollo`. Los archivos .dump se incluyen en `backups/` (el usado en el simulacro es `foodstore_20261021_114403.dump`; el de las 11:39 es de una prueba previa).

## 1. Respaldo generado (Parte 2)

Contenido de `backups/` (solo respaldos .dump):
```
10894547 bytes  2026-10-21 11:39  foodstore_20261021_113929.dump
10894547 bytes  2026-10-21 11:44  foodstore_20261021_114403.dump
```

Verificación de que el .dump es un respaldo válido (`pg_restore --list`, primeras líneas y total de entradas):
```
;
; Archive created at 2026-10-21 11:44:03
;     dbname: foodstore_desarrollo
;     TOC Entries: 75
;     Compression: gzip
;     Dump Version: 1.16-0
;     Format: CUSTOM
;     Integer: 4 bytes
;     Offset: 8 bytes
;     Dumped from database version: 17.11
;     Dumped by pg_dump version: 17.11
;
... total de entradas: 71
```

### Log del respaldo (`logs/backup_foodstore.log`)

Las dos primeras líneas con ERROR corresponden al problema real descrito en el informe (pg_dump falló y se corrigió el script).
```
[2026-10-21 11:24:29] Inicio de respaldo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_112428.dump
[2026-10-21 11:24:29] ERROR: pg_dump fallo con codigo 1. Respaldo NO completado.
[2026-10-21 11:24:47] ERROR: PGPASSWORD no esta definida en el entorno. Definirla antes de ejecutar el script.
[2026-10-21 11:35:26] Inicio de respaldo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_113526.dump
[2026-10-21 11:35:26] OK: Respaldo completado. Archivo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_113526.dump (13.63 KB).
[2026-10-21 11:35:50] Inicio de respaldo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_113550.dump
[2026-10-21 11:35:50] OK: Respaldo completado. Archivo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_113550.dump (13.63 KB).
[2026-10-21 11:39:30] Inicio de respaldo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_113929.dump
[2026-10-21 11:39:36] OK: Respaldo completado. Archivo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_113929.dump (10639.21 KB).
[2026-10-21 11:44:03] Inicio de respaldo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_114403.dump
[2026-10-21 11:44:08] OK: Respaldo completado. Archivo: C:\Users\agusf\Desktop\foodstore_bd\foodstore_bd\backups\foodstore_20261021_114403.dump (10639.21 KB).
```

## 2. Chequeo de salud (Parte 3, `sql/health_check.sql`)
```
         base         | tamano 
----------------------+--------
 foodstore_desarrollo | 186 MB
(1 fila)

 conexiones_activas | xact_commit | xact_rollback | pct_rollback 
--------------------+-------------+---------------+--------------
                  1 |       23166 |            35 |         0.15
(1 fila)

    relname     | n_live_tup | n_dead_tup | pct_muertas |        last_autovacuum        |       last_autoanalyze       
----------------+------------+------------+-------------+-------------------------------+------------------------------
 pedidos        |     200000 |          4 |        0.00 | 2026-09-03 17:19:04.57563-03  | 
 categorias     |          5 |          3 |       37.50 |                               | 
 clientes       |      20000 |          0 |        0.00 | 2026-09-03 17:19:04.727941-03 | 
 clientes_anon  |      20000 |          0 |        0.00 | 2026-10-14 12:07:09.151689-03 | 2026-10-14 12:07:09.64231-03
 detalle_pedido |     600000 |          0 |        0.00 | 2026-09-03 17:19:03.704576-03 | 
 productos      |      50000 |          0 |        0.00 | 2026-09-03 17:19:04.669378-03 | 
(6 filas)

 pid | state | duracion | query 
-----+-------+----------+-------
(0 filas)

```

## 3. Revisión de mantenimiento (Parte 3, `sql/maintenance.sql`)

La consulta de candidatas a ANALYZE devuelve 0 filas: todas las tablas tienen `n_mod_since_analyze = 0`. No se ejecutó VACUUM ni ANALYZE adicional (no hay observación que lo justifique) y no se usó VACUUM FULL.
```
 autovacuum 
------------
 on
(1 fila)

    relname     | n_live_tup | n_dead_tup | pct_muertas | n_mod_since_analyze |          last_vacuum          |        last_autovacuum        |         last_analyze          |       last_autoanalyze       
----------------+------------+------------+-------------+---------------------+-------------------------------+-------------------------------+-------------------------------+------------------------------
 pedidos        |     200000 |          4 |        0.00 |                   0 | 2026-09-10 12:38:34.767627-03 | 2026-09-03 17:19:04.57563-03  | 2026-10-21 11:39:42.18824-03  | 
 categorias     |          5 |          3 |       37.50 |                   0 |                               |                               | 2026-10-21 11:39:41.220179-03 | 
 clientes       |      20000 |          0 |        0.00 |                   0 |                               | 2026-09-03 17:19:04.727941-03 | 2026-10-21 11:39:43.066102-03 | 
 clientes_anon  |      20000 |          0 |        0.00 |                   0 |                               | 2026-10-14 12:07:09.151689-03 | 2026-10-21 11:39:43.696073-03 | 2026-10-14 12:07:09.64231-03
 detalle_pedido |     600000 |          0 |        0.00 |                   0 | 2026-09-10 12:38:35.080392-03 | 2026-09-03 17:19:03.704576-03 | 2026-10-21 11:39:42.400785-03 | 
 productos      |      50000 |          0 |        0.00 |                   0 | 2026-09-10 12:38:35.359644-03 | 2026-09-03 17:19:04.669378-03 | 2026-10-21 11:39:41.98567-03  | 
(6 filas)

 relname | n_live_tup | n_mod_since_analyze | motivo 
---------+------------+---------------------+--------
(0 filas)

```

## 4. Simulacro de restauración (Parte 4, `sql/restore_test.ps1`)

### Log del simulacro (`logs/restore_test.log`)
```
[2026-10-21 11:44:09] Respaldo usado: foodstore_20261021_114403.dump (creado 2026-10-21 11:44:08, antiguedad 0 min, 10639.21 KB)
[2026-10-21 11:44:09] INICIO cronometro (restauracion en foodstore_restore_test)
[2026-10-21 11:44:24] Conteo categorias: referencia=5 restaurado=5 OK
[2026-10-21 11:44:24] Conteo clientes: referencia=20000 restaurado=20000 OK
[2026-10-21 11:44:24] Conteo productos: referencia=50000 restaurado=50000 OK
[2026-10-21 11:44:24] Conteo pedidos: referencia=200000 restaurado=200000 OK
[2026-10-21 11:44:24] Conteo detalle_pedido: referencia=600000 restaurado=600000 OK
[2026-10-21 11:44:24] productos_invalidos=0 detalles_invalidos=0
[2026-10-21 11:44:24] Tiempo createdb+pg_restore: 14,0 s
[2026-10-21 11:44:24] RTO observado (createdb + restore + validaciones): 14,8 s
[2026-10-21 11:44:24] OK: restauracion validada en foodstore_restore_test.
```

### Conteos actuales de la base restaurada `foodstore_restore_test`
```
     tabla      | filas  
----------------+--------
 categorias     |      5
 clientes       |  20000
 productos      |  50000
 pedidos        | 200000
 detalle_pedido | 600000
(5 filas)

 productos_invalidos 
---------------------
                   0
(1 fila)

 detalles_invalidos 
--------------------
                  0
(1 fila)

```

## 5. Seguridad

Ningún archivo de esta entrega contiene contraseñas (`PGPASSWORD` se toma del entorno o de un `.env` no versionado). Comprobación sobre los archivos de esta carpeta:
```
sin coincidencias: no hay contraseñas en scripts ni documentos
```
