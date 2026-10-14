# BITACORA.md — Registro de uso de IA
## TP Unidad 5 — Administración y Seguridad de Food Store

---

## Formato de cada entrada

| Campo | Descripción |
|-------|-------------|
| **Parte** | A / B / C / D / E |
| **Prompt enviado a la IA** | Texto exacto o resumen fiel del prompt |
| **Respuesta relevante recibida** | Resumen de lo que la IA generó (no es necesario copiar la respuesta completa) |
| **Validación o corrección humana aplicada** | Qué quedó tal cual, qué se modificó y por qué |

---

## Parte A — Diseño e implementación de roles y permisos

### Registro A-1 — Especificación de roles (Kiro)

| Campo | Contenido |
|-------|-----------|
| **Parte** | A |
| **Prompt enviado a la IA** | Se le entregó a Kiro la especificación completa de requirements y design (archivo adjunto en el mensaje de sesión): roles de grupo `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`; roles de login `app_web` y `admin_datos`; permisos por objeto y por columna; `ALTER DEFAULT PRIVILEGES`; `SCRAM-SHA-256` y `CONNECTION LIMIT` para `app_web`. |
| **Respuesta relevante recibida** | Kiro generó los archivos: `docs/kiro_roles_spec/requirements.md`, `docs/kiro_roles_spec/design.md` y `sql/roles.sql`. El script incluye `DO $$ IF NOT EXISTS $$` para idempotencia, `GRANT` explícitos por objeto, permiso por columna sobre `clientes` para `rol_soporte`, `REVOKE DELETE, TRUNCATE` para `rol_app_escritura`, y `ALTER DEFAULT PRIVILEGES`. |
| **Validación o corrección humana aplicada** | Ver sección "Corrección A-1" más abajo. |

#### Corrección A-1 — Ajuste de nombres de objetos (error detectado)

**Problema identificado por el equipo:**

La especificación entregada a la IA usaba el nombre `usuario` para referirse a la
tabla de clientes (por ejemplo, `GRANT SELECT (id, nombre, apellido, mail, rol) ON usuario`),
pero el DDL real del proyecto (`parcial1_01_ddl_schema.sql`) define la tabla como
`clientes`. Del mismo modo, la spec mencionaba vistas `v_productos_vigentes` y
`v_categorias_vigentes` que no existen: los nombres reales son
`v_productos_vigentes_con_categoria`, `v_pedidos_con_cliente` y
`v_detalle_pedido_con_producto`.

**Cómo se detectó:** antes de aplicar el script generado se verificaron los nombres
contra el DDL fuente. Si se hubiera ejecutado sin revisar, todos los `GRANT`
sobre objetos con nombre incorrecto habrían fallado silenciosamente o con error.

**Corrección aplicada:** se renombraron todos los objetos en `roles.sql` para
coincidir con el esquema real. También se corrigió la vista `v_pedidos_resumen`
(mencionada en la spec) por `v_pedidos_con_cliente` (nombre real). La vista
materializada se ajustó de `mv_ventas_categoria_mes` a `mv_facturacion_categoria_mes`.

**Qué se aceptó sin cambios:** la estructura general del script (secciones, orden
de ejecución, uso de `DO $$ IF NOT EXISTS $$`, `REVOKE` explícito, `ALTER DEFAULT
PRIVILEGES`) se aceptó tal cual porque es correcta y sigue buenas prácticas.

---

### Registro A-2 — Auditoría del script por la IA (punto 4 de la Parte A)

| Campo | Contenido |
|-------|-----------|
| **Parte** | A |
| **Prompt enviado a la IA** | "Auditá este `roles.sql` y proponé mejoras o correcciones de seguridad." |
| **Respuesta relevante recibida** | IA auditó `roles.sql` e identificó 6 áreas de mejora: (1) contradicción CREATEDB/NOCREATEDB en `admin_datos`, (2) placeholders de password, (3) `CONNECTION LIMIT 10` bajo en `app_web`, (4) permisos de columna en `clientes` para `rol_soporte` incluyen `mail`/`celular`, (5) falta de `REVOKE DELETE/TRUNCATE` para `rol_soporte` en `clientes`, (6) `ALTER DEFAULT PRIVILEGES` solo para `admin_datos`. |
| **Validación o corrección humana aplicada** | Se propusieron correcciones para los puntos 1 y 3. El punto 4 fue analizado: la consigna lo requiere para atención al cliente, pero en producción se deberían enmascarar. No existen `GRANT ALL` en el script; todos los grants son puntuales. Se documentaron las justificaciones por cada punto. Se registraron en la bitácora los casos de permisos potencialmente amplios (puntos 1, 3 y 4). |

> **Nota:** Auditoría completada. Se identificaron permisos que podrían ser más restrictivos (ver sección "Permisos potencialmente amplios" en el reporte de auditoría). El punto 4 de la Parte A (validar si algún GRANT es más amplio que lo necesario) fue resuelto: no hay `GRANT ALL`, pero `UPDATE ON productos` y `ALTER DEFAULT PRIVILEGES` podrían reducirse según el principio de mínimo privilegio.

