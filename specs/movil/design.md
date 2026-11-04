# Diseño — Base móvil de la tablet (TP8)

## Flujo

```
PostgreSQL (copia foodstore_desarrollo)
   │  v_snapshot_movil ──\copy──► servidor_snapshot.csv
   ▼
SQLite en la tablet (foodstore_movil.db)
   snapshot_servidor ──► producto_cache         (catálogo offline, solo lectura)
   pedido_borrador ◄─ item_borrador             (borradores armados sin señal)
   cola_sync ──trigger──► evaluacion_sync      (solicitudes, resultado del semáforo y su registro)
   semáforo: compara cada solicitud PENDIENTE con snapshot_servidor
```

La tablet nunca escribe en PostgreSQL. El resultado del semáforo es una simulación.

## Tablas (las de la tablet son STRICT, `PRAGMA foreign_keys = ON`)

| Tabla | Clave | Reglas |
| :--- | :--- | :--- |
| `producto_cache` | `id` (viene del servidor) | `precio_centavos >= 0`; `disponible` y `eliminado` solo 0 o 1 |
| `pedido_borrador` | `id_local` (UUID v4, con CHECK de formato) | `forma_pago` EFECTIVO, TARJETA o TRANSFERENCIA |
| `item_borrador` | (`id_local`, `producto_id`) | FK a las dos tablas anteriores; `cantidad > 0` |
| `cola_sync` | `solicitud_uuid` (UUID v4, con CHECK de formato) | `estado` PENDIENTE, CONFLICTO, RECHAZADO o SIMULADO_APROBADO; índice único parcial `ux_cola_sync_una_pendiente` (un borrador, una solicitud PENDIENTE) |
| `snapshot_servidor` | `id` | última instantánea importada del CSV (sin STRICT: se carga con `.import`) |
| `evaluacion_sync` | `id` | una fila por evaluación del semáforo (estado, motivo, `fecha_instantanea`); la llena el trigger `trg_cola_sync_registra_evaluacion` y solo se agrega |

## Semáforo (`movil/semaforo.sql`)

| Color | Estado | Condición |
| :--- | :--- | :--- |
| Rojo | RECHAZADO | algún producto no existe, no está disponible, fue dado de baja o no alcanza el stock |
| Amarillo | CONFLICTO | no hay rojo, pero cambió algún precio |
| Verde | SIMULADO_APROBADO | todo coincide |

Solo se evalúan las solicitudes PENDIENTE, por eso repetir la simulación no cambia nada.

## Decisiones

- **Centavos enteros:** evitan decimales binarios al comparar precios.
- **Cómo se prueban los casos:** cada caso cambia datos en PostgreSQL (`UPDATE` dentro de `BEGIN`), exporta `v_snapshot_movil` de esa transacción y hace `ROLLBACK`; la tablet importa el CSV nuevo. La copia del servidor queda igual.
- **Registro de evaluaciones:** `cola_sync` guarda el estado actual; `evaluacion_sync` guarda la historia (qué dijo el semáforo, por qué y con qué instantánea).
- **UUID como clave de la solicitud:** la tablet lo genera sin red y el servidor lo usa para no procesar dos veces lo mismo.
- **`stock_visto` y `precio_centavos_visto`:** son lo que vio la tablet, no el valor real; el semáforo los compara con una instantánea nueva.
- **Lápidas:** las bajas lógicas viajan con `eliminado = 1` y la fila queda en `producto_cache`; el catálogo las oculta con `eliminado = 0`.
- **Protección real contra duplicados:** iría en el servidor (clave de idempotencia por UUID al confirmar la venta), no en la tablet.
