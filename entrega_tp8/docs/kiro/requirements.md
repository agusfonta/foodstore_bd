# Requisitos — Base móvil de la tablet (TP8)

Regla de oro: **el móvil propone, el servidor dispone.** La tablet solo consulta y arma borradores; precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` no es una venta.

Notación EARS. Cada requisito indica el caso o la prueba que lo comprueba (ver `informe.pdf`, consigna 2.c, y `movil/pruebas_sqlite.sql`). REQ-01 a REQ-04 son los cuatro que pide la consigna y se ligan a C2, C3, C4 y C6; REQ-05 a REQ-10 cubren el resto de las reglas del diseño.

## Semáforo y sincronización

**REQ-01** WHEN el precio actual del servidor es distinto del precio visto en el borrador y ningún ítem tiene un problema rojo
THE SYSTEM SHALL marcar la solicitud como CONFLICTO y guardar el motivo.
Se prueba con: **C2** (y, al aceptar el cliente el precio nuevo, una solicitud nueva da SIMULADO_APROBADO).

**REQ-02** IF algún ítem del borrador pide más unidades que el stock de la instantánea nueva (porque el stock bajó en el servidor)
THEN THE SYSTEM SHALL marcar la solicitud como RECHAZADO y guardar el motivo.
Se prueba con: **C3**.

**REQ-03** WHEN el servidor da de baja (baja lógica) un producto que está en un borrador
THE SYSTEM SHALL marcar la solicitud como RECHAZADO y, al recargar el catálogo, dejar de mostrar el producto conservando su fila en `producto_cache`.
Se prueba con: **C4**.

**REQ-04** WHEN llega una solicitud con un `solicitud_uuid` ya registrado
THE SYSTEM SHALL rechazarla por clave primaria y no reevaluar ninguna solicitud que no esté PENDIENTE.
Se prueba con: **C6**.

**REQ-05** WHEN todos los ítems de un borrador coinciden con la instantánea (existen, están disponibles, no están dados de baja, alcanza el stock y el precio es el mismo)
THE SYSTEM SHALL marcar la solicitud como SIMULADO_APROBADO sin confirmar ninguna venta ni modificar precio o stock.
Se prueba con: **C5** y la línea base de `pruebas_sqlite.sql`.

**REQ-06** WHEN el semáforo resuelve una solicitud PENDIENTE
THE SYSTEM SHALL agregar una fila a `evaluacion_sync` con el estado, el motivo y la `fecha_copia` de la instantánea usada, y no agregar ninguna al repetir el semáforo sobre una solicitud ya resuelta.
Se prueba con: el resumen de `simulador_casos.py` (6 evaluaciones para 6 solicitudes, aun después de repetir el semáforo en C6).

## Integridad de la base local

**REQ-07** IF un borrador intenta guardarse con una cantidad menor o igual a 0 o con un producto que no está en `producto_cache`
THEN THE SYSTEM SHALL rechazar la operación con error de CHECK o de clave foránea y no dejar filas nuevas.
Se prueba con: **C7**.

**REQ-08** IF un `id_local` o un `solicitud_uuid` no tiene formato de UUID v4
THEN THE SYSTEM SHALL rechazar el INSERT con error de CHECK.
Se prueba con: sección «Extra» de `movil/pruebas_sqlite.sql`.

**REQ-09** IF un borrador que ya tiene una solicitud PENDIENTE recibe otra solicitud PENDIENTE
THEN THE SYSTEM SHALL rechazarla con el índice único parcial `ux_cola_sync_una_pendiente`, y aceptar una solicitud nueva solo cuando la anterior ya se resolvió.
Se prueba con: sección «Extra» de `movil/pruebas_sqlite.sql` (rechazo) y **C2** (segunda solicitud tras el CONFLICTO).

## Disponibilidad sin señal y no escritura en el servidor

**REQ-10** WHILE la tablet no tiene conexión con el servidor
THE SYSTEM SHALL listar el catálogo disponible desde `producto_cache` y permitir armar borradores y solicitudes con `BEGIN … COMMIT` o `ROLLBACK`.
Se prueba con: **C1** y la prueba de COMMIT/ROLLBACK de `movil/pruebas_sqlite.sql`.

**REQ-11** THE SYSTEM SHALL no modificar PostgreSQL (pedidos, detalles, stock ni precios) en ningún paso de la simulación.
Se prueba con: la consulta de control antes y después de `simulador_casos.py` (los cambios de cada caso se hacen dentro de `BEGIN` y terminan en `ROLLBACK`).

## Trazabilidad

| Caso o prueba | Requisitos |
| :--- | :--- |
| C1 | REQ-10 |
| C2 | REQ-01, REQ-09 |
| C3 | REQ-02 |
| C4 | REQ-03 |
| C5 | REQ-05 |
| C6 | REQ-04, REQ-06 |
| C7 | REQ-07 |
| `pruebas_sqlite.sql` «Extra» | REQ-08, REQ-09 |
| Control de PostgreSQL | REQ-11 |
