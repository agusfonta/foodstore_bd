# Requirements — Roles y Permisos de Mínimo Privilegio (Food Store)

## Contexto del sistema

Food Store es una tienda de alimentos con una base de datos PostgreSQL que gestiona
categorías, productos, clientes, pedidos y detalles de pedido. El backend de la
aplicación web accede a la base y existe un rol administrativo para mantenimiento
del esquema. El sistema aplica borrado lógico en todas las tablas principales.

## Principio rector

**Mínimo privilegio**: cada identidad recibe únicamente los privilegios necesarios
para ejecutar su función, y ninguno más. Ningún rol de aplicación ni de
administración del esquema tendrá atributo `SUPERUSER`.

## Requerimientos funcionales

### RF-01 — Separación de credenciales y permisos
Los roles de login (`LOGIN`) deben ser distintos de los roles funcionales
(`NOLOGIN`). Los permisos se otorgan a los roles funcionales; los roles de login
los heredan mediante membresía. Esto permite reasignar permisos sin tocar
credenciales.

### RF-02 — Roles de grupo requeridos

| ID | Nombre | Propósito |
|---|---|---|
| RG-01 | `rol_app_lectura` | Lectura del catálogo de productos y categorías vigentes para visitantes y clientes del sitio. |
| RG-02 | `rol_app_escritura` | Creación y actualización de pedidos durante el flujo de compra. Sin DELETE ni TRUNCATE físico. |
| RG-03 | `rol_soporte` | Consulta de datos identificatorios básicos de clientes (sin contraseña) y resumen de pedidos para atención al cliente. |
| RG-04 | `rol_reportes` | Lectura de vistas analíticas y la vista materializada de facturación para reportes gerenciales. |

### RF-03 — Roles de login requeridos

| ID | Nombre | Propósito |
|---|---|---|
| RL-01 | `app_web` | Conexión del backend de la aplicación web. Combina lectura de catálogo y escritura de pedidos. |
| RL-02 | `admin_datos` | Identidad administrativa para mantenimiento del esquema y gestión de roles. Sin SUPERUSER. |

### RF-04 — Restricciones de seguridad obligatorias
- `app_web` NO puede ejecutar `DELETE` ni `TRUNCATE` sobre ninguna tabla transaccional.
- `app_web` NO puede `GRANT` ni `REVOKE` privilegios a otros roles.
- `admin_datos` puede `CREATEDB` y `CREATEROLE`, pero sin `SUPERUSER`.
- `rol_soporte` NO puede leer la columna `contrasenia` de la tabla `clientes`.
- `rol_reportes` accede únicamente a vistas y a la vista materializada, nunca a las tablas base directamente.

### RF-05 — Permisos a nivel de columna
`rol_soporte` obtiene acceso por columna sobre `clientes`: solo `id`, `nombre`,
`apellido`, `mail`, `celular` y `rol`. La columna `contrasenia` queda excluida
explícitamente.

### RF-06 — Herencia automática de privilegios futuros
Cualquier tabla nueva creada por `admin_datos` en el esquema `public` debe heredar
automáticamente `SELECT` para `rol_reportes`, sin necesidad de ejecutar `GRANT`
manualmente cada vez.

### RF-07 — Autenticación segura
`app_web` debe crearse con método de autenticación `SCRAM-SHA-256` y límite de
conexiones concurrentes (`CONNECTION LIMIT`).

## Requerimientos no funcionales

- **RNF-01**: El script de roles debe ser idempotente: usar `IF NOT EXISTS` donde
  PostgreSQL lo soporte para poder re-ejecutarlo sin errores.
- **RNF-02**: Todos los `GRANT` deben ser explícitos. Evitar `GRANT ALL` salvo
  justificación documentada.
- **RNF-03**: El script debe ejecutarse primero en `foodstore_desarrollo` (copia
  de trabajo), no sobre la base original.
