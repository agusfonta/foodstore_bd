# DUIA — Parte B: Vistas para reportes (Foodstore)

**Proyecto:** Foodstore — PostgreSQL 17 (base de trabajo `foodstore_desarrollo`)
**Archivos:** `db/views.sql` (entregable), `db/vistas_reportes_prompt_opencode.sql`, `db/vistas_reportes_prompt_propio.sql`
**Spec base:** `spec/spec_parteB_kiro.md`
**Verificación:** `docs/bitacora_verificacion_vistas_parteB.md` + `db/verificacion_vistas_parteB.sql`
**Fecha:** 2026-09-23
**Nota:** este archivo nuevo no modifica `docs/duia_uso_de_la_IA_TP3.md` (vacío) ni las DUIA de Parte 1/2.

## Vista 1 — Productos vigentes con categoría

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode (vista completa) + Kiro (especificación punto 1) |
| **Spec o prompt utilizado** | Kiro: `v_productos_vigentes: p.id, p.nombre, p.precio, p.stock, c.nombre como categoria. Solo vigentes con p.eliminado=false y p.deleted_at is null y c.eliminado=false y c.deleted_at is null.` (texto completo en `spec/spec_parteB_kiro.md`) |
| **Qué generó** | OpenCode: `v_productos_vigentes_con_categoria(producto_id, producto_nombre, precio, stock, disponible, categoria_id, categoria_nombre)` con `JOIN categorias` y doble filtro de vigencia |
| **Qué se aceptó** | JOIN, filtros WHERE y lista base de columnas tal cual |
| **Qué se modificó o descartó, y por qué** | Se agregaron `disponible` y `categoria_id` en la versión OpenCode para reportes (no pedidas en el prompt corto de Kiro). No afecta filas, solo columnas expuestas. La versión definitiva `db/views.sql` conserva esas columnas extra |
| **Verificación realizada** | `EXCEPT` en ambas direcciones sobre columnas comunes + conteo. Ver `docs/bitacora_verificacion_vistas_parteB.md` Vista 1. Esperado: 0 filas de diferencia |

## Vista 2 — Pedidos con datos del usuario (criterio de seguridad)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode + Kiro |
| **Spec o prompt utilizado** | Kiro: `v_pedidos_clientes: pe.id, pe.fecha, pe.estado, pe.total, pe.forma_pago, cl.nombre, cl.apellido, cl.mail, cl.celular. Solo vigentes. Por seguridad no mostrar cl.contrasenia nunca.` |
| **Qué generó** | OpenCode: `v_pedidos_con_cliente(pedido_id, fecha, estado, total, forma_pago, cliente_id, cliente_nombre, cliente_apellido, cliente_mail, cliente_celular)` sin `contrasenia`, sin `rol`, sin auditoría |
| **Qué se aceptó** | Exclusión total de `clientes.contrasenia` tal cual. Es la vista que implementa el criterio teórico |
| **Qué se modificó o descartó, y por qué** | Se agregó `cliente_id` en versión OpenCode para trazabilidad de reportes. Se descartó exponer `rol` por ser dato de autorización interna |
| **Verificación realizada** | `EXCEPT` bidireccional + `SELECT contrasenia FROM vista` (debe fallar) + `information_schema.columns WHERE column_name='contrasenia'` (debe dar 0 filas). Patrón `REVOKE ON clientes / GRANT SELECT ON vista TO rol_reportes` documentado en `db/views.sql` |

## Vista 3 — Detalle de pedido con nombre del producto

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode + Kiro |
| **Spec o prompt utilizado** | Kiro: `v_detalle_pedido: dp.pedido_id, dp.producto_id, pr.nombre como producto, dp.cantidad, dp.precio_unitario, dp.subtotal. Filtrar productos vigentes igual que en 1.` |
| **Qué generó** | OpenCode: `v_detalle_pedido_con_producto(pedido_id, detalle_id, producto_id, producto_nombre, cantidad, precio_unitario, subtotal)` con vigencia solo sobre `productos` |
| **Qué se aceptó** | JOIN y filtro (detalle es histórico, sin `eliminado`/`deleted_at`) tal cual, con comentario de histórico completo |
| **Qué se modificó o descartó, y por qué** | Se agregó `detalle_id (dp.id)` en versión OpenCode para identificar la línea. Sin impacto en filas |
| **Verificación realizada** | `EXCEPT` bidireccional sobre columnas comunes + conteo. Ver bitácora Vista 3. Esperado: 0 filas de diferencia |
