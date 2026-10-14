# Informe de Auditoría — Parte B
## TP Unidad 5 — Food Store

---

## 1. Parámetros de auditoría configurados

Los siguientes parámetros se modificaron en `postgresql.conf` del servidor de
desarrollo (instancia local Windows, PostgreSQL 16/17).

Para editar el archivo desde PowerShell:

```powershell
# Ubicar el archivo de configuración
psql -U postgres -c "SHOW config_file;"

# Editar con notepad (ajustar la ruta según la versión instalada)
notepad "C:\Program Files\PostgreSQL\17\data\postgresql.conf"
```

Después de editar, recargar la configuración sin reiniciar el servicio:

```sql
SELECT pg_reload_conf();
-- O desde PowerShell:
-- pg_ctl reload -D "C:\Program Files\PostgreSQL\17\data"
```

### Parámetros configurados

| Parámetro | Valor configurado | Valor por defecto | Justificación |
|-----------|------------------|-------------------|---------------|
| `log_connections` | `on` | `off` | Registra cada nueva conexión establecida: quién se conectó, desde dónde y cuándo. |
| `log_disconnections` | `on` | `off` | Registra el cierre de sesión incluyendo la duración total de la conexión. |
| `log_statement` | `'mod'` | `'none'` | Registra todas las instrucciones de modificación (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`). Con `'all'` también registra `SELECT`, pero genera un volumen excesivo en producción. |
| `log_failed_auth` | `on` | `off` | Registra explícitamente los intentos de autenticación fallidos (disponible desde PG 14). |
| `log_min_duration_statement` | `1000` | `-1` (desactivado) | Registra toda consulta que tarde más de 1 segundo: útil para detectar consultas lentas además de las modificaciones. |
| `log_line_prefix` | `'%t [%p] %u@%d '` | `'%m [%p] '` | Agrega timestamp, PID, usuario y base de datos al inicio de cada línea del log. |

### Fragmento de `postgresql.conf` modificado

```
# Auditoría básica — TP Unidad 5 Food Store
log_connections             = on
log_disconnections          = on
log_statement               = 'mod'
log_failed_auth             = on
log_min_duration_statement  = 1000
log_line_prefix             = '%t [%p] %u@%d '
```

---

## 2. Secuencia de operaciones de prueba ejecutadas

Ver script completo: `sql/auditoria_test.sql`

| # | Operación | Comando | Resultado esperado en log |
|---|-----------|---------|--------------------------|
| 1 | Lectura | `SELECT` sobre `v_productos_vigentes_con_categoria` | **No aparece** con `log_statement = 'mod'` |
| 2 | Inserción | `INSERT INTO pedidos ...` | Aparece como `LOG: statement: INSERT ...` |
| 3 | Actualización | `UPDATE pedidos SET estado = 'CONFIRMADO'` | Aparece como `LOG: statement: UPDATE ...` |
| 4 | Login fallido | `psql -U usuario_inexistente -d foodstore_desarrollo` | `FATAL: password authentication failed for user "usuario_inexistente"` |

---

## 3. Fragmento de log capturado

> **Evidencia:** las capturas del log real se encuentran en
> `capturas/logs_tp5_roles/` (tres imágenes capturadas el 14/10/2026):
> - `parteB_01_log_parametros_auditoria.jpeg` — verificación de parámetros de log activos (`log_connections`, `log_statement`, `log_line_prefix`)
> - `parteB_02_log_insert_update.jpeg` — INSERT y UPDATE dentro de BEGIN/ROLLBACK registrados en el log
> - `parteB_03_log_login_fallido.jpeg` — intento de login fallido (FATAL: autenticación password falló)

Formato representativo de las líneas capturadas:

```
2026-10-14 10:23:01 -03 [12345] app_web@foodstore_desarrollo LOG:  connection received: host=127.0.0.1 port=54321
2026-10-14 10:23:01 -03 [12345] app_web@foodstore_desarrollo LOG:  connection authorized: user=app_web database=foodstore_desarrollo
2026-10-14 10:23:02 -03 [12345] app_web@foodstore_desarrollo LOG:  statement: INSERT INTO pedidos (estado, total, forma_pago, cliente_id) VALUES ('PENDIENTE', 0.00, 'EFECTIVO', 1);
2026-10-14 10:23:02 -03 [12345] app_web@foodstore_desarrollo LOG:  statement: UPDATE pedidos SET estado = 'CONFIRMADO', updated_at = CURRENT_TIMESTAMP WHERE id = 42;
2026-10-14 10:23:03 -03 [12345] app_web@foodstore_desarrollo LOG:  disconnection: session time: 0:00:02.341 user=app_web database=foodstore_desarrollo host=127.0.0.1 port=54321
2026-10-14 10:23:10 -03 [12400] usuario_inexistente@foodstore_desarrollo FATAL:  password authentication failed for user "usuario_inexistente"
```

---

## 4. Análisis del contenido del log

### 4.1 ¿Qué información es útil para auditoría?

Con la configuración activada, cada entrada del log responde a las cuatro
preguntas clave de auditoría:

| Pregunta | Información en el log | Parámetro que la registra |
|----------|-----------------------|--------------------------|
| **Quién** | Usuario de BD (`%u` en `log_line_prefix`) | `log_line_prefix` |
| **Qué** | Texto completo de la sentencia SQL | `log_statement = 'mod'` |
| **Cuándo** | Timestamp con zona horaria (`%t`) | `log_line_prefix` |
| **Desde dónde** | IP y puerto del cliente | `log_connections` |

El intento de login fallido también queda registrado con el nombre de usuario
que intentó conectarse, la base de datos de destino y la IP de origen.

### 4.2 ¿Qué queda fuera del alcance de este mecanismo?

Con `log_statement = 'mod'` y sin extensión adicional, el log nativo de
PostgreSQL **no puede registrar**:

- **Qué filas específicas fueron leídas o modificadas**: el log solo guarda el
  texto de la sentencia, no su resultado ni las filas afectadas. Para eso se
  necesitaría la extensión `pgaudit` con `pgaudit.log_relation = on`, que
  registra a nivel de relación (tabla) qué filas se leyeron o escribieron.

- **Sentencias `SELECT`** (con `log_statement = 'mod'`): una lectura masiva de
  datos sensibles no queda registrada. Para capturarla habría que usar
  `log_statement = 'all'` o `pgaudit` con `pgaudit.log = 'read'`.

- **Valores de parámetros en consultas parametrizadas**: si la aplicación usa
  `$1`, `$2`, el log muestra los placeholders, no los valores reales.

- **Cambios a nivel de objeto dentro de una transacción que hizo ROLLBACK**: el
  log registra la sentencia, pero no indica si la transacción se confirmó o
  revirtió (para eso se necesita correlacionar con `log_transactions` o `pgaudit`).

---

## 5. ¿Es el archivo de log un activo sensible?

Sí. El archivo de log **es en sí mismo un activo sensible** porque contiene el
texto completo de las sentencias SQL ejecutadas, incluyendo potencialmente
valores de datos personales que aparezcan en `INSERT` o `UPDATE` (nombres,
mails, totales de pedidos). Un atacante con acceso al archivo de log puede
reconstruir actividad de la base sin necesidad de conectarse a ella.

**Quién debería poder leerlo y con qué permisos:**

- A nivel de **sistema operativo**: el archivo debe ser propiedad del usuario
  del servicio PostgreSQL (típicamente `postgres`) con permisos `640` o `600`,
  es decir, lectura solo para el propietario y, opcionalmente, para un grupo
  de auditores dedicado. Ningún usuario de aplicación debe tener acceso al
  directorio de logs.
- A nivel de **motor PostgreSQL**: la función `pg_read_file()` y la vista
  `pg_log` (si está habilitada) deben restringirse al rol `pg_monitor` o a un
  rol específico de auditoría, no a roles de aplicación como `app_web`.
- En entornos regulados (datos personales, PCI-DSS), los logs deben enviarse a
  un sistema SIEM centralizado con controles de acceso propios, separados del
  servidor de base de datos.
