# DUIA — Parte 1: Restricciones de Integridad (Foodstore TP2)

**Proyecto:** Foodstore — PostgreSQL 17.11 (Windows, postgres@localhost:5432, base foodstore)
**Archivo implementado:** restricciones.sql
**Fecha:** 2026-08-28

## Resumen general
- **Herramienta:** OpenCode
- **Modelo:** Nemotron 3 Ultra Free
- Las 3 specs transcriptas textualmente del usuario (ver cada regla).

## Regla 1 — Coherencia del subtotal (detalle_pedido)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo** | Nemotron 3 Ultra Free |
| **Spec/prompt utilizado** | "En detalle_pedido, el valor de subtotal debe ser exactamente igual a cantidad * precio_unitario." |
| **Qué generó la IA** | `ALTER TABLE detalle_pedido ADD CONSTRAINT chk_detalle_subtotal_coherente CHECK (subtotal = cantidad * precio_unitario);` |
| **Qué se aceptó** | CHECK tal cual generado |
| **Qué se modificó o descartó** | Pruebas separadas de restricciones.sql por decisión del usuario para mantener el archivo de implementación separado de las pruebas. |
| **Correcciones hechas manualmente y motivo** | Ninguna sobre la lógica. Se agregó encabezado de "EJECUCIÓN ÚNICA" por indicación del usuario. |
| **Verificación realizada** | Cantidad 3, precio_unitario 150.00, subtotal 450.00 → `INSERT 0 1` (válido). Cantidad 2, precio_unitario 200.00, subtotal 500.00 → `ERROR` por `chk_detalle_subtotal_coherente` (inválido, esperado). |

## Regla 2 — Transiciones de estado (pedidos.estado)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo** | Nemotron 3 Ultra Free |
| **Spec/prompt utilizado** | "En pedidos, las únicas transiciones permitidas son: PENDIENTE → CONFIRMADO o CANCELADO, CONFIRMADO → TERMINADO o CANCELADO, TERMINADO y CANCELADO son estados finales y no pueden modificarse." |
| **Qué generó la IA** | `CREATE OR REPLACE FUNCTION fn_check_transicion_estado() RETURNS trigger ...` + `CREATE TRIGGER trg_pedidos_transicion_estado BEFORE UPDATE OF estado ON pedidos FOR EACH ROW EXECUTE FUNCTION fn_check_transicion_estado();` |
| **Qué se aceptó** | Función y trigger completos, incluyendo decisión aceptada durante la revisión de permitir UPDATE sin cambio real (`IF OLD.estado = NEW.estado THEN RETURN NEW`) incluida por la IA en la implementación. |
| **Qué se modificó o descartó** | Se descartó agregar `DROP TRIGGER IF EXISTS` por decisión del usuario (preferencia por implementación mínima fácil de defender oralmente). |
| **Correcciones hechas manualmente y motivo** | Ninguna. La lógica de estados finales (`RAISE EXCEPTION`) y transiciones válidas fue generada por la IA y aceptada sin modificación manual. |
| **Verificación realizada** | PENDIENTE → CONFIRMADO → `UPDATE 1` (válido). CONFIRMADO → TERMINADO → `UPDATE 1` (válido). TERMINADO → PENDIENTE → `ERROR: Estado TERMINADO es final y no puede modificarse` (inválido, esperado). |

## Regla 3 — Baja lógica de clientes con pedidos activos (clientes.eliminado)

| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode |
| **Modelo** | Nemotron 3 Ultra Free |
| **Spec/prompt utilizado** | "En clientes, no se permite establecer eliminado = TRUE si existe al menos un pedido asociado a ese cliente cuyo estado sea PENDIENTE o CONFIRMADO. Relación: pedidos.cliente_id = clientes.id" |
| **Qué generó la IA** | `CREATE OR REPLACE FUNCTION fn_check_baja_cliente_con_pedidos_activos() RETURNS trigger ... IF EXISTS (SELECT 1 FROM pedidos WHERE cliente_id = OLD.id AND estado IN ('PENDIENTE','CONFIRMADO')) THEN RAISE EXCEPTION ...` + `CREATE TRIGGER trg_clientes_baja_logica BEFORE UPDATE OF eliminado ON clientes FOR EACH ROW EXECUTE FUNCTION fn_check_baja_cliente_con_pedidos_activos();` |
| **Qué se aceptó** | Función con `EXISTS` y trigger `BEFORE UPDATE OF eliminado` tal cual generados |
| **Qué se modificó o descartó** | Se descartó afirmar que PostgreSQL crea automáticamente índice sobre `pedidos.cliente_id` por ser FK, por indicación del usuario. |
| **Correcciones hechas manualmente y motivo** | Ninguna. |
| **Verificación realizada** | Cliente sin pedidos → `UPDATE 1` (válido). Cliente con pedido PENDIENTE → `ERROR` (inválido, esperado). Cliente con pedido CONFIRMADO → `ERROR` (inválido, esperado). Cliente con pedido TERMINADO → `UPDATE 1` (válido). |

## Trazabilidad — Decisiones y correcciones reales del proceso

1. Selección de las 3 reglas finales entre 8 candidatos propuestos por la IA (usuario eligió subtotal, transiciones, baja lógica).
2. Corrección del usuario: no asumir `cliente_id`/`pedido_id`/`producto_id` existentes; crear datos de prueba controlados.
3. Corrección del usuario: separar SQL de implementación (`restricciones.sql`) de SQL de prueba (no incluir pruebas ejecutables en el archivo).
4. Corrección del usuario: no agregar `DROP TRIGGER IF EXISTS` salvo razón concreta (implementación mínima).
5. Corrección del usuario: no atribuir índice automático a FK `pedidos.cliente_id` sin justificación.
6. Decisión aceptada durante revisión: permitir `OLD.estado = NEW.estado` en Regla 2, incluida por la IA en la implementación (no corrección manual posterior).
7. Corrección del usuario: marcar `restricciones.sql` como `EJECUCIÓN ÚNICA` (no idempotente).
8. Verificación real separada en `foodstore_desarrollo` con `BEGIN ... ROLLBACK` antes de `COMMIT` (según `protocolo_seguridad.md`).

## Verificación global

Todos los resultados corresponden a ejecución real en `foodstore_desarrollo` tras aplicar `restricciones.sql` dentro de transacción de prueba. No se inventaron prompts ni resultados adicionales. Casos de prueba creados de forma controlada sin asumir IDs existentes.
