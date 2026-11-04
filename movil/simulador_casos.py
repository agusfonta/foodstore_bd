#!/usr/bin/env python3
"""Arma la base de la tablet desde cero y corre las pruebas 1.c y los casos C2-C6.

Alternativa en Python para quien no tiene el CLI sqlite3: ejecuta los mismos
scripts .sql de esta carpeta (schema_sqlite.sql, carga_snapshot.sql,
pruebas_sqlite.sql, semaforo.sql) y reemplaza el comando `.import` por el
módulo csv.

Cada caso cambia datos EN POSTGRESQL (la copia foodstore_desarrollo), como pide
la consigna 2.c: abre una transacción, aplica el UPDATE, exporta
v_snapshot_movil desde esa misma transacción a un CSV nuevo, hace ROLLBACK
(protocolo de seguridad: la copia queda como estaba) e importa el CSV en
snapshot_servidor de SQLite. Después corre el semáforo.

Conexión: usuario postgres en localhost:5432, base foodstore_desarrollo; la
contraseña se toma de la variable de entorno PGPASSWORD (nunca va en el código).

Uso:
  python simulador_casos.py                 corre todo en una base temporal (no toca foodstore_movil.db)
  python simulador_casos.py --guardar RUTA  igual, pero deja la base con los resultados en RUTA
  python simulador_casos.py --limpia        reconstruye foodstore_movil.db solo con el esquema y la
                                            instantánea de servidor_snapshot.csv (la que se entrega)
  python simulador_casos.py --emular        sin PostgreSQL: emula el cambio del servidor con un UPDATE
                                            sobre snapshot_servidor (solo para quien no puede conectarse)
"""
import csv
import os
import sqlite3
import sys
import tempfile
from pathlib import Path

try:
    import psycopg2
except ImportError:  # sin driver solo sirve --emular
    psycopg2 = None

AQUI = Path(__file__).resolve().parent
DB_ENTREGA = AQUI / "foodstore_movil.db"
VISTA_SQL = AQUI.parent / "postgres" / "datos" / "vista_snapshot.sql"
PG = {"host": "localhost", "port": 5432, "user": "postgres", "dbname": "foodstore_desarrollo"}
COLUMNAS = ["id", "nombre", "precio_centavos", "stock_visto", "disponible", "eliminado", "fecha_copia"]

# UUID v4 reales (generados con uuid.uuid4()): borrador (B) y solicitud (S) de cada caso.
BASE_S = "f47ac10b-58cc-4372-a567-0e02b2c3d479"   # solicitud de pruebas_sqlite.sql (1.c)
C2_B = "c1abcbf0-16d8-4243-b296-a4b7794e1165"
C2_S1 = "a8b5fbe6-babe-4f12-8903-c859518153c7"
C2_S2 = "4e790513-e286-4303-982b-a1e90d837d35"
C3_B = "b96eceba-0ab5-4e99-bb07-52733dc066ff"
C3_S = "a179e489-0a4a-4ce0-afc1-32a3a46099cf"
C4_B = "79fef315-9adf-4316-9cfd-4b76227ca730"
C4_S = "86f12151-8c0b-48c1-b8d5-3fbe3a2a6248"
C5_B = "cb420e06-9a9a-4ffd-88e3-47b1b08a483e"
C5_S = "38f3809c-6d58-441c-a7b1-a4662b36e54f"

sys.stdout.reconfigure(encoding="utf-8")


def correr_script(con, nombre, verbose=True):
    """Ejecuta un .sql sentencia por sentencia, como el CLI: un error se informa y sigue."""
    buffer = ""
    for linea in (AQUI / nombre).read_text(encoding="utf-8").splitlines():
        if not buffer.strip() and linea.lstrip().startswith("."):
            if linea.startswith(".import"):
                importar_csv(con)
            continue
        buffer += linea + "\n"
        if not sqlite3.complete_statement(buffer):
            continue
        sentencia, buffer = buffer.strip(), ""
        try:
            cur = con.execute(sentencia)
            filas = cur.fetchall()
            if verbose and filas:
                print(" | ".join(d[0] for d in cur.description))
                for fila in filas:
                    print(" | ".join(str(v) for v in fila))
                print()
        except sqlite3.Error as e:
            if verbose:
                print(f"ERROR: {e}\n")


def importar_csv(con, ruta=None):
    """Equivale a: .import --csv --skip 1 <csv> snapshot_servidor"""
    with open(ruta or AQUI / "servidor_snapshot.csv", newline="", encoding="utf-8") as f:
        filas = list(csv.reader(f))[1:]
    con.executemany("INSERT INTO snapshot_servidor VALUES (?,?,?,?,?,?,?)", filas)


def semaforo(con):
    correr_script(con, "semaforo.sql", verbose=False)


def recargar_catalogo(con):
    """Vuelve a cargar producto_cache con el contenido actual de snapshot_servidor."""
    con.executescript(
        """
        INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
        SELECT id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia
        FROM snapshot_servidor WHERE true
        ON CONFLICT(id) DO UPDATE SET precio_centavos = excluded.precio_centavos,
            stock_visto = excluded.stock_visto, disponible = excluded.disponible,
            eliminado = excluded.eliminado, fecha_copia = excluded.fecha_copia;
        """
    )


