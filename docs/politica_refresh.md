# Política de REFRESH para `mv_facturacion_categoria_mes`

## 1. Naturaleza del reporte y tolerancia al desfase

El reporte "Facturación por categoría y mes" agrega ventas históricas agrupadas
por período mensual. Esto tiene una consecuencia clave para decidir la frecuencia
de refresco: **los meses cerrados no cambian**.

Un pedido de octubre de 2025 que ya pasó a estado `TERMINADO` no va a modificar
su `subtotal` ni su mes. El único dato que crece constantemente es el mes en curso:
cada nuevo pedido confirmado o terminado durante el mes activo suma unidades al
agregado de ese mes.

Esto divide el contenido de la vista en dos zonas con necesidades muy distintas:

| Zona | Descripción | ¿Cambia tras el refresco? |
| :--- | :--- | :--- |
| **Meses cerrados** | Todos los meses anteriores al mes en curso | No (dato estable) |
| **Mes en curso** | El mes calendario activo al momento del refresco | Sí, crece con cada pedido nuevo |

---

## 2. Frecuencia de refresco recomendada

### Recomendación principal: una vez al día, al inicio de la jornada

```sql
-- Ejecutar a las 00:05 (o al inicio del día hábil) vía pg_cron o tarea programada
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

**Justificación:**

- El reporte de facturación por categoría y mes es típicamente consultado por
  gerencia, contaduría o el equipo de compras para tomar decisiones de
  reposición, análisis de tendencias o cierre contable. Ninguno de esos usos
  requiere datos del minuto anterior.
- Un desfase de hasta 24 horas en el mes en curso es completamente aceptable:
  si hoy es 15 de noviembre, que el reporte muestre la facturación de noviembre
  hasta ayer a las 00:05 no afecta ninguna decisión operativa urgente.
- Los meses cerrados son exactos en cualquier momento.
- Un refresco diario tiene un costo operativo bajo: el benchmark muestra que la
  consulta base tarda ~1 364 ms sobre 600 000 filas. `REFRESH CONCURRENTLY` agrega
  algo de overhead (comparar snapshot nuevo vs. viejo fila a fila), pero sigue
  siendo del orden de segundos, ejecutable sin impacto perceptible en las 3:00 AM.

### Variante para operaciones de alta frecuencia: cada hora en horario comercial

```sql
-- Cada hora entre las 08:00 y las 22:00 (horario de operación del negocio)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

Aplicar si el negocio tiene un dashboard operativo que el equipo de ventas
consulta durante el día para ver el progreso del mes. En ese caso un desfase
de 1 hora es razonable. Fuera del horario comercial, con un refresco nocturno
alcanza.

### Variante para cierre mensual: refresco manual al confirmar el último pedido del mes

Algunos negocios tienen un proceso de "cierre de mes" donde se confirman o
cancelan pedidos pendientes antes de emitir el informe contable. En ese caso
corresponde un refresco manual explícito tras ese proceso:

```sql
-- Ejecutar después del proceso de cierre de mes
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;

-- Verificar que el mes cerrado tiene los valores definitivos:
SELECT categoria, mes, total_facturado, cantidad_pedidos
FROM mv_facturacion_categoria_mes
WHERE mes = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
ORDER BY total_facturado DESC;
```

---

## 3. Qué implica para los usuarios que el dato no se actualice en tiempo real

### 3.1 El dato que ven es un snapshot, no el estado actual

Cuando un usuario consulta `mv_facturacion_categoria_mes`, está leyendo el
estado de la base **en el momento del último `REFRESH`**, no en el momento
de la consulta. Dicho de otro modo: entre dos refrescos, la vista es
inmutable. Los pedidos confirmados en ese intervalo no aparecen.

**Ejemplo concreto con refresco diario:**

Hoy es 18 de noviembre. El refresco del día corrió a las 00:05 y encontró
$142 000 facturados en la categoría "Bebidas" en noviembre.
A las 11:00, el equipo de ventas cerró 5 pedidos grandes por $8 000 adicionales.
Si alguien consulta la vista a las 14:00, seguirá viendo $142 000 — los $8 000
de esa mañana no estarán hasta mañana a las 00:05.

### 3.2 Consecuencias según el perfil de usuario

