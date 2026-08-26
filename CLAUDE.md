# Foodstore Database TP2 - Instrucciones para Agentes

## Contexto del Proyecto
Este repositorio contiene un esquema de PostgreSQL para una tienda de alimentos (`foodstore`) en `Script.sql` y las consignas del Trabajo Práctico 2 sobre integridad, transacciones y concurrencia.

## Reglas Críticas (No negociables por la cátedra)

### 1. Protocolo de Seguridad de 3 Pasos
Antes de ejecutar cualquier script o comando que afecte a la base de datos (propio o sugerido por la IA), debes documentar e implementar estos tres pasos en `protocolo_seguridad.md`:
*   **Copia de Trabajo:** Nunca operar directamente sobre la base de datos original. Trabajar siempre sobre una copia local creada con:
    ```powershell
    createdb -T foodstore foodstore_desarrollo
    ```
*   **Transacciones Obligatorias:** Todo script que escriba datos debe correrse primero dentro de un bloque de transacción para inspeccionar el impacto antes de confirmar:
    ```sql
    BEGIN;
    -- [operaciones]
    ROLLBACK; -- (Revisar cantidad de filas y mensajes de error, confirmar SOLO si es correcto)
    ```
*   **Respaldo Estructural:** Ejecutar `pg_dump` de la base de datos de trabajo antes de aplicar cualquier instrucción DDL (`ALTER`, `DROP`, migración):
    ```powershell
    pg_dump -U postgres -d foodstore_desarrollo -F c -b -v -f respaldo_estructura.backup
    ```

### 2. Flujo de Trabajo Obligatorio para Restricciones (Parte 1)
1.  **Redactar la Spec primero:** Escribir una descripción breve de la regla (indicando la tabla y la columna exacta) antes de generar código SQL.
2.  **Modo Plan:** Generar los scripts SQL siempre con OpenCode en modo Plan/explicación y leer el diff línea por línea antes de aplicarlo.
3.  **Transacción de verificación:** Probar en la copia local mediante un `BEGIN; ...; ROLLBACK;` con inserts válidos e inválidos.
4.  **Commit descriptivo:** Commitear con un mensaje de commit que explique explícitamente qué regla de negocio garantiza (evitar mensajes vagos como "agrego constraint").
5.  **Declarar DUIA:** Completar la Declaración de Uso de IA (DUIA) usando la plantilla definida.

### 3. Plantilla DUIA Obligatoria
Cada parte completada con IA debe incluir o acompañar una DUIA con la siguiente tabla:
| Campo | Completar |
| :--- | :--- |
| **Herramienta** | OpenCode (modelo/proveedor configurado) |
| **Spec o prompt utilizado** | Texto exacto de la consigna dada a la IA |
| **Qué generó** | Resumen de los archivos y líneas que propuso |
| **Qué se aceptó** | Qué quedó tal cual lo generó la IA |
| **Qué se modificó o descartó, y por qué** | Cualquier corrección hecha a mano, con la razón |
| **Verificación realizada** | Los INSERT o comandos de prueba y su resultado |

## Entregables Clave (Ubicación y Nombre Exactos en la Raíz)

*   **`protocolo_seguridad.md`**: Detalla los comandos reales de copia, transacción y respaldo para el entorno PostgreSQL local sobre Windows (PowerShell 5.1).
*   **Script de Restricciones + DUIA**: Archivo SQL con las 2 o 3 restricciones de integridad/triggers elegidas de las tablas `pedidos`, `productos` o `detalle_pedido` (p. ej., control de transiciones de estado, totales calculados o precios/stock coherentes), acompañados por la DUIA correspondiente.
*   **`informe_concurrencia.md`**: Documentación de 3 anomalías concurrentes reproducidas con dos sesiones de psql o DBeaver en paralelo (Lectura no repetible, Lectura fantasma y Espera por bloqueo), adjuntando explicaciones de la IA, verificación y DUIA.
*   **`ejercicio_lectura_critica.md`**: Análisis de vulnerabilidad/error para los dos scripts ficticios de la consigna (Script 1 actualiza todo por falta de `WHERE`; Script 2 falla al usar `NOT IN` con subconsultas que retornan `NULL`) y sus versiones corregidas.

## Comandos y Entorno
*   **SO / Shell**: Windows 10/11 con PowerShell 5.1.
*   **Acceso a DB**: `psql -U postgres` o cliente gráfico similar. Usa el puerto por defecto (5432).