---

## Casos de permisos potencialmente más amplios de lo necesario

A continuación se detallan los casos encontrados donde algún grants podría considerarse más amplio de lo estrictamente necesario según el principio de mínimo privilegio:

| **Parte** | **A** |
|-----------|-------|
| **Prompt** | Auditoría de `roles.sql` en busca de permisos más amplios de lo necesario |
| **Respuesta relevante** | Se identificaron los siguientes casos: |
| **Validación o corrección humana aplicada** | | |

### Caso 1: `UPDATE ON productos` en `rol_app_escritura`

| Campo | Descripción |
|-------|-------------|
| **Objeto** | Tabla `productos` |
| **Rol** | `rol_app_escritura` |
| **Grant actual** | `GRANT SELECT, UPDATE ON productos TO rol_app_escritura;` |
| **Por qué es amplio** | El UPDATE afecta todas las columnas de la tabla `productos`. Según el TP, el procedimiento `sp_crear_pedido` solo realiza `SELECT ... FOR UPDATE` y UPDATE sobre `stock`, por lo que teóricamente solo se necesita `UPDATE (stock)`. |
| **Propiedad propuesta** | `GRANT SELECT, UPDATE (stock) ON productos TO rol_app_escritura;` (PostgreSQL 9.0+) |
| **Qué se decidió** | Mantener `UPDATE ON productos` por compatibilidad con el procedimiento `sp_crear_pedido` y menor riesgo de romper funcionalidad existente. Documentado como "aceptable temporalmente" hasta que se refactorice el procedimiento. |
| **Verificación** | Script auditado y granted confirmado sobre la copia `foodstore_desarrollo` con `BEGIN; ... ROLLBACK;`. |

### Caso 2: `CONNECTION LIMIT 10` en `app_web`

| Campo | Descripción |
|-------|-------------|
| **Objeto** | Rol `app_web` |
| **Grant actual** | `CONNECTION LIMIT 10` |
| **Por qué es amplio** | Un bug o ataque DoS sencillo podría agotar las 10 conexiones disponibles, dejando la aplicación sin servicio. Un sitio web típico requiere al menos 50-100 conexiones concurrentes. |
| **Propiedad propuesta** | `CONNECTION LIMIT 100` o usar variable de entorno `$$CONNECTION LIMIT :'app_web_max_conn'`$$ |
| **Qué se decidió** | Aumentar a `CONNECTION LIMIT 100` como valor razonable para desarrollo/pruebas. En producción se recomienda externalizar el valor o ajustar según métricas de carga reales. |
| **Verificación** | Validado que el rol `app_web` sigue funcionando con el nuevo límite y que los testeos de conexión múltiple no fallan. |

### Caso 3: Permisos de columna `mail` y `celular` en `clientes` para `rol_soporte`

| Campo | Descripción |
|-------|-------------|
| **Objeto** | Tabla `clientes` |
| **Rol** | `rol_soporte` |
| **Grant actual** | `GRANT SELECT (id, nombre, apellido, mail, celular, rol) ON clientes TO rol_soporte;` |
| **Por qué es amplio** | Incluye `mail` y `celular`, que son datos personales que podrían considerarse sensibles. La consigna los requiere, pero en un entorno real estos campos deberían estar enmascarados a nivel de columna o el rol debería tener solo `id, nombre, apellido`. |
| **Propiedad propuesta** | `GRANT SELECT (id, nombre, apellido) ON clientes TO rol_soporte;` (quitar `mail` y `celular`) |
| **Qué se decidió** | Mantener el grant actual porque la consigna TP requiere específicamente estos campos para el ejercicio de "permiso a nivel de columna requerido por la consigna". Documentado que en producción se deberían añadir políticas de RLS o enmascaramiento. |
| **Verificación** | Grant aplicado confirmado sobre `foodstore_desarrollo`; se comprobó que `rol_soporte` puede leer los 6 campos especificados. |

---

---

## Parte B — Activación y prueba de la auditoría

### Registro B-1 — Configuración de parámetros de log

| Campo | Contenido |
|-------|-----------|
| **Parte** | B |
| **Prompt enviado a la IA** | Se le pidió a Kiro que generara el script de prueba `auditoria_test.sql` y el `informe_auditoria.md` describiendo los parámetros `log_connections`, `log_disconnections`, `log_statement`, `log_failed_auth` y `log_line_prefix`, con análisis de utilidad y limitaciones. |
| **Respuesta relevante recibida** | Kiro generó `sql/auditoria_test.sql` con la secuencia de SELECT, INSERT, UPDATE y documentación del login fallido externo; e `informe_auditoria.md` con la tabla de parámetros, el análisis de qué registra y qué no, y la respuesta sobre el log como activo sensible. |
| **Validación o corrección humana aplicada** | El log real y los valores exactos de las líneas del fragmento deben completarse ejecutando `sql/auditoria_test.sql` contra `foodstore_desarrollo` con los parámetros activos, y copiando el fragmento real al archivo `docs/log_auditoria_prueba.txt`. Los valores de ejemplo en el informe son representativos, no reales: deben reemplazarse con la salida real del experimento. |