| Perfil | Uso del reporte | Impacto del desfase |
| :--- | :--- | :--- |
| **Gerencia / dirección** | Tendencias mensuales, comparativos entre categorías, decisiones estratégicas | **Nulo.** Los meses cerrados son exactos; el mes en curso con ±1 día de desfase no cambia ninguna decisión estratégica. |
| **Contaduría / finanzas** | Cierre contable, conciliación de ingresos | **Bajo, gestionable.** El cierre se hace sobre meses ya cerrados (dato estable). Para el mes en curso, basta un refresco manual antes de emitir el informe. |
| **Compras / reposición** | Ver qué categorías venden más para anticipar stock | **Bajo.** Las decisiones de compra se toman con datos semanales o mensuales, no del minuto. |
| **Equipo de ventas (dashboard diario)** | Seguimiento del progreso del mes actual | **Moderado si el refresco es diario.** Reducir a cada 1-2 horas en horario comercial si este perfil es prioritario. |

### 3.3 Lo que el usuario **no debe hacer** con esta vista

La vista materializada **no es apta** para estos casos de uso:

- **Verificar si un pedido específico fue contabilizado**: para eso se necesita
  la tabla `pedidos` en tiempo real, no el agregado.
- **Calcular el total del día en curso** con exactitud al minuto: la vista
  agrega por mes, y el snapshot puede tener horas de antigüedad.
- **Auditoría financiera en tiempo real**: siempre auditar contra las tablas base
  (`pedidos`, `detalle_pedido`), nunca contra la vista.

### 3.4 Cómo comunicar el desfase en la interfaz

Es buena práctica exponer al usuario cuándo fue el último refresco:

```sql
-- Consultar la última vez que se refrescó la vista:
SELECT schemaname, matviewname, last_refresh
FROM pg_stat_user_tables
WHERE relname = 'mv_facturacion_categoria_mes';

-- Alternativa: guardar la marca de tiempo en una tabla de control:
-- CREATE TABLE IF NOT EXISTS control_refresh (
--     vista        VARCHAR(100) PRIMARY KEY,
--     ultimo_refresh TIMESTAMPTZ NOT NULL DEFAULT NOW()
-- );
-- -- Ejecutar después de cada REFRESH:
-- INSERT INTO control_refresh (vista, ultimo_refresh)
-- VALUES ('mv_facturacion_categoria_mes', NOW())
-- ON CONFLICT (vista) DO UPDATE SET ultimo_refresh = EXCLUDED.ultimo_refresh;
```

Si hay un dashboard, mostrar un texto del tipo:
> "Datos actualizados al: 18/11/2025 00:05 — el mes en curso puede no incluir
> pedidos de las últimas horas."

---

## 4. Resumen de la política

| Escenario | Frecuencia recomendada | Comando |
| :--- | :--- | :--- |
| Uso estándar (gerencia, finanzas) | **1 vez al día** — 00:05 hs | `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;` |
| Dashboard operativo de ventas | **Cada 1 hora** en horario comercial | Ídem, schedulear con pg_cron o tarea de Windows |
| Cierre de mes / informe contable | **Manual**, tras confirmar el último pedido del período | Ídem, ejecutar manualmente y verificar |
| Tras migración o carga masiva de datos | **Inmediato** (refresco completo, sin CONCURRENTLY) | `REFRESH MATERIALIZED VIEW mv_facturacion_categoria_mes;` |

> **Nota sobre CONCURRENTLY vs. refresco completo:**  
> `REFRESH CONCURRENTLY` requiere el índice único y no bloquea lecturas, pero
> es levemente más lento que el refresco completo (tiene que comparar el snapshot
> nuevo contra el viejo). Para ventanas de mantenimiento nocturnas o tras una
> carga masiva, el refresco completo sin `CONCURRENTLY` es preferible porque
> no necesita ese proceso de comparación.

---

## 5. DUIA

| Campo | Detalle |
| :--- | :--- |
| **Herramienta** | Kiro (Claude – Anthropic) |
| **Prompt utilizado** | "Documentar con qué frecuencia debería ejecutarse el REFRESH MATERIALIZED VIEW dado el uso esperado del reporte, y qué implica para los usuarios que el dato no se actualice en cada REFRESH." |
| **Qué generó** | Este documento completo: análisis de zonas estables vs. dinámicas, tabla de frecuencias por escenario, tabla de impacto por perfil de usuario, casos de uso no aptos para la vista, y snippet de control de marca de tiempo. |
| **Qué se aceptó** | Estructura y contenido completo. |
| **Qué se modificó o descartó** | Ninguna modificación. El análisis está fundamentado en la naturaleza del reporte (datos históricos mensuales) y en los resultados del benchmark documentado en `benchmark_resultados.md`. |
| **Verificación realizada** | El análisis es conceptual/documental; no requiere ejecución de SQL. Los tiempos de refresco citados (~1 364 ms) son los medidos en `benchmark_resultados.md`. |
