# Design — Roles y Permisos de Mínimo Privilegio (Food Store)

## Objetos del esquema afectados

Extraídos del DDL del proyecto (`parcial1_01_ddl_schema.sql`,
`parcial1_06_vistas.sql`, `parcial1_07_vista_materializada.sql`,
`parcial1_08_funciones_procedimientos_plpgsql.sql`):

**Tablas:** `categorias`, `productos`, `clientes`, `pedidos`, `detalle_pedido`

**Vistas:**
- `v_productos_vigentes_con_categoria`
- `v_pedidos_con_cliente`
- `v_detalle_pedido_con_producto`

**Vista materializada:** `mv_facturacion_categoria_mes`

**Procedimientos almacenados:** `sp_crear_pedido`, `sp_cambiar_estado_pedido`,
`sp_baja_logica_producto`, `sp_baja_logica_cliente`,
`sp_refrescar_facturacion_categoria_mes`

**Funciones:** `fn_total_pedido`, `fn_pedidos_cliente`,
`fn_ranking_productos_categoria`

---

## Jerarquía de roles

```
admin_datos (LOGIN, CREATEDB, CREATEROLE)
    └── gestiona los roles de grupo y los objetos del esquema

app_web (LOGIN, CONNECTION LIMIT 10)
    ├── MEMBER OF rol_app_lectura
    └── MEMBER OF rol_app_escritura

rol_app_lectura  (NOLOGIN)
rol_app_escritura (NOLOGIN)
rol_soporte      (NOLOGIN)
rol_reportes     (NOLOGIN)
```

---

## Diseño detallado de permisos

### 1. Acceso al esquema (prerequisito para cualquier operación)

```sql
GRANT USAGE ON SCHEMA public TO
    rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;
```

Justificación: sin `USAGE` sobre el esquema ningún rol puede resolver nombres de
objetos, aunque tenga `SELECT` sobre ellos.

---

### 2. `rol_app_lectura`

Propósito: mostrar el catálogo al visitante o cliente autenticado.

| Objeto | Privilegio | Justificación |
|--------|-----------|---------------|
| `v_productos_vigentes_con_categoria` | `SELECT` | Vista que filtra productos y categorías activas; expone solo lo necesario para el catálogo. |
| `v_pedidos_con_cliente` | `SELECT` | Permite que el cliente web consulte sus propios pedidos a través de la aplicación. |

No se otorga `SELECT` directo sobre `productos`, `categorias` ni `clientes`: la
vista actúa como capa de seguridad.

---

### 3. `rol_app_escritura`

Propósito: flujo de compra operativo (crear y actualizar pedidos).

| Objeto | Privilegio | Justificación |
|--------|-----------|---------------|
| `pedidos` | `SELECT, INSERT, UPDATE` | Necesario para crear el pedido y cambiar su estado. |
| `detalle_pedido` | `SELECT, INSERT, UPDATE` | Necesario para agregar renglones al pedido. |
| `productos` | `SELECT, UPDATE (stock)` | `sp_crear_pedido` descuenta stock; solo necesita leer y actualizar esa columna. |
| `clientes` | `SELECT (id, eliminado)` | `sp_crear_pedido` valida existencia del cliente. |
| `sp_crear_pedido` | `EXECUTE` | Procedimiento principal del flujo de compra. |
| `sp_cambiar_estado_pedido` | `EXECUTE` | Permite confirmar, terminar o cancelar un pedido desde la app. |

`DELETE` y `TRUNCATE` sobre `pedidos` y `detalle_pedido` se revocan explícitamente:
el sistema usa borrado lógico; el borrado físico es una operación administrativa.

---

### 4. `rol_soporte`

Propósito: atención al cliente puede consultar datos del cliente y su historial.

| Objeto | Privilegio | Justificación |
|--------|-----------|---------------|
| `clientes (id, nombre, apellido, mail, celular, rol)` | `SELECT` (columnas específicas) | Información identificatoria básica para atender al cliente. `contrasenia` excluida. |
| `v_pedidos_con_cliente` | `SELECT` | Vista que expone pedidos sin datos sensibles de clientes; permite ver el historial. |
| `v_detalle_pedido_con_producto` | `SELECT` | Permite ver el detalle de cada pedido para asistir en consultas. |

Permiso por columna en lugar de vista adicional: PostgreSQL soporta `GRANT SELECT
(col1, col2, ...) ON tabla TO rol`, lo que evita crear una vista extra solo para
soporte y mantiene el diseño más simple.

---

### 5. `rol_reportes`

Propósito: lectura analítica para reportes gerenciales, sin acceso a datos
operativos ni personales identificables.

| Objeto | Privilegio | Justificación |
|--------|-----------|---------------|
| `mv_facturacion_categoria_mes` | `SELECT` | Vista materializada de facturación por categoría y mes: reporte ejecutivo principal. |
| `v_productos_vigentes_con_categoria` | `SELECT` | Permite reportes de catálogo vigente. |
| `v_detalle_pedido_con_producto` | `SELECT` | Permite análisis de líneas de pedido sin datos personales. |
| `fn_ranking_productos_categoria` | `EXECUTE` | Función de ranking de productos: uso analítico. |

No se otorga `SELECT` directo sobre `clientes`, `pedidos` ni tablas base.

---

### 6. `app_web` (rol de login)

```sql
CREATE ROLE app_web WITH
    LOGIN
    PASSWORD '...'   -- SCRAM-SHA-256 en pg_hba.conf
    CONNECTION LIMIT 10
    NOCREATEDB NOCREATEROLE NOSUPERUSER;

GRANT rol_app_lectura  TO app_web;
GRANT rol_app_escritura TO app_web;
```

---

### 7. `admin_datos` (rol de login)

```sql
CREATE ROLE admin_datos WITH
    LOGIN
    PASSWORD '...'
    CREATEDB
    CREATEROLE
    NOCREATEDB -- (se activa solo si se necesita crear bases adicionales)
    NOSUPERUSER;
```

`admin_datos` no recibe membresía en roles de aplicación: su función es
administrar el esquema, no operar la aplicación.

---

### 8. `ALTER DEFAULT PRIVILEGES`

Para que cualquier tabla futura creada por `admin_datos` en `public` sea
automáticamente legible por `rol_reportes`:

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_reportes;
```

---

## Decisiones de diseño y alternativas descartadas

| Decisión | Alternativa descartada | Razón |
|----------|------------------------|-------|
| Permiso de columna sobre `clientes` para `rol_soporte` | Vista `v_clientes_soporte` | El permiso por columna es más directo y evita proliferación de vistas. La vista ya existe (`v_pedidos_con_cliente`) para el historial. |
| `rol_reportes` accede solo a vistas y función analítica | `SELECT` directo sobre tablas | Las vistas actúan como capa de seguridad: no exponen `contrasenia` ni columnas internas. |
| `app_web` sin `DELETE`/`TRUNCATE` | Confiar en la lógica de la app | El motor como última línea de defensa: aunque la app tenga un bug, el rol no puede ejecutar borrado físico. |
| `admin_datos` sin `SUPERUSER` | `SUPERUSER` para simplicidad | `SUPERUSER` saltea todas las comprobaciones de permisos; viola el principio de mínimo privilegio. |
