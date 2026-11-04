# Guion de defensa — TP8 (10 minutos)

Equipo: Agustina Fontagnol, Gianella Peña, Martina Suarez. La consigna 4.c pide tres cosas: el mapa, un caso en vivo y un hallazgo de la IA. Cada integrante tiene que poder responder cualquier parte (la defensa lleva preguntas individuales).

Antes de empezar, con la terminal abierta en `movil` y `PGPASSWORD` cargada en esa sesión:

```powershell
python simulador_casos.py --limpia
sqlite3 foodstore_movil.db ".read pruebas_sqlite.sql"
```

## Reparto del tiempo

| Min | Quién | Qué | Qué se muestra |
| :--- | :--- | :--- | :--- |
| 0:00–0:30 | Agustina | Regla de oro y qué es la entrega | `README.md`: «el móvil propone, el servidor dispone; `SIMULADO_APROBADO` no es una venta» |
| 0:30–3:00 | Gianella | **El mapa** de los tres motores | Tabla 3.a del informe |
| 3:00–7:00 | Martina | **Un caso en vivo**: C3 (el stock baja en el servidor) | Comandos de abajo |
| 7:00–9:30 | Agustina | **Un hallazgo de la IA** | Hallazgo 1 (descartado) o 4 (aceptado) del informe |
| 9:30–10:00 | Todas | Cierre y preguntas | Tabla de hallazgos |

## 1. El mapa (2:30)

- Tres motores: **PostgreSQL** guarda todo (precios, stock, clientes, pedidos) y es la fuente de verdad; **MongoDB** (`foodstore_u7.pedidos`) tiene una copia de los pedidos 1 a 10 para consultar; **SQLite** en la tablet guarda el catálogo (`producto_cache`), los borradores y la cola de solicitudes.
- El flujo es en un solo sentido para los datos: PostgreSQL → MongoDB y PostgreSQL → SQLite. De la tablet al servidor solo viaja una **solicitud con UUID**, que el servidor valida.
- Qué no viaja a la tablet: clientes (contraseña, mail, celular), auditoría, descripción e imagen. Es lo mínimo para vender sin señal.
- Si se restaura un respaldo viejo de PostgreSQL: las tablets bajan una instantánea nueva, reemplazan `producto_cache` y vuelven a correr el semáforo con solicitudes nuevas.

## 2. Caso en vivo: C3 (4:00)

Qué decir: «El vendedor ve 61 unidades del producto 2 en su catálogo local y arma un borrador de 50. Sin señal, la tablet no se entera de que en el servidor el stock bajó a 10».

1. Mostrar el catálogo sin conexión (C1):

   ```powershell
   sqlite3 foodstore_movil.db "SELECT id, nombre, stock_visto FROM producto_cache WHERE id = 2"
   ```

2. Correr el simulador y mostrar la sección C3. Por dentro hace `UPDATE productos SET stock = 10 WHERE id = 2` en `foodstore_desarrollo` dentro de `BEGIN`, exporta `v_snapshot_movil` y hace `ROLLBACK`:

   ```powershell
   python simulador_casos.py --guardar ..\casos.db
   ```

   Resultado esperado: `RECHAZADO (Stock insuficiente en producto 2: pedido=50, stock=10)`.

3. Mostrar que quedó registrado y que PostgreSQL no cambió:

   ```powershell
   sqlite3 ..\casos.db "SELECT estado, motivo, fecha_instantanea FROM evaluacion_sync ORDER BY id"
   ```

   Al final del simulador, la tabla «PostgreSQL no cambió» (pedidos, detalles, stock y huella md5 iguales antes y después).

Si falla la conexión a PostgreSQL: `python simulador_casos.py --emular` da los mismos resultados (emula el cambio sobre `snapshot_servidor`); hay que decir que es el plan B y por qué.

## 3. Un hallazgo de la IA (2:30)

**Elegido: hallazgo 1, descartado** (race condition en `sp_crear_pedido`). Mostrar que se comprobó, no que se aceptó:

- OpenCode dijo que `FOR UPDATE` dentro del loop podía causar una condición de carrera.
- Se probó con dos sesiones de psql sobre el producto 7 (stock 1): la sesión B queda esperando (`wait_event_type = Lock`) y, al hacer COMMIT la A, la B falla con `Stock insuficiente para 7`. Stock final 0 y un solo pedido nuevo.
- Por qué no era un problema: `GROUP BY ... ORDER BY 1` bloquea siempre en el mismo orden, así que no hay deadlock.

Alternativa si preguntan por uno aceptado: **hallazgo 4** (contraseñas en texto plano en datos de prueba de `parcial1_09` y `_10`): reemplazadas por hash falso con formato bcrypt.

## Preguntas probables (y qué contestar)

| Pregunta | Respuesta corta |
| :--- | :--- |
| ¿Por qué `SIMULADO_APROBADO` y no APROBADO? | Porque la tablet no vende: solo el servidor confirma la venta y descuenta stock. Es una predicción con una instantánea que puede quedar vieja. |
| ¿Por qué los cambios de los casos se hacen en PostgreSQL y no en SQLite? | La consigna pide cambiar datos en la copia del servidor y exportar una instantánea nueva. Cada caso lo hace con `UPDATE` dentro de `BEGIN` y termina en `ROLLBACK`, así la copia queda igual. |
| ¿Qué pasa si se manda dos veces la misma solicitud? | El UUID es clave primaria: el segundo INSERT falla. Además el semáforo solo toma las PENDIENTE, y el índice único parcial impide dos PENDIENTE para el mismo borrador. En un sistema real, la protección iría en el servidor (tabla de solicitudes procesadas con el UUID como clave). |
| ¿Para qué sirve `evaluacion_sync`? | `cola_sync` tiene el estado actual; `evaluacion_sync` deja la historia de cada evaluación (qué dijo, por qué y con qué instantánea), que se llena con un trigger. |
| ¿Por qué precios en centavos enteros? | Evita errores de decimales binarios al comparar precios (`12063` contra `14000`). |
| ¿Por qué no se borra el producto dado de baja del cache? | Porque los borradores lo referencian (clave foránea `RESTRICT`); la baja viaja como lápida (`eliminado = 1`) y el catálogo la oculta con el filtro. |
| ¿Qué respaldás de SQLite? | Nada: se recrea con `schema_sqlite.sql` + `carga_snapshot.sql`. Lo único que se pierde son borradores sin sincronizar, por eso se envían al cierre de cada jornada. |
| ¿Qué rechazaste de lo que dijo la IA? | Ver `bitacora_ia.md`: hallazgos 1, 3 y 5 del code review, Redis como cuarto motor, cifrado en reposo y los números inventados del primer borrador. |
