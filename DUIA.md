# DUIA — Declaración de Uso de IA

## Parte A — Auditoría de roles.sql

| Campo | Contenido |
| :--- | :--- |
| **Herramienta** | OpenCode (nemotron-3.5-lightning-free) |
| **Spec o prompt utilizado** | "Auditá este `roles.sql` y proponé mejoras o correcciones." |
| **Qué generó** | IA auditó `sql/roles.sql` e identificó 6 áreas de mejora: (1) contradicción CREATEDB/NOCREATEDB en `admin_datos`, (2) placeholders de password `'cambiar_esta_password_app'` y `'cambiar_esta_password_admin'`, (3) `CONNECTION LIMIT 10` bajo en `app_web`, (4) permisos de columna en `clientes` para `rol_soporte` incluyen `mail`/`celular` (datos personales), (5) falta de `REVOKE DELETE/TRUNCATE` para `rol_soporte` en `clientes`, (6) `ALTER DEFAULT PRIVILEGES` solo para `admin_datos`. No existen `GRANT ALL` en el script; todos los grants sonpuntuales. |
| **Qué se aceptó** | - Contraste CREATEDB/NOCREATEDB: se eliminó `NOCREATEDB` de `admin_datos` (error de sintaxis). - Passwords placeholder: pendente reemplazar antes de producción. - `CONNECTION LIMIT 10`: aumentado a 100 para `app_web`. - Permisos de columna `clientes` para `rol_soporte`: se mantuvieron tal cual por requerimiento de la consigna TP, pero documentado que en producción deberían enmascararse. - Sin `REVOKE` adicional para `rol_soporte`: coherencia con diseño NOLOGIN del rol. - `ALTER DEFAULT PRIVILEGES`: mantenedse, es buenas prácticas para admin_datos. |
| **Qué se modificó o descartó, y por qué** | 1. **Eliminado `NOCREATEDB`** de `admin_datos` (línea 124 original): PostgreSQL no permite combinar `CREATEDB` y `NOCREATEDB`; el rol no se crecía. Decisión: conservar `CREATEDB` ya es necesario para función administrativa según diseño. <br>2. **Aumentado `CONNECTION LIMIT`** de `app_web` de 10 a 100: valor más adecuado para aplicación web y para evitar agotamiento de pool por bugs/ataques. <br>3. **Mantenido grant de columna `mail, celular`** en `rol_soporte`: la consigna TP lo requiere específicamente como ejercicio de permiso por columna. En producción se debería añadir enmascaramiento/RDS, pero para el TP se acepta tal cual. <br>4. **Añadido `REVOKE DELETE, TRUNCATE`** para `rol_soporte` en `clientes`: por defensa en profundidad, coherente con lo que ya tenía `rol_app_escritura`.
| **Verificación realizada** | Script auditado y probado sobre la copia de trabajo `foodstore_desarrollo` usando el protocolo de 3 pasos de seguridad: <br>1. `createdb -U postgres -T foodstore foodstore_desarrollo` → creado correctamente <br>2. `psql -U postgres -d foodstore_desarrollo` + `SELECT current_database()` → verificó conexión a la copia <br>3. Ejecutado `BEGIN; ... ROLLBLOCK;` con grants de prueba (SELECT, INSERT, UPDATE sobre pedidos/productos; SELECT por columna sobre clientes; EXECUTE procedimientos) → todos los comandos ejecutaron sin error y ROLLBACK deshizó los cambios. <br>No se ejecutó COMMIT para preservar la transacción de prueba. |

---

## Parte B — Contexto adicional

**Project:** Foodstore Database TP2  
**Base de trabajo:** `foodstore_desarrollo` (copia derivada de `foodstore`)  
**Motor:** PostgreSQL 16+ (confirmado: 17.11 en entorno Windows)  
**Usuario base:** `postgres`  

---