---

## Parte C — Simulacro de incidente

### Registro C-1 — Reconstrucción del incidente con OpenCode

| Campo | Contenido |
|-------|-----------|
| **Parte** | C |
| **Prompt enviado a la IA** | "A partir de este fragmento de log de PostgreSQL, reconstruí qué ocurrió y proponé una hipótesis de contención." (se adjuntó el contenido de `capturas/logs_tp5_roles/log_simulacro_anonimizado.txt` sin contexto adicional) |
| **Respuesta relevante recibida** | OpenCode identificó correctamente las 5 fases: 3 intentos fallidos con `md5()`, login exitoso, lectura masiva de `clientes`, intento de escalamiento fallido y desconexión. Propuso como contención: aplicar RLS, revisar jerarquía de roles, auditar la Fase 3, corregir el orden de deployment y revisar `pg_hba.conf`. |
| **Validación o corrección humana aplicada** | **Error detectado:** OpenCode interpretó el fallo del escalamiento como un defecto de configuración ("jerarquía mal configurada") y recomendó darle opción ADMIN a `admin_datos`. Esto es incorrecto — el fallo es el comportamiento correcto y esperado por diseño. Aplicar esa recomendación debilitaría el esquema. **Omisión detectada:** la IA no distinguió que la Fase 3 ocurrió con el usuario `postgres` y no con `app_web`, lo cual cambiaría el análisis del alcance del incidente. La decisión de contención final fue tomada por el equipo (ver `docs/informe_incidente.md` sección 6), no delegada a la IA. |

---

## Parte D — Protección de datos personales

### Registro D-1 — Construcción de clientes_anon y consultas de equivalencia

| Campo | Contenido |
|-------|-----------|
| **Parte** | D |
| **Prompt enviado a la IA** | Se le pidió a Kiro que generara el script `sql/usuario_anon.sql` con la tabla `clientes_anon` usando datos sintéticos deterministas, y las consultas de agregación equivalentes sobre la tabla real y la anonimizada para verificar que los resultados coinciden. También se pidió el documento `docs/verificacion_equivalencia.md`. |
| **Respuesta relevante recibida** | Kiro generó `sql/usuario_anon.sql` con `CREATE TABLE clientes_anon AS SELECT ...` usando `'Cliente' \|\| id` para nombre, `'cliente_' \|\| id \|\| '@anon.example.com'` para mail, `DATE_TRUNC('month', created_at)` para preservar granularidad temporal sin exponer fecha exacta, y conservando `rol` y `eliminado` para que los agregados sean equivalentes. También generó la consulta de verificación con `FULL OUTER JOIN` que devuelve 0 filas si los resultados son idénticos. |
| **Validación o corrección humana aplicada** | El script es correcto. Se verificó que la lógica de truncado de fechas preserva la equivalencia de los agregados por mes. Los resultados reales deben completarse ejecutando el script y pegando las salidas en `docs/verificacion_equivalencia.md`. |

---

## Caso más significativo de error de la IA (Parte E — análisis)

El caso más significativo detectado durante el trabajo es el del **Registro C-1**:
al analizar el log del simulacro, OpenCode identificó correctamente las cuatro
fases del incidente pero cometió un error de interpretación crítico en la fase de
escalamiento. El error `se ha denegado el permiso para otorgar el rol «admin_datos»`
fue interpretado como evidencia de una "jerarquía de roles mal configurada" que
debía corregirse, y la IA recomendó darle la opción ADMIN al rol `admin_datos`.
Esta recomendación es incorrecta y peligrosa: el fallo es exactamente el
comportamiento esperado y deseado por el diseño de la Parte A. Seguir esa
sugerencia hubiera debilitado el esquema de seguridad que acabábamos de construir.
El error se detectó porque el equipo conocía de antemano qué debía ocurrir en cada
fase del simulacro y pudo contrastar la hipótesis de la IA contra la evidencia real,
en lugar de aceptarla como válida sin verificación.

---

## Historial de Git

Los commits se realizaron al finalizar el trabajo completo, agrupados por parte,
siguiendo el criterio de la consigna. Para la próxima entrega se recomienda
commitear al terminar cada parte para tener un historial más granular que refleje
el avance progresivo del trabajo.

---

## Historial de revisiones de esta bitácora

| Fecha | Parte | Acción |
|-------|-------|--------|
| 2026-10-14 | A, B | Creación inicial con registros A-1 y B-1 |
| 2026-10-14 | A | Registro A-2 completado tras auditoría con OpenCode |
| 2026-10-14 | C | Registro C-1 completado tras simulacro e intercambio con OpenCode |
| 2026-10-14 | D | Registro D-1 completado tras construcción de clientes_anon |
| 2026-10-14 | E | Consolidación final, análisis de error significativo e historial Git |
