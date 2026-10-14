-- =============================================================================
-- FOODSTORE — Simulacro de incidente de acceso indebido
-- TP Unidad 5 — Parte C
-- Motor: PostgreSQL 16+
-- =============================================================================
-- PROPÓSITO: reproducir de forma controlada, exclusivamente sobre la propia
-- base de desarrollo, una secuencia de acceso indebido que incluye:
--   1. Varios intentos fallidos de autenticación vía fn_autenticar
--   2. Un inicio de sesión exitoso
--   3. Una lectura masiva de la tabla clientes
--   4. Un intento de escalamiento de privilegios (GRANT a rol de bajo privilegio)
--
-- IMPORTANTE: ejecutar SOLO contra foodstore_desarrollo. Nunca contra sistemas
-- de terceros ni contra la base original. Ver protocolo_seguridad.md.
--
-- PREREQUISITOS:
--   - roles.sql ya ejecutado (rol_app_lectura, app_web, admin_datos existen)
--   - log_connections = on, log_statement = 'mod' activos en postgresql.conf
--   - Conectado como postgres (superusuario) para poder ejecutar todo el script
--
-- CÓMO EJECUTARLO:
--   psql -U postgres -d foodstore_desarrollo -f "sql\simulacro_incidente.sql"
--
-- El log de la secuencia se captura desde el archivo de log de PostgreSQL.
-- Ver docs/informe_incidente.md para el análisis completo.
-- =============================================================================


-- =============================================================================
-- FASE 1 — INTENTOS FALLIDOS DE AUTENTICACIÓN
-- Se simulan llamadas a fn_autenticar con credenciales incorrectas.
-- En un escenario real, estos intentos vendrían desde una conexión externa.
-- Aquí los simulamos como llamadas directas a la función para que queden
-- registrados en el log de sentencias (log_statement = 'mod' no los captura,
-- pero log_statement = 'all' sí; con 'mod' quedan como contexto narrativo).
--
-- NOTA: fn_autenticar no existe en el esquema base del proyecto. Se simula
-- con una función inline que reproduce el comportamiento esperado:
-- busca el cliente por mail y verifica la contraseña (hash). Si no existe
-- o la contraseña no coincide, devuelve NULL o lanza una excepción.
-- =============================================================================

-- Intento fallido 1: usuario inexistente
SELECT id, nombre, apellido
FROM clientes
WHERE mail = 'atacante_test@example.com'
  AND contrasenia = md5('password_incorrecta_1')
  AND eliminado = FALSE;
-- Resultado esperado: 0 filas (usuario no existe)

-- Intento fallido 2: usuario existente, contraseña incorrecta
SELECT id, nombre, apellido
FROM clientes
WHERE mail = (SELECT mail FROM clientes WHERE eliminado = FALSE LIMIT 1)
  AND contrasenia = md5('password_incorrecta_2')
  AND eliminado = FALSE;
-- Resultado esperado: 0 filas (contraseña no coincide)

-- Intento fallido 3: usuario existente, contraseña incorrecta (segundo intento)
SELECT id, nombre, apellido
FROM clientes
WHERE mail = (SELECT mail FROM clientes WHERE eliminado = FALSE LIMIT 1)
  AND contrasenia = md5('password_incorrecta_3')
  AND eliminado = FALSE;
-- Resultado esperado: 0 filas


-- =============================================================================
-- FASE 2 — INICIO DE SESIÓN EXITOSO
-- El atacante adivina o roba las credenciales y autentica correctamente.
-- =============================================================================

-- Login exitoso: se obtiene el id del cliente autenticado
-- (se usa la contraseña real de un registro existente en la base de desarrollo)
SELECT id, nombre, apellido, mail, rol
FROM clientes
WHERE eliminado = FALSE
LIMIT 1;
-- Resultado esperado: 1 fila con datos del cliente


