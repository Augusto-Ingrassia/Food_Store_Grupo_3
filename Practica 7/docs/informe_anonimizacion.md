# Parte D — Anonimización y verificación de equivalencia

Archivos de esta parte:

| Archivo | Contenido |
|---|---|
| `sql/parteD_usuario_anon.sql` | Creación / actualización de `usuario_anon` (punto 1) |
| `sql/parteD_consultas_equivalencia.sql` | Las dos consultas (punto 2) y la verificación (punto 3) |
| `docs/resultado_parteD.txt` | Salida completa de `psql` al ejecutar las consultas |

## 1. Construcción de `usuario_anon` (punto 1)

`usuario_anon` no existía en el repositorio, así que se construyó desde cero siguiendo el patrón de clase: **datos sintéticos deterministas**, calculados solo a partir del `id` y sin `random()`. Es el mismo criterio que ya usamos para anonimizar el log de la Parte C (`usuario_3@ejemplo.com`).

| Columna de `usuario` | En `usuario_anon` | Técnica |
|---|---|---|
| `id` | se conserva | seudónimo técnico; permite cruzar con `pedido` |
| `nombre` | `Usuario_<id>` | sustitución determinista |
| `apellido` | `Anon_<id>` | sustitución determinista |
| `mail` | `usuario_<id>@ejemplo.com` | sustitución determinista (sigue siendo único) |
| `celular` | `000-<id en 7 dígitos>`, o `NULL` si era `NULL` | sustitución determinista |
| `contrasena` | **no se copia** | supresión: no tiene ningún uso analítico |
| `rol` | se conserva | dato de negocio, necesario para el análisis |
| `eliminado` | se conserva | necesario para respetar el soft-delete |
| `created_at` | `mes_alta` (día 1 del mes) | generalización: se pierden día y hora exactos |

Decisiones que vale la pena justificar:

- **Lo que se conserva es justo lo que la agregación necesita** (`rol`, `eliminado`, mes de alta). Todo lo que identifica a una persona se reemplaza o se elimina. Por eso los conteos pueden coincidir.
- **Zona horaria fija** (`America/Argentina/Buenos_Aires`). Si no se fija, el mes depende del `TimeZone` de la sesión: un alta del 31/10 a las 22 h en Argentina ya es 01/11 en UTC. Se comprobó corriendo el script con `PGTZ=UTC` y con la zona del servidor: el `md5` de la tabla completa dio igual en los dos casos (`f1887ed9…`).
- **Idempotente.** `usuario_anon` se regenera completa desde `usuario` (`DROP` + `CREATE` + `INSERT ... SELECT` dentro de una transacción). Correrlo dos veces da exactamente la misma tabla.
- **Controles dentro del script.** Antes del `COMMIT`, un bloque `DO` verifica que la cantidad de filas sea igual a la de `usuario` y que **ningún mail, celular ni nombre + apellido real** aparezca en la copia. Si algo falla, la transacción se revierte.
- **Permisos.** `REVOKE ALL ... FROM PUBLIC` y `GRANT SELECT` solo a `rol_reportes`. Es el rol que en la Parte C pudo leer `usuario` completa, contraseñas incluidas, y `usuario_anon` es su alternativa segura. Además se revoca explícitamente a `rol_app_lectura`: el `ALTER DEFAULT PRIVILEGES` de `roles.sql` le daría `SELECT` si la tabla la creara `admin_datos`.
- **Límite conocido.** Conservar el `id` hace que esto sea, en rigor, una *seudonimización*: quien tenga acceso a `usuario` puede revertirla. Por eso `usuario_anon` sigue siendo un objeto con acceso restringido y no un dato público.

Salida de la creación:

```
INSERT 0 20003
NOTICE:  usuario_anon OK: 20003 filas, 0 datos reales detectados
COMMIT

 id |  nombre   | apellido |         mail          |   celular   |   rol   | eliminado |  mes_alta
----+-----------+----------+-----------------------+-------------+---------+-----------+------------
  1 | Usuario_1 | Anon_1   | usuario_1@ejemplo.com | 000-0000001 | USUARIO | f         | 2026-10-01
  2 | Usuario_2 | Anon_2   | usuario_2@ejemplo.com | 000-0000002 | USUARIO | f         | 2026-10-01
  3 | Usuario_3 | Anon_3   | usuario_3@ejemplo.com | 000-0000003 | ADMIN   | f         | 2026-10-01
```

