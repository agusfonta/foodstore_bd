# Spec Parte B — Prompt Kiro para vistas de reportes (transcripción exacta)

> Este archivo guarda la especificación pedida en el punto 1 de la consigna 4.2
> Parte B. No modifica ningún archivo previo. Complementa `spec/spec_tp3.md`
> (que solo contenía Punto 2 y 3) y `docs/informe_mediciones.md`.

## Prompt Kiro utilizado (texto exacto)

```text
Kiro, para la bd foodstore necesito 3 vistas para los reportes:

1. v_productos_vigentes: p.id, p.nombre, p.precio, p.stock, c.nombre como categoria. Solo vigentes con p.eliminado=false y p.deleted_at is null y c.eliminado=false y c.deleted_at is null.
2. v_pedidos_clientes: pe.id, pe.fecha, pe.estado, pe.total, pe.forma_pago, cl.nombre, cl.apellido, cl.mail, cl.celular. Solo vigentes (pe.eliminado=false y deleted_at null, igual para clientes). Por seguridad no mostrar cl.contrasenia nunca.
3. v_detalle_pedido: dp.pedido_id, dp.producto_id, pr.nombre como producto, dp.cantidad, dp.precio_unitario, dp.subtotal. Filtrar productos vigentes igual que en 1.

Generame el SQL con CREATE VIEW.
```

## Por qué este prompt cumple la consigna

| Requisito consigna | Dónde está en el prompt |
|---|---|
| Tres vistas: productos vigentes con categoría | Punto 1: `productos JOIN categorias` |
| Pedidos con datos del usuario | Punto 2: `pedidos JOIN clientes` |
| Detalle de un pedido con nombre del producto | Punto 3: `detalle_pedido JOIN productos` |
| Columnas a exponer con precisión | Listadas una por una en cada punto |
| Filtro de vigencia | `eliminado=false AND deleted_at IS NULL` en ambas tablas del JOIN (doble borrado lógico de `db/schema.sql`) |
| Columna a ocultar por seguridad | Punto 2: `no mostrar cl.contrasenia nunca` (criterio teórico: vista sin contraseña) |

## Trazabilidad

- Salida de Kiro con este prompt: `db/vistas_reportes_prompt_propio.sql` (versión estudiante/manual, nombres cortos).
- Salida de OpenCode con la especificación extendida: `db/vistas_reportes_prompt_opencode.sql` (nombres descriptivos + columnas extra `disponible, categoria_id, cliente_id, detalle_id`).
- Vistas definitivas validadas (entregable): `db/views.sql`.
- Verificación de equivalencia: `docs/bitacora_verificacion_vistas_parteB.md` + script `db/verificacion_vistas_parteB.sql`.
