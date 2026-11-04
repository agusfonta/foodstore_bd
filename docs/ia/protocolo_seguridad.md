# Protocolo de Seguridad — Foodstore TP2

Entorno confirmado:
- PostgreSQL: 17.11
- SO: Windows — terminal CMD + psql 17.11
- Usuario: postgres
- Host: localhost
- Puerto: 5432
- Base original: foodstore
- Base de trabajo: foodstore_desarrollo

---

## 1. Crear la Copia de Trabajo

Nunca operar directamente sobre `foodstore`. Trabajar siempre sobre una copia local creada con `createdb` usando la base original como plantilla.

```powershell
# Verificar que la base original existe
psql -U postgres -h localhost -p 5432 -lqt | findstr foodstore

# Crear copia de trabajo
createdb -U postgres -h localhost -p 5432 -T foodstore foodstore_desarrollo
```

---

## 2. Verificar la Conexión Activa

Antes de ejecutar cualquier sentencia, confirmar que la sesión está conectada a `foodstore_desarrollo` y no a la base original.

```powershell
# Conectarse a la copia
psql -U postgres -h localhost -p 5432 -d foodstore_desarrollo
```

Dentro de `psql`, ejecutar obligatoriamente:

```sql
\conninfo
SELECT current_database(), current_user;
```

**Comprobación obligatoria:**
- `current_database()` debe devolver `foodstore_desarrollo`
- `current_user` debe devolver `postgres`

Si el resultado difiere, **no continuar**. Reconectar a la base correcta.

---

## 3. Ejecutar Cambios en Transacción de Prueba (`BEGIN ... ROLLBACK`)

Todo script que escriba datos (DML: INSERT, UPDATE, DELETE) debe ejecutarse primero dentro de un bloque de transacción para inspeccionar el impacto antes de confirmar.

```sql
BEGIN;

-- 1. Aplicar operaciones de prueba (INSERT válidos, INSERT inválidos esperados, etc.)
-- 2. Consultar tablas afectadas para verificar comportamiento y mensajes de error

ROLLBACK;  -- Deshace TODO. Solo cambiar a COMMIT si la validación es 100% correcta.
```

**Regla:** El `ROLLBACK` es obligatorio por defecto. El `COMMIT` solo se usa tras revisar:
- Cantidad de filas afectadas
- Mensajes de error esperados (casos inválidos)
- Ausencia de errores inesperados

---

## 4. Respaldos con `pg_dump` — Diferenciación y Cuándo Usar Cada Uno

### Directorio de respaldos (relativo al repositorio)

```powershell
# Crear carpeta si no existe
if (-not (Test-Path -Path ".\backups")) { New-Item -ItemType Directory -Path ".\backups" }
```

### Tipos de Respaldo

| Tipo | Cuándo se usa | Comando |
|------|---------------|---------|
| **Completo (datos + esquema)** | Antes de operaciones destructivas masivas, migraciones de datos, o como snapshot general de la base de desarrollo. Incluye todos los datos de las tablas. | `pg_dump -U postgres -h localhost -p 5432 -d foodstore_desarrollo -F c -b -v -f ".\backups\respaldo_completo_$(Get-Date -Format 'yyyyMMdd_HHmmss').backup"` |
| **Solo Esquema (`--schema-only`)** | **Obligatorio antes de cualquier cambio DDL** (ALTER TABLE, CREATE FUNCTION, CREATE TRIGGER, DROP, etc.). Genera un respaldo de la estructura (tablas, índices, constraints, funciones, triggers, tipos, enums) sin datos, que puede utilizarse posteriormente para reconstruir el esquema si el cambio DDL falla o rompe algo. | `pg_dump -U postgres -h localhost -p 5432 -d foodstore_desarrollo --schema-only -F c -v -f ".\backups\respaldo_esquema_$(Get-Date -Format 'yyyyMMdd_HHmmss').backup"` |

**Notas:**
- Formato custom (`-F c`): binario, comprimido, permite restaurar selectivamente con `pg_restore`.
- Convención de nombres: timestamp `yyyyMMdd_HHmmss` para mantener histórico sin sobrescribir.

---

## 5. Ubicación y Gestión de Respaldos

- Carpeta: `.\backups\` (relativa a la raíz del repositorio)
- Esta carpeta **no se commitea** (agregar al `.gitignore`):
  ```
  backups/
  ```
- Los archivos `.backup` son binarios (formato custom `-F c`) y se restauran con `pg_restore`:
  ```powershell
  # Ejemplo de restauración de esquema
  pg_restore -U postgres -h localhost -p 5432 -d foodstore_desarrollo --schema-only ".\backups\respaldo_esquema_20260826_143000.backup"
  
  # Ejemplo de restauración completa
  pg_restore -U postgres -h localhost -p 5432 -d foodstore_desarrollo ".\backups\respaldo_completo_20260826_143000.backup"
  ```

---

## Resumen de Flujo Obligatorio

1. `createdb -T foodstore foodstore_desarrollo` → Copia de trabajo
2. `psql -d foodstore_desarrollo` + `SELECT current_database()` → Verificar conexión
3. `pg_dump --schema-only` → Respaldo estructural **antes de cualquier DDL**
4. `BEGIN; ... ROLLBACK;` → Validar DML en transacción de prueba
5. `COMMIT` solo tras confirmación explícita de resultados correctos