## 2. Especificación a OpenCode y consultas generadas (punto 2)

OpenCode se abrió **fuera del repositorio** (en un proyecto vacío, sin Git). Así no podía leer `sql/` y copiar nuestras consultas, que fue el problema que detectamos en la Parte C. El prompt solo incluye la **estructura** de las tablas, ningún dato.

Prompt enviado, textual:

> Tengo en PostgreSQL 16 la tabla usuario_anon(id BIGINT PK, nombre, apellido, mail, celular, rol rol, eliminado BOOLEAN, mes_alta DATE), donde rol es un ENUM ('ADMIN','USUARIO') y mes_alta es el primer día del mes de alta, ya calculado en la zona America/Argentina/Buenos_Aires.
> 1. Escribí una consulta sobre usuario_anon que devuelva la cantidad de usuarios no eliminados (eliminado = FALSE) agrupados por rol y por mes de alta. Columnas exactas y en este orden: rol, mes_alta (texto con formato 'YYYY-MM'), cantidad_usuarios. Ordenado por mes_alta y después por rol.
> 2. Escribí la consulta equivalente sobre la tabla real usuario(id, nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at TIMESTAMPTZ). Tiene que devolver las mismas columnas, con el mismo formato y el mismo orden. El mes de alta se obtiene convirtiendo created_at a la zona America/Argentina/Buenos_Aires antes de truncar al mes.
> Restricciones: solo SELECT, sin tablas temporales ni modificaciones. La consulta sobre usuario no puede leer ninguna columna aparte de rol, created_at y eliminado (nada de mail, nombre ni contrasena). No ejecutes nada ni leas archivos: solo respondé con las dos consultas.

Respuesta de OpenCode (agente *Build*, modelo *Muse Spark 1.3 Free*, 15 s). Respondió solo con las dos consultas y no ejecutó nada:

**D.1 — Sobre `usuario_anon`**

```sql
SELECT rol, TO_CHAR(mes_alta, 'YYYY-MM') AS mes_alta, COUNT(*) AS cantidad_usuarios
FROM usuario_anon
WHERE eliminado = FALSE
GROUP BY rol, mes_alta
ORDER BY mes_alta, rol;
```

**D.2 — Equivalente sobre `usuario` (real)**

```sql
SELECT rol, TO_CHAR(DATE_TRUNC('month', created_at AT TIME ZONE 'America/Argentina/Buenos_Aires'), 'YYYY-MM') AS mes_alta, COUNT(*) AS cantidad_usuarios
FROM usuario
WHERE eliminado = FALSE
GROUP BY rol, DATE_TRUNC('month', created_at AT TIME ZONE 'America/Argentina/Buenos_Aires')
ORDER BY mes_alta, rol;
```

Validación del equipo antes de ejecutarlas:

| Control | D.1 | D.2 |
|---|---|---|
| Filtra `eliminado = FALSE` | ✔ | ✔ |
| Columnas `rol`, `mes_alta` ('YYYY-MM'), `cantidad_usuarios`, en ese orden | ✔ | ✔ |
| Convierte a `America/Argentina/Buenos_Aires` **antes** de truncar | — (ya viene en `mes_alta`) | ✔ |
| No lee datos personales (`mail`, `nombre`, `contrasena`…) | ✔ | ✔ (solo `rol`, `created_at`, `eliminado`) |
| Solo `SELECT` | ✔ | ✔ |

Dos detalles que revisamos porque no eran evidentes:

- En D.1, `mes_alta` aparece dos veces con distinto tipo: la columna de la tabla es `DATE` y el alias de salida es texto. En PostgreSQL, el `GROUP BY` toma la columna de la tabla y el `ORDER BY` toma el alias. Como el texto tiene formato `YYYY-MM`, el orden alfabético coincide con el cronológico, así que el resultado es correcto.
- En D.2 se agrupa por `DATE_TRUNC(...)` y se ordena por el alias de texto. Es válido y da los mismos grupos.