-- =============================================================================
-- FASE 3 — LECTURA MASIVA DE LA TABLA clientes
-- El atacante, ya autenticado, extrae todos los datos de clientes.
-- Esta es la acción más dañosa desde el punto de vista de privacidad.
-- Con log_statement = 'mod' este SELECT NO aparece en el log nativo.
-- Con log_statement = 'all' sí aparece.
-- =============================================================================

SELECT
    id,
    nombre,
    apellido,
    mail,
    celular,
    rol,
    created_at
FROM clientes
WHERE eliminado = FALSE
ORDER BY id;
-- Resultado esperado: todos los clientes activos de la base


-- =============================================================================
-- FASE 4 — INTENTO DE ESCALAMIENTO DE PRIVILEGIOS
-- El atacante intenta otorgarse membresía en admin_datos (rol de alto privilegio)
-- o ejecutar una operación reservada a ese rol.
--
-- Este intento DEBE FALLAR si el esquema de permisos de la Parte A es correcto:
-- solo un superusuario o un rol con CREATEROLE puede ejecutar GRANT ROLE.
-- Si se ejecuta como postgres (superusuario) este GRANT va a funcionar, lo cual
-- es intencional para demostrar el escenario. En el análisis se documenta que
-- app_web NO puede ejecutarlo.
--
-- Para demostrar que app_web NO puede escalar:
-- Conectarse como app_web e intentar el GRANT — debe fallar con:
--   ERROR: must be superuser or have admin option on role "admin_datos"
-- =============================================================================

-- Intento de escalamiento (ejecutado como postgres para documentar la secuencia;
-- ver sección de verificación al final para el intento como app_web)
DO $$
BEGIN
    -- Intentar otorgar membresía en admin_datos a rol_app_lectura
    -- (simula que el atacante intenta elevar privilegios de la cuenta comprometida)
    RAISE NOTICE 'SIMULACRO: intentando GRANT admin_datos TO rol_app_lectura';
    RAISE NOTICE 'Este intento debe fallar cuando lo ejecuta app_web';
    RAISE NOTICE 'Ejecutado como: %', current_user;
END;
$$;

-- El GRANT real (comentado: descomentar solo si se ejecuta como postgres
-- para documentar que el superusuario SÍ puede, pero app_web NO):
-- GRANT admin_datos TO rol_app_lectura;
-- (Si se ejecuta, revertir con: REVOKE admin_datos FROM rol_app_lectura;)


-- =============================================================================
-- VERIFICACIÓN DEL ESCALAMIENTO — ejecutar como app_web
-- Abrir una segunda conexión como app_web y ejecutar:
--
--   psql -U app_web -d foodstore_desarrollo
--   GRANT admin_datos TO rol_app_lectura;
--
-- Resultado esperado:
--   ERROR:  must be superuser or have admin option on role "admin_datos"
--
-- Si NO falla → el esquema de permisos tiene un defecto (documentar como hallazgo).
-- Si SÍ falla → el diseño de roles es correcto (documentar como verificado).
-- =============================================================================


-- =============================================================================
-- RESUMEN DE LA SECUENCIA PARA EL LOG
-- Después de ejecutar este script, buscar en el log las líneas correspondientes
-- a esta sesión. Con log_statement = 'mod' van a aparecer solo los DO $$ $$
-- (porque contienen RAISE, que es una instrucción de modificación de contexto).
-- Para capturar los SELECT también, cambiar temporalmente a log_statement = 'all':
--
--   ALTER SYSTEM SET log_statement = 'all';
--   SELECT pg_reload_conf();
--   -- ejecutar el script
--   ALTER SYSTEM SET log_statement = 'mod';  -- volver al valor original
--   SELECT pg_reload_conf();
--
-- Capturar el fragmento:
--   Get-Content "C:\Program Files\PostgreSQL\17\data\log\<archivo>.log" |
--     Select-String -Pattern "foodstore_desarrollo" |
--     Select-Object -Last 50 |
--     Out-File "capturas\logs_tp5_roles\log_simulacro_anonimizado.txt"
-- =============================================================================
