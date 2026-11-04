-- =============================================================================
-- FOODSTORE — Anonimización de clientes: tabla clientes_anon
-- TP Unidad 5 — Parte D
-- Motor: PostgreSQL 16+
-- =============================================================================
-- PROPÓSITO: crear una versión anonimizada de la tabla clientes con datos
-- sintéticos deterministas, para poder trabajar con la estructura y los
-- agregados sin exponer datos personales reales a herramientas externas
-- (asistentes de IA, reportes, entornos de prueba).
--
-- CRITERIO DE ANONIMIZACIÓN (mismo que Clase 2):
--   - Datos sintéticos DETERMINISTAS: el mismo id siempre produce el mismo
--     valor sintético. Esto mantiene coherencia interna del dataset.
--   - Se preservan: id, rol, eliminado, created_at (mes/año), updated_at,
--     deleted_at — necesarios para que los agregados sean equivalentes.
--   - Se reemplazan: nombre, apellido, mail, celular, contrasenia
--     por valores generados a partir del id (sin datos reales).
--
-- PROTOCOLO DE SEGURIDAD: ejecutar solo sobre foodstore_desarrollo.
-- =============================================================================

-- =============================================================================
-- PASO 1 — Eliminar tabla anterior si existe (idempotente)
-- =============================================================================
DROP TABLE IF EXISTS clientes_anon;

-- =============================================================================
-- PASO 2 — Crear la tabla anonimizada con datos sintéticos deterministas
-- =============================================================================
CREATE TABLE clientes_anon AS
SELECT
    id,
    -- Nombre sintético: 'Cliente' + id (determinista)
    ('Cliente' || id::TEXT)                         AS nombre,
    -- Apellido sintético: 'Apellido' + id (determinista)
    ('Apellido' || id::TEXT)                        AS apellido,
    -- Mail sintético: patrón único basado en id (determinista, formato válido)
    ('cliente_' || id::TEXT || '@anon.example.com') AS mail,
    -- Celular sintético: patrón numérico basado en id (determinista)
    ('54 11 ' || LPAD(id::TEXT, 7, '0'))            AS celular,
    -- Contraseña: hash fijo de texto constante (no es la contraseña real)
    md5('contrasenia_anonimizada')                  AS contrasenia,
    -- Rol: se conserva tal cual (no es un dato personal identificatorio)
    rol,
    -- Eliminado: se conserva para que los filtros de vigencia sean equivalentes
    eliminado,
    -- created_at: se conserva el mes y año pero se normaliza al día 1
    -- para preservar la granularidad temporal de los agregados sin exponer
    -- la fecha exacta de alta del cliente
    DATE_TRUNC('month', created_at)::TIMESTAMPTZ    AS created_at,
    -- updated_at y deleted_at: se preservan truncados al mes
    DATE_TRUNC('month', updated_at)::TIMESTAMPTZ    AS updated_at,
    DATE_TRUNC('month', deleted_at)::TIMESTAMPTZ    AS deleted_at
FROM clientes;

-- =============================================================================
-- PASO 3 — Índice para que las consultas de agregación sean eficientes
-- =============================================================================
CREATE INDEX idx_clientes_anon_rol       ON clientes_anon (rol);
CREATE INDEX idx_clientes_anon_created   ON clientes_anon (created_at);
CREATE INDEX idx_clientes_anon_eliminado ON clientes_anon (eliminado);

-- =============================================================================
-- PASO 4 — Verificación rápida: conteo debe coincidir con tabla original
-- =============================================================================
SELECT
    (SELECT COUNT(*) FROM clientes)      AS total_original,
    (SELECT COUNT(*) FROM clientes_anon) AS total_anonimizado,
    (SELECT COUNT(*) FROM clientes)
        = (SELECT COUNT(*) FROM clientes_anon) AS conteos_iguales;
-- Resultado esperado: conteos_iguales = true

-- =============================================================================
-- PASO 5 — Verificar que no hay datos reales en la tabla anonimizada
-- =============================================================================
-- Comprobar que ningún mail de clientes_anon coincide con clientes real:
SELECT COUNT(*) AS coincidencias_mail_real
FROM clientes_anon ca
JOIN clientes c ON c.mail = ca.mail;
-- Resultado esperado: 0

-- =============================================================================
-- CONSULTAS DE VERIFICACIÓN DE EQUIVALENCIA
-- (Ver también docs/verificacion_equivalencia.md)
-- =============================================================================

-- Consulta A — sobre clientes_anon: cantidad de clientes activos por rol y mes de alta
SELECT
    rol,
    DATE_TRUNC('month', created_at) AS mes_alta,
    COUNT(*)                        AS cantidad_clientes
FROM clientes_anon
WHERE eliminado = FALSE
GROUP BY rol, DATE_TRUNC('month', created_at)
ORDER BY rol, mes_alta;

-- Consulta B — equivalente sobre clientes real (misma lógica, mismos resultados esperados)
SELECT
    rol,
    DATE_TRUNC('month', created_at) AS mes_alta,
    COUNT(*)                        AS cantidad_clientes
FROM clientes
WHERE eliminado = FALSE
GROUP BY rol, DATE_TRUNC('month', created_at)
ORDER BY rol, mes_alta;

-- Verificación directa de equivalencia (debe devolver 0 filas si son iguales):
SELECT
    COALESCE(a.rol, b.rol)          AS rol,
    COALESCE(a.mes_alta, b.mes_alta) AS mes_alta,
    a.cantidad_clientes             AS cant_anon,
    b.cantidad_clientes             AS cant_real
FROM (
    SELECT rol,
           DATE_TRUNC('month', created_at) AS mes_alta,
           COUNT(*) AS cantidad_clientes
    FROM clientes_anon
    WHERE eliminado = FALSE
    GROUP BY rol, DATE_TRUNC('month', created_at)
) a
FULL OUTER JOIN (
    SELECT rol,
           DATE_TRUNC('month', created_at) AS mes_alta,
           COUNT(*) AS cantidad_clientes
    FROM clientes
    WHERE eliminado = FALSE
    GROUP BY rol, DATE_TRUNC('month', created_at)
) b ON a.rol = b.rol AND a.mes_alta = b.mes_alta
WHERE a.cantidad_clientes IS DISTINCT FROM b.cantidad_clientes;
-- Resultado esperado: 0 filas (los agregados son idénticos)