Además de la base del TP, las dos consultas se probaron en una base auxiliar con altas en ocho meses distintos y usuarios eliminados. Devolvieron exactamente las mismas filas. No hubo que corregirlas, así que se usan **tal cual** en `sql/parteD_consultas_equivalencia.sql`.

## 3. Ejecución y evidencia de equivalencia (punto 3)

Entorno: base Food Store en PostgreSQL 16, cargada con `schema.sql`, `objects.sql`, `data.sql` y los 20.000 usuarios de `seed_masivo.sql` (20.003 usuarios en total), con `TimeZone` = `America/Argentina/Buenos_Aires`. La salida completa de `psql -e` (cada consulta seguida de su resultado) está en `docs/resultado_parteD.txt`.

**Resultados uno junto al otro**

| D.1 — `usuario_anon` | | | | D.2 — `usuario` (real) | | |
|---|---|---|---|---|---|---|
| **rol** | **mes_alta** | **cantidad** | | **rol** | **mes_alta** | **cantidad** |
| ADMIN | 2026-10 | 401 | | ADMIN | 2026-10 | 401 |
| USUARIO | 2026-10 | 19602 | | USUARIO | 2026-10 | 19602 |

**Comparación automática (D.3, `FULL OUTER JOIN`)**

```
   rol   | mes_alta | cantidad_usuario_anon | cantidad_usuario_real | coincide
---------+----------+-----------------------+-----------------------+----------
 ADMIN   | 2026-10  |                   401 |                   401 | SI
 USUARIO | 2026-10  |                 19602 |                 19602 | SI
```

**Diferencia simétrica (D.4, `EXCEPT` en ambos sentidos)**

```
 filas_solo_en_anon | filas_solo_en_real | total_anon | total_real
--------------------+--------------------+------------+------------
                  0 |                  0 |      20003 |      20003
```

Conclusión: **mismos grupos y mismos conteos**. No hay ningún grupo que esté en una sola de las tablas, ni ningún conteo distinto. La anonimización no distorsiona esta agregación.

**Por qué hay un solo mes.** En la base de desarrollo todos los usuarios se cargaron por script (`data.sql` + `seed_masivo.sql`), así que todos tienen `created_at` del mismo mes. Para que la prueba no quede débil por eso, se agregó un control negativo.

**Control negativo (D.5).** Simulamos una anonimización mal hecha que "aleatoriza" el mes de alta, corriéndolo entre 0 y 11 meses hacia atrás. Es un error típico cuando se busca "más anonimato". Con la misma verificación:

```
 filas_solo_en_anon | filas_solo_en_real | total_anon | total_real
--------------------+--------------------+------------+------------
                 24 |                  2 |      20003 |      20003
```

El **total sigue dando 20003**, pero los agrupamientos ya no coinciden: 24 grupos que la base real no tiene, y los 2 grupos reales con otros conteos. Esto muestra dos cosas. Primero, que la verificación sí detecta una distorsión. Segundo, que **comparar solo el total no alcanza**: hay que comparar grupo por grupo.

## 4. Qué no debe salir nunca hacia una IA sin anonimizar (punto 4)

Nunca debería llegar a un asistente de IA el contenido de la tabla `usuario` tal como está: nombre, apellido, mail y celular de los clientes, y sobre todo la columna `contrasena`, que en nuestra base está en texto plano, como mostró el simulacro de la Parte C. Tampoco debería llegar el historial de pedidos vinculado a una persona identificable (qué compra, cuándo, cuánto gasta y con qué forma de pago), ni los logs del servidor, que con `log_statement = 'all'` repiten esos mismos mails y contraseñas dentro de las sentencias registradas, por ejemplo en las llamadas a `fn_autenticar`. A la IA sí se le puede pasar la estructura (DDL), las consultas y resultados agregados como los de esta parte, que permiten trabajar sin exponer a nadie.