# ---------------------------------------------------------------- PostgreSQL

def pg_conectar():
    if psycopg2 is None:
        raise SystemExit("Falta psycopg2 (pip install psycopg2-binary). Sin PostgreSQL se puede usar --emular.")
    try:
        return psycopg2.connect(connect_timeout=5, **PG)  # la contraseña sale de PGPASSWORD
    except psycopg2.OperationalError as e:
        raise SystemExit(f"No se pudo conectar a {PG['dbname']}: {e}\nDefiní PGPASSWORD o usá --emular.")


def control_postgres():
    """Última consulta de postgres/datos/vista_snapshot.sql: pedidos, detalles, stock, precios y huella md5."""
    texto = VISTA_SQL.read_text(encoding="utf-8")
    sql = texto[texto.index("SELECT (SELECT COUNT(*) FROM pedidos)"):].strip().rstrip(";")
    pg = pg_conectar()
    try:
        with pg.cursor() as cur:
            cur.execute(sql)
            return tuple(str(v) for v in cur.fetchone())
    finally:
        pg.rollback()
        pg.close()


def exportar_instantanea(cambio_pg, destino_csv):
    """Aplica `cambio_pg` en la copia del servidor dentro de una transacción, exporta
    v_snapshot_movil (la misma transacción ve el cambio) a `destino_csv` y hace ROLLBACK."""
    pg = pg_conectar()
    try:
        with pg.cursor() as cur:
            cur.execute(cambio_pg)
            print(f"  PostgreSQL ({PG['dbname']}): {cambio_pg}  -> {cur.rowcount} fila(s), dentro de BEGIN")
            cur.execute("SELECT * FROM v_snapshot_movil")
            filas = cur.fetchall()
    finally:
        pg.rollback()  # la copia del servidor queda como estaba
        pg.close()
    with open(destino_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(COLUMNAS)
        for fila in filas:
            w.writerow([*fila[:6], fila[6].isoformat(sep=" ")])
    print(f"  Instantánea nueva exportada: {len(filas)} productos (ROLLBACK hecho en PostgreSQL)")


def cambiar_servidor(con, emular, cambio_pg, cambio_sqlite):
    """Cambia datos del servidor y deja la instantánea nueva en snapshot_servidor."""
    if emular:
        con.execute(cambio_sqlite)
        print(f"  (emulado) {cambio_sqlite}")
        return
    ruta = Path(tempfile.mkdtemp()) / "servidor_snapshot_nueva.csv"
    exportar_instantanea(cambio_pg, ruta)
    con.execute("DELETE FROM snapshot_servidor")
    importar_csv(con, ruta)


# ---------------------------------------------------------------- casos

def borrador(con, id_local, solicitud, producto, cantidad, precio, usuario="vendedor01", pago="EFECTIVO"):
    con.execute("INSERT INTO pedido_borrador (id_local, usuario, forma_pago) VALUES (?,?,?)", (id_local, usuario, pago))
    con.execute(
        "INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES (?,?,?,?)",
        (id_local, producto, cantidad, precio),
    )
    con.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES (?,?, 'PENDIENTE')", (solicitud, id_local))


def resultado(con, solicitud):
    estado, motivo = con.execute("SELECT estado, motivo FROM cola_sync WHERE solicitud_uuid = ?", (solicitud,)).fetchone()
    print(f"  {solicitud}: {estado}" + (f"  ({motivo})" if motivo else ""))
    return estado


def titulo(texto):
    print("\n" + "=" * 70 + f"\n{texto}\n" + "=" * 70)


def main(argv):
    emular = "--emular" in argv
    if "--limpia" in argv:
        destino = DB_ENTREGA
    elif "--guardar" in argv:
        destino = Path(argv[argv.index("--guardar") + 1]).resolve()
    else:
        destino = Path(tempfile.mkdtemp()) / "foodstore_movil_casos.db"
    if destino.exists():
        destino.unlink()
    con = sqlite3.connect(destino, isolation_level=None)  # sin transacciones implícitas

    titulo("schema_sqlite.sql + carga_snapshot.sql")
    correr_script(con, "schema_sqlite.sql", verbose=False)
    correr_script(con, "carga_snapshot.sql")
    if "--limpia" in argv:
        con.close()
        print(f"Base limpia armada en {destino}")
        return

    antes = None if emular else control_postgres()

    titulo("pruebas_sqlite.sql (1.c: COMMIT, ROLLBACK, C1, C7)")
    correr_script(con, "pruebas_sqlite.sql")

    titulo("Línea base: la solicitud de 1.c contra la instantánea sin cambios")
    semaforo(con)
    esperado = {BASE_S: "SIMULADO_APROBADO"}
    resultado(con, BASE_S)

    titulo("C2: el precio sube en el servidor -> CONFLICTO; el cliente acepta -> SIMULADO_APROBADO")
    borrador(con, C2_B, C2_S1, producto=1, cantidad=2, precio=12063)
    cambiar_servidor(con, emular, "UPDATE productos SET precio = 140.00 WHERE id = 1",
                     "UPDATE snapshot_servidor SET precio_centavos = 14000 WHERE id = 1")
    semaforo(con)
    esperado[C2_S1] = "CONFLICTO"
    resultado(con, C2_S1)
    con.execute("UPDATE item_borrador SET precio_centavos_visto = 14000 WHERE id_local = ? AND producto_id = 1", (C2_B,))
    con.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES (?, ?, 'PENDIENTE')", (C2_S2, C2_B))
    semaforo(con)
    esperado[C2_S2] = "SIMULADO_APROBADO"
    resultado(con, C2_S2)

    titulo("C3: el stock baja en el servidor y el borrador pide más de lo que queda -> RECHAZADO")
    # El borrador es válido con lo que mostraba la copia local (stock_visto = 61): 50 unidades.
    borrador(con, C3_B, C3_S, producto=2, cantidad=50, precio=39583, usuario="vendedor02", pago="TARJETA")
    cambiar_servidor(con, emular, "UPDATE productos SET stock = 10 WHERE id = 2",
                     "UPDATE snapshot_servidor SET stock_visto = 10 WHERE id = 2")
    semaforo(con)
    esperado[C3_S] = "RECHAZADO"
    resultado(con, C3_S)

    titulo("C4: producto dado de baja (baja lógica) -> RECHAZADO; la fila queda en el cache")
    borrador(con, C4_B, C4_S, producto=3, cantidad=2, precio=3066, usuario="vendedor03", pago="TRANSFERENCIA")
    cambiar_servidor(con, emular, "UPDATE productos SET eliminado = TRUE WHERE id = 3",
                     "UPDATE snapshot_servidor SET eliminado = 1 WHERE id = 3")
    semaforo(con)
    esperado[C4_S] = "RECHAZADO"
    resultado(con, C4_S)
    recargar_catalogo(con)
    catalogo = [r[0] for r in con.execute("SELECT id FROM producto_cache WHERE disponible = 1 AND eliminado = 0 ORDER BY id")]
    fila = con.execute("SELECT id, eliminado FROM producto_cache WHERE id = 3").fetchone()
    print(f"  catálogo disponible tras recargar: ids {catalogo} (el 3 ya no aparece)")
    print(f"  fila del producto 3 en producto_cache: id={fila[0]}, eliminado={fila[1]} (la fila queda)")

    titulo("C5: borrador sin cambios -> SIMULADO_APROBADO")
    borrador(con, C5_B, C5_S, producto=4, cantidad=2, precio=17272, usuario="vendedor04")
    semaforo(con)
    esperado[C5_S] = "SIMULADO_APROBADO"
    resultado(con, C5_S)

    titulo("C6: reenviar la misma solicitud (mismo UUID)")
    try:
        con.execute("INSERT INTO cola_sync (solicitud_uuid, id_local, estado) VALUES (?, ?, 'PENDIENTE')", (C5_S, C5_B))
        print("  ERROR: se permitió un UUID repetido")
    except sqlite3.IntegrityError as e:
        print(f"  UUID repetido rechazado: {e}")
    cambiar_servidor(con, emular, "UPDATE productos SET precio = 9.99 WHERE id = 4",   # el servidor cambia el precio...
                     "UPDATE snapshot_servidor SET precio_centavos = 999 WHERE id = 4")
    semaforo(con)                                                                       # ...y se repite la simulación
    print("  tras repetir la simulación con otro precio en el servidor:")
    resultado(con, C5_S)

    titulo("Resumen")
    ok = True
    for solicitud, estado in esperado.items():
        real = con.execute("SELECT estado FROM cola_sync WHERE solicitud_uuid = ?", (solicitud,)).fetchone()[0]
        ok &= real == estado
        print(f"  {'OK ' if real == estado else 'MAL'} {solicitud}: esperado {estado}, obtenido {real}")
    print("\n  Todos los casos dieron el resultado esperado." if ok else "\n  HAY CASOS CON RESULTADO DISTINTO.")

    evaluaciones = con.execute("SELECT COUNT(*), COUNT(DISTINCT solicitud_uuid) FROM evaluacion_sync").fetchone()
    print(f"  Registro de evaluaciones: {evaluaciones[0]} filas para {evaluaciones[1]} solicitudes "
          f"({'una por solicitud: repetir el semáforo en C6 no agregó ninguna' if evaluaciones[0] == evaluaciones[1] else 'HAY EVALUACIONES REPETIDAS'}).")

    if not emular:
        despues = control_postgres()
        titulo("PostgreSQL no cambió (pedidos, detalles, stock 1-10, suma de precios 1-10, bajas 1-10, huella md5)")
        print(f"  antes:   {' | '.join(antes)}")
        print(f"  después: {' | '.join(despues)}")
        print("  " + ("Sin cambios." if antes == despues else "¡POSTGRESQL CAMBIÓ!"))
    con.close()


if __name__ == "__main__":
    main(sys.argv[1:])
