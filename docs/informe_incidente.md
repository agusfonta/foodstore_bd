# Informe de Incidente — Parte C
## TP Unidad 5 — Food Store

---

## 1. Descripción del simulacro

Se reprodujo de forma controlada, exclusivamente sobre la base de desarrollo
`foodstore_desarrollo`, una secuencia de acceso indebido compuesta por cuatro
fases:

| Fase | Acción | Script |
|------|--------|--------|
| 1 | Tres intentos fallidos de autenticación via consultas a `clientes` con credenciales incorrectas | `sql/simulacro_incidente.sql` — Fase 1 |
| 2 | Inicio de sesión exitoso (autenticación correcta) | `sql/simulacro_incidente.sql` — Fase 2 |
| 3 | Lectura masiva de la tabla `clientes` (exfiltración de datos) | `sql/simulacro_incidente.sql` — Fase 3 |
| 4 | Intento de escalamiento de privilegios: `GRANT admin_datos TO rol_app_lectura` | `sql/simulacro_incidente.sql` — Fase 4 |

---

## 2. Verificación del escalamiento de privilegios

El intento de escalamiento se ejecutó conectado como `app_web`:

```sql
-- Conectado como app_web:
GRANT admin_datos TO rol_app_lectura;
```

**Evidencia capturada:**

- `capturas/logs_tp5_roles/parteC_01_simulacro_lectura_masiva.jpeg` — ejecución del script del simulacro: intentos fallidos, login exitoso y lectura masiva de `clientes`
- `capturas/logs_tp5_roles/parteC_02_escalamiento_denegado.jpeg` — error al intentar el escalamiento de privilegios

**Resultado obtenido:**

```
ERROR:  se ha denegado el permiso para otorgar el rol «admin_datos»
DETAIL:  Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
```

**Conclusión:** el intento de escalamiento **falló correctamente**. El diseño de
roles de la Parte A es válido: `app_web` no tiene `SUPERUSER` ni `CREATEROLE`,
por lo que no puede otorgar membresía en ningún rol.

> Si el escalamiento NO hubiera fallado, se habría documentado como hallazgo
> crítico y se habría corregido el esquema de permisos antes de continuar.

---

## 3. Log anonimizado de la secuencia

El log real capturado se encuentra en:
`capturas/logs_tp5_roles/log_simulacro_anonimizado.txt`

Para anonimizarlo se reemplazaron:
- Mails reales → `cliente_001@example.com`, `cliente_002@example.com`, etc.
- Nombres reales → `Cliente Uno`, `Cliente Dos`, etc.
- IPs reales → `192.168.x.x`
- PID reales → `[XXXXX]`

**Criterio de anonimización:** mismo criterio que `usuario_anon` de la Parte D —
los datos sintéticos son deterministas (siempre el mismo dato real → mismo valor
sintético) para que el log sea coherente internamente pero no exponga datos reales
al asistente de IA.

### Fragmento representativo del log anonimizado

```
2026-10-14 11:45:01 -03 [XXXXX] postgres@foodstore_desarrollo LOG:  statement: SELECT id, nombre, apellido FROM clientes WHERE mail = 'atacante_test@example.com' AND contrasenia = md5('password_incorrecta_1') AND eliminado = FALSE;
2026-10-14 11:45:01 -03 [XXXXX] postgres@foodstore_desarrollo LOG:  statement: SELECT id, nombre, apellido FROM clientes WHERE mail = 'cliente_001@example.com' AND contrasenia = md5('password_incorrecta_2') AND eliminado = FALSE;
2026-10-14 11:45:02 -03 [XXXXX] postgres@foodstore_desarrollo LOG:  statement: SELECT id, nombre, apellido FROM clientes WHERE mail = 'cliente_001@example.com' AND contrasenia = md5('password_incorrecta_3') AND eliminado = FALSE;
2026-10-14 11:45:03 -03 [XXXXX] postgres@foodstore_desarrollo LOG:  statement: SELECT id, nombre, apellido, mail, rol FROM clientes WHERE eliminado = FALSE LIMIT 1;
2026-10-14 11:45:04 -03 [XXXXX] postgres@foodstore_desarrollo LOG:  statement: SELECT id, nombre, apellido, mail, celular, rol, created_at FROM clientes WHERE eliminado = FALSE ORDER BY id;
2026-10-14 11:45:05 -03 [XXXXX] app_web@foodstore_desarrollo ERROR:  must be superuser or have admin option on role "admin_datos"
2026-10-14 11:45:05 -03 [XXXXX] app_web@foodstore_desarrollo STATEMENT:  GRANT admin_datos TO rol_app_lectura;
```

---

## 4. Respuesta de la IA (OpenCode) sobre el log anonimizado

> **Prompt enviado:** se entregó el fragmento de log anonimizado a OpenCode sin
> agregar contexto adicional, con la instrucción: *"A partir de este fragmento
> de log de PostgreSQL, reconstruí qué ocurrió y proponé una hipótesis de
> contención."*

**Respuesta de OpenCode (transcripción):**

| Fase | Hora | Reconstrucción de OpenCode |
|------|------|---------------------------|
| 1 | 11:48:01 | 3 intentos fallidos con `SELECT ... WHERE mail ... AND contrasenia = md5(...)` — posible SQL injection o adivinanza de contraseña |
| 2 | 11:48:01 | Login exitoso: `SELECT id, nombre, apellido, mail, rol FROM clientes WHERE eliminado = FALSE LIMIT 1` |
| 3 | 11:48:01 | Lectura masiva exfiltrada: `SELECT ... FROM clientes WHERE eliminado = FALSE ORDER BY id` — posible escape completo de la tabla |
| 4 | 11:51:22 | Intento fallido de `SET ROLE app_web; GRANT admin_datos TO rol_app_lectura` — denegado por falta de opción ADMIN |
| 5 | 11:51:22 | Desconexión del rol postgres |

