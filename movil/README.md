# TP8 — Food Store en la feria: la base de la tablet

Base de Datos II · UTN TUP · Equipo: Agustina Fontagnol, Gianella Peña, Martina Suarez.
Regla de oro: **el móvil propone, el servidor dispone.** `SIMULADO_APROBADO` no es una venta.

```
movil/                              (esta carpeta)
├── README.md
├── schema_sqlite.sql         4 tablas STRICT + snapshot_servidor + evaluacion_sync     (1.b)
├── pruebas_sqlite.sql        COMMIT, ROLLBACK, C1, C7, UUID e índice único              (1.c)
├── carga_snapshot.sql        importa el CSV y carga producto_cache                      (2.a)
├── semaforo.sql              rojo / amarillo / verde                                    (2.b)
├── simulador_casos.py        corre C2 a C6 contra PostgreSQL (o --limpia / --emular)     (2.c)
├── servidor_snapshot.csv     instantánea del servidor                                   (2.a)
└── foodstore_movil.db        base de la tablet limpia: esquema + instantánea del CSV
Fuera de esta carpeta:
postgres/datos/vista_snapshot.sql        v_snapshot_movil en PostgreSQL + control de que no cambió  (2.a, 2.c)
specs/movil/                             requirements.md (11 requisitos EARS) · design.md · tasks.md (4.a)
docs/informes/informe_u8_movil.pdf       1.a, 2.c, 3.a, 3.b y 3.c (fuente: informe_u8_movil_fuente.html)
docs/informes/inventario_scripts.md      todos los scripts de la cursada, por unidad                (3.c)
docs/defensa/guion_defensa.md            ensayo de 10 minutos y preguntas probables                 (4.c)
docs/ia/bitacora_u8_movil.md             (4.b)
docs/ia/duia_u8_movil.md                 (4.b)
```

## Requisitos

SQLite 3.37+ (tablas STRICT) y PostgreSQL 16+ con `psql`. Para el paso 4: Python 3.10+ y `pip install psycopg2-binary`. Para instalar el CLI en Windows: `winget install --id SQLite.SQLite` (probado con 3.54.1; abrir una terminal nueva después). El módulo `sqlite3` de Python ya viene incluido, así que el CLI de SQLite es opcional para el paso 4.

## Orden para crear todo desde cero

Todo con datos de prueba y sobre la copia de trabajo, nunca sobre `foodstore`.

**1. Copia, respaldo y vista en PostgreSQL** (PowerShell, desde la raíz del repositorio)

```powershell
createdb -U postgres -T foodstore foodstore_desarrollo
pg_dump -U postgres -d foodstore_desarrollo -F c -b -v -f respaldo_estructura.backup
psql -U postgres -d foodstore_desarrollo -f postgres/datos/vista_snapshot.sql
```

**2. Exportar la instantánea** (regenera `movil/servidor_snapshot.csv`)

```powershell
cd movil
psql -U postgres -d foodstore_desarrollo -c "\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER"
```

**3. Armar la base de la tablet** (desde `movil/`)

```powershell
sqlite3 foodstore_movil.db ".read schema_sqlite.sql"
sqlite3 foodstore_movil.db ".read carga_snapshot.sql"
sqlite3 foodstore_movil.db ".read pruebas_sqlite.sql"
```

**4. Semáforo y casos C2 a C6** (desde `movil/`)

```powershell
$env:PGPASSWORD = '<contraseña de postgres>'   # solo en esta sesión; no se guarda en ningún archivo
python simulador_casos.py
```

Arma una base temporal con los scripts del paso 3 (con el módulo `sqlite3` en lugar del CLI) y corre cada caso. Los cambios del servidor se hacen **en PostgreSQL** (`foodstore_desarrollo`): cada caso abre una transacción, aplica el `UPDATE`, exporta `v_snapshot_movil` a un CSV nuevo, hace `ROLLBACK` e importa ese CSV en `snapshot_servidor`. Al final imprime una tabla con lo esperado y lo obtenido, el registro de evaluaciones y la comparación de PostgreSQL antes y después; no modifica `foodstore_movil.db`. Sin conexión a PostgreSQL, `--emular` reemplaza ese paso por un `UPDATE` sobre `snapshot_servidor` (solo como plan B). Con `--guardar ruta.db` deja la base con los resultados para inspeccionarla. Para correr el semáforo a mano sobre una base ya cargada: `sqlite3 foodstore_movil.db ".read semaforo.sql"`.

Para volver a dejar la base entregada limpia (esquema + instantánea del CSV, sin borradores): `python simulador_casos.py --limpia`.

**5. Comprobar que PostgreSQL no cambió**: el simulador ya corre la última consulta de `postgres/datos/vista_snapshot.sql` antes y después y lo informa; también se puede correr a mano (la tabla antes/después está en el informe).

## Casos

| Caso | Se prepara | Resultado |
| :--- | :--- | :--- |
| C1 | catálogo disponible sin servidor | lista los 10 productos del cache |
| C2 | el servidor sube un precio (`UPDATE` en PostgreSQL); el cliente acepta | CONFLICTO; la solicitud nueva da SIMULADO_APROBADO |
| C3 | borrador de 50 unidades (la tablet ve 61); el servidor baja el stock a 10 | RECHAZADO |
| C4 | el servidor da de baja un producto (`eliminado = TRUE`) | RECHAZADO; el catálogo ya no lo muestra pero la fila queda |
| C5 | borrador sin cambios | SIMULADO_APROBADO |
| C6 | reenviar la misma solicitud (mismo UUID) | error de clave primaria; repetir la simulación no reevalúa |
| C7 | cantidad 0 y producto inexistente | error y ninguna fila nueva |

En la tablet, `cola_sync.solicitud_uuid` e `id_local` son UUID v4 (con `CHECK` de formato), un borrador no puede tener dos solicitudes PENDIENTE a la vez (`ux_cola_sync_una_pendiente`) y cada resolución del semáforo queda en `evaluacion_sync`.