**Hipótesis principal de OpenCode:** falta de Row-Level Security (RLS) sobre `clientes`, jerarquía de roles mal configurada, y brechas en el deployment por GRANTs sobre objetos inexistentes.

**Contención recomendada por OpenCode:**
1. Aplicar RLS inmediato en `clientes` por rol/usuario
2. Revisar `admin_datos` con opción ADMIN o reestructurar la jerarquía
3. Auditar filas leídas en la Fase 3
4. Corregir secuencia de deployment: crear funciones/procedimientos antes de `GRANT EXECUTE`
5. Revisar `pg_hba.conf` para restringir orígenes de conexión

---

## 5. Contraste entre la reconstrucción de la IA y lo realmente ejecutado

| Aspecto | Lo que ejecutó el equipo | Lo que dijo la IA | Evaluación |
|---------|--------------------------|-------------------|------------|
| Cantidad de intentos fallidos | 3 intentos con contraseñas incorrectas | 3 intentos — correcto | ✅ Acertó |
| Método de autenticación | `SELECT` directo sobre `clientes` con `md5()` | Identificó correctamente el patrón `SELECT ... md5(...)` | ✅ Acertó |
| Acción tras el login exitoso | Lectura masiva de toda la tabla `clientes` | Identificó la exfiltración masiva | ✅ Acertó |
| Intento de escalamiento | `GRANT admin_datos TO rol_app_lectura` como `app_web` vía `SET ROLE` | Identificó el `GRANT` y el `SET ROLE` | ✅ Acertó |
| Resultado del escalamiento | ERROR — falló correctamente por diseño | Lo identificó como fallo, pero lo atribuyó a "jerarquía mal configurada" | ⚠️ Parcialmente incorrecto — ver nota |
| Causa del fallo de escalamiento | El rol `app_web` no tiene `CREATEROLE` ni `ADMIN OPTION`: es el comportamiento correcto y esperado | Lo interpretó como un **defecto de configuración** a corregir | ❌ Error de interpretación |
| Errores de GRANT en roles.sql | GRANTs fallidos porque los procedimientos no estaban cargados al correr roles.sql | Los identificó como "brechas de validación en el deployment" | ✅ Acertó en el diagnóstico |
| Recomendación RLS | No se implementó RLS en el simulacro | Propuso aplicar RLS inmediato | ⚠️ Sugerencia válida pero fuera del alcance del simulacro diseñado |

### Análisis crítico de los errores de la IA

**Error principal — el escalamiento fallido:**
OpenCode interpretó el error `se ha denegado el permiso para otorgar el rol «admin_datos»`
como evidencia de una **jerarquía mal configurada** y recomendó "revisar/crear `admin_datos`
con opción ADMIN si se requiere otorgamiento". Esto es **incorrecto**: el fallo es
exactamente el comportamiento deseado. El diseño de la Parte A establece deliberadamente
que `app_web` no puede escalar privilegios. Si se siguiera esta recomendación de la IA
se estaría **debilitando** el esquema de seguridad, no corrigiéndolo.

**Omisión notable:**
La IA no señaló que la Fase 3 (lectura masiva) ocurrió con el usuario `postgres`
(superusuario), no con `app_web`. En un incidente real esto cambiaría completamente
el análisis: significaría que el atacante ya tenía acceso de superusuario, no solo
de usuario de aplicación. La IA no distinguió entre las sesiones de distintos usuarios
en el log.

---

## 6. Decisión de contención

**Esta decisión es del equipo, tomada a partir de la evidencia del log.**
No es una acción ejecutada automáticamente a partir de lo que sugirió la IA.

En un caso real, ante esta secuencia de eventos el equipo tomaría las siguientes
medidas, en orden de prioridad:

### Medida 1 — Bloqueo inmediato de la cuenta comprometida

```sql
-- Revocar el permiso de login de app_web hasta investigar el origen
ALTER ROLE app_web NOLOGIN;
-- Reactivar cuando se confirme que el vector de ataque fue cerrado:
-- ALTER ROLE app_web LOGIN;
```

**Justificación:** si las credenciales de `app_web` fueron comprometidas, bloquear
el login impide nuevas conexiones mientras se investiga. Es reversible y no
destruye datos.

### Medida 2 — Forzar rotación de contraseña

```sql
ALTER ROLE app_web PASSWORD 'nueva_password_segura_generada_aleatoriamente';
```

**Justificación:** invalida las credenciales robadas sin necesidad de eliminar el rol.

### Medida 3 — Revisar y revocar sesiones activas

```sql
-- Ver sesiones activas de app_web
SELECT pid, usename, application_name, client_addr, state, query_start
FROM pg_stat_activity
WHERE usename = 'app_web';

-- Terminar sesiones sospechosas
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE usename = 'app_web';
```

### Medida 4 — Auditoría del alcance de la exfiltración

Revisar el log completo para determinar:
- Cuántas filas de `clientes` fueron leídas
- Si hubo otros accesos a tablas sensibles (`pedidos`, `detalle_pedido`)
- Desde qué IP se conectó el atacante

### Lo que el equipo NO haría automáticamente

- **No se eliminarían roles ni usuarios** sin confirmar primero el alcance del incidente.
- **No se ejecutaría ninguna acción sugerida por la IA** sin validar primero que
  corresponde a la evidencia real del log.
- **No se notificaría a los clientes afectados** basándose solo en la hipótesis
  de la IA — se esperaría la confirmación del análisis forense.
