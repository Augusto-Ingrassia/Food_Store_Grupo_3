# Consigna 3 — Integrar y revisar

## 3.a Mapa de la capa de datos

```
                    instantánea v_snapshot_movil (CSV, con lápidas)
   ┌──────────────┐ ─────────────────────────────────────────────▶ ┌──────────────────┐
   │  PostgreSQL  │                                                 │  SQLite (tablet) │
   │  food_store  │ ◀───────────────────────────────────────────── │ foodstore_movil  │
   │   (MANDA)    │   solicitud en cola_sync (propone, no escribe)  │       .db        │
   └──────────────┘                                                 └──────────────────┘
          │ migración (insertMany, U7)
          ▼
   ┌──────────────┐
   │   MongoDB    │  copia de lectura: no le escribe a nadie
   │ food_store.  │
   │   pedidos    │
   └──────────────┘
```

| Motor | Qué guarda | Quién manda |
|---|---|---|
| **PostgreSQL** (`food_store`, servidor) | Catálogo (`categoria`, `producto` con precio, stock, disponible y baja), `usuario` con credenciales, ventas (`pedido`, `detalle_pedido`) y la lógica: `sp_crear_pedido` y los triggers de subtotal y total | **Manda sobre todo.** Es la única fuente de verdad. Solo acá se crea una venta, se fija un precio y se descuenta stock. |
| **MongoDB** (`food_store.pedidos`, U7) | Los 5 pedidos migrados como documentos: cliente, líneas, producto y categoría embebidos, con el precio histórico de cada línea. Sin contraseña ni rol. | **No manda sobre nada.** Es una copia derivada para leer pedidos sin JOIN. Si difiere de PostgreSQL, se corrige MongoDB (como el `total` que migró en 0). |
| **SQLite** (`foodstore_movil.db`, tablet) | `producto_cache` y `snapshot_servidor` (foto del catálogo con `fecha_copia`), `pedido_borrador`, `item_borrador` y `cola_sync` | **Manda solo sobre sus borradores y su cola**, que no existen en ningún otro lado hasta que se envían. El catálogo es una foto: precio y stock los manda PostgreSQL. `SIMULADO_APROBADO` no es una venta. |

| Dato | Dónde vive | Quién manda |
|---|---|---|
| Precio, stock, disponible, baja | PostgreSQL → foto en SQLite | PostgreSQL |
| Venta (pedido, total, descuento de stock) | PostgreSQL, por `sp_crear_pedido` | PostgreSQL |
| Comprobante histórico de un pedido | PostgreSQL → copia en MongoDB | PostgreSQL |
| Contraseñas, mails, roles | Solo PostgreSQL (no viajan) | PostgreSQL |
| Borrador armado en la feria | Solo SQLite | La tablet, hasta que el servidor lo acepte o lo rechace |
| Estado de la solicitud (`cola_sync`) | SQLite (simulado) | En la simulación, el semáforo. En un sistema real, la respuesta de PostgreSQL. |

## 3.b Plan de mantenimiento (agregado al plan de la Unidad 6)

**Qué se respalda y cómo se prueba.**

- **PostgreSQL:** se respalda con `backup_foodstore.ps1` (`pg_dump -Fc` diario a las 02:00, regla 3-2-1-1 y retención de 7 diarios, 4 semanales y 6 mensuales). Junto al `.dump` se guardan los roles de la U5 con `pg_dumpall --globals-only`, porque `pg_dump` no los incluye (hallazgo 12 de 3.c). La restauración se prueba todas las semanas con `restore_test.ps1` en `foodstore_restore_test`, más una vez por mes con la copia bajada de la nube. `validacion_restore.sql` tiene que dar los mismos conteos que el `.conteo.txt` y 0 en los controles lógicos. Una restauración real, a diferencia de la prueba, se hace sin `--no-privileges`.
- **MongoDB:** no se respalda como fuente, porque se regenera desde PostgreSQL con la migración (`consultas_mongodb.js`).
- **SQLite:** de cada tablet solo importa lo que no está en el servidor, es decir, los borradores y la `cola_sync`. Al volver de la feria se copia con `VACUUM INTO 'respaldo_tablet_AAAAMMDD.db'`. El catálogo no se respalda porque se rehace con una instantánea. Para probar la copia se abre y se corre `PRAGMA integrity_check;` (tiene que dar `ok`) y `PRAGMA foreign_key_check;` (tiene que salir vacío). Se probó sobre una copia de `foodstore_movil.db`: dio `ok`, sin errores de FK y con las 5 solicitudes.

**Si se restaura un respaldo viejo de PostgreSQL**, las tablets dejan de confiar en su foto. Una señal de alarma es que su `fecha_copia` sea más nueva que el respaldo. Esto es lo que hacen:

1. No envían nada hasta que el responsable declara la base operativa.
2. Cargan una instantánea nueva, porque precios, stock y bajas pueden haber vuelto atrás.
3. Pasan otra vez a `PENDIENTE` las solicitudes `SIMULADO_APROBADO` (`UPDATE cola_sync SET estado = 'PENDIENTE', motivo = NULL WHERE estado = 'SIMULADO_APROBADO';`) y corren el semáforo contra la foto nueva. No eran ventas, así que no se pierde nada.
4. Conservan el mismo `solicitud_uuid`. En el sistema real, el `UNIQUE` del servidor descarta las que el respaldo ya tenía y vuelve a crear las que se perdieron en la ventana del RPO.

**Revisión de CONFLICTO y RECHAZADO.**

- **Al cierre de cada jornada de feria**, cuando la tablet recupera señal y antes de cargar la instantánea del día siguiente, el **encargado del food truck** corre `SELECT estado, id_local, motivo FROM cola_sync WHERE estado IN ('CONFLICTO','RECHAZADO');`.
  - Un `CONFLICTO` se resuelve con el cliente: si acepta el precio nuevo, se actualiza el borrador y se manda una solicitud nueva (caso C2).
  - Un `RECHAZADO` se avisa al cliente y el borrador queda como historial.
- **Una vez por semana**, junto con `restore_test.ps1`, el **responsable del plan U6** revisa los conteos por estado y motivo. Si se repiten conflictos de precio, la instantánea se está tomando con poca frecuencia.


## 3.c Code review con IA

**Cómo se hizo.** La consigna pide OpenCode con el agente Plan. El 05/11/2026, OpenCode respondió `Free usage limit reached` con todos sus modelos gratuitos. Con el aval del docente, la revisión se hizo con **Claude Code** (modelo Claude Opus 5.5), en modo solo lectura sobre todos los scripts de la cursada y con el pedido de `docs/prompt_code_review.txt`.

Ningún hallazgo se aceptó sin probarlo. Cada uno se comprobó en un PostgreSQL 17 descartable (otro servidor, puerto 5499, con bases nuevas creadas desde `schema.sql`, `objects.sql` y `data.sql`) y, los de la tablet, sobre una copia de `foodstore_movil.db`. La base real no se tocó. Después de corregir, todo se volvió a crear desde cero.

| # | U | Archivo | Hallazgo | Decisión | Motivo / comprobación |
|---|---|---|---|---|---|
| 1 | 1-2 | `objects.sql` | `sp_crear_pedido` no puede vender la última unidad: deja `stock = 0` con `disponible = TRUE` y viola `chk_producto_stock_si_disponible` | **Corregido** | Ver desarrollo A |
| 2 | 1-2 | `objects.sql` | `sp_crear_pedido` con `'[]'` crea un pedido sin detalles y con total 0 | **Corregido** | Antes: `CALL` exitoso, pedido 4 con 0 detalles. Ahora: `ERROR: El pedido no tiene ítems` |
| 3 | 1-2 | `README.md` | Pone `data.sql` antes de `objects.sql` y no menciona `views.sql` | **Corregido** | Con ese orden, `data.sql` falla: `procedure sp_crear_pedido(...) does not exist`. También se arregló la nota de `AGENTS.md` |
| 4 | 1-2 | `queries.sql` | HU-PROD-01 filtra `p.eliminado`, pero no `c.eliminado`: muestra productos de categorías dadas de baja | **Aceptado** | Con la categoría 2 dada de baja, la Coca Cola sigue en la lista. `v_productos_vigentes` ya filtra las dos, así que la HU debería usar esa vista. Queda pendiente para no cambiar la entrega de la U1 |
| 5 | 1-2 | `objects.sql` | "Falta un trigger AFTER DELETE en `detalle_pedido` para recalcular el total" | **Descartado** | Ver desarrollo D |
| 6 | 3 | `Practica 5/query.sql` | Quedaron marcas de merge sin resolver (`<<<<<<< HEAD`) | **Corregido** | Antes: `syntax error at or near "<<<<<<<"`, y la consulta 1 nunca corría. Las dos mitades eran idénticas (`diff` vacío), así que se dejó una. Ahora corren los 3 `EXPLAIN` sin errores |
| 7 | 3 | `Practica 5/indices.sql` | "`CREATE INDEX CONCURRENTLY` falla" | **Descartado** | Solo falla dentro de una transacción (`psql -1`). Con `psql -f`, que es como se usa, crea los dos índices. Se deja `CONCURRENTLY` porque no bloquea las escrituras en una tabla de 200.000 pedidos |
| 8 | 3 | `Practica 3/seed_masivo.sql` | Falla si se corre después de `data.sql`. `ON CONFLICT DO NOTHING` consume valores de la identidad, así que las categorías nuevas quedan con id 4 y 8, y el `(g % 5) + 1` busca la 5 | **Aceptado** | Se reprodujo: `Key (categoria_id)=(5) is not present`. Sobre `schema.sql` y `objects.sql` sin `data.sql`, como lo corrió el equipo en la U3, funciona. No se cambió para no alterar las mediciones de la U3. Se documenta que va sobre una base sin datos de ejemplo |
| 9 | 5 | `Practica 7/roles.sql` | `app_web` no puede crear ningún pedido válido. El `GRANT EXECUTE` sobre `sp_crear_pedido` estaba comentado y el `INSERT` directo deja un pedido vacío | **Corregido** | Ver desarrollo B |
| 10 | 5 | `Practica 7/roles.sql` | `rol_reportes` tiene `SELECT` sobre toda la tabla `usuario`, incluida `contrasena` | **Aceptado** | `SET ROLE rol_reportes; SELECT mail, contrasena FROM usuario` devuelve `adminpass`. Es el permiso que explota el simulacro de la U5, así que se mantiene para poder reproducirlo. La corrección propuesta es dar `GRANT SELECT` por columnas, sin `contrasena`, y usar `usuario_anon` para BI |
| 11 | 5 | `Practica 7/sql/simulacro_incidente.sql` | Deja `log_statement = 'all'` activo para siempre, y cada contraseña que se prueba queda en texto plano en el log | **Corregido** | Antes: `SHOW log_statement` daba `all`, y en el log aparecía `SELECT fn_autenticar('admin@foodstore.com', 'adminpass')`. El informe de la U5 recomendaba volver a `'mod'`, pero el script no lo hacía. Se agregó el paso 2.4. Ahora queda en `mod` |
| 12 | 6 | `Practica 8/restore_test.ps1`, `backup_foodstore.ps1` | La base restaurada no tiene ningún permiso de la U5, y los roles no están en el `.dump` | **Aceptado** | El `.dump` trae 26 permisos (ACL), pero `--no-privileges` los descarta: `has_table_privilege('rol_reportes','pedido','SELECT')` da `t` en el origen y `f` en la base restaurada. Para la prueba semanal está bien así, pero se agregó al plan (3.b) `pg_dumpall --globals-only` y una restauración real con privilegios |
| 13 | 7 | `Practica 9/reconstruccion_pedidos_pg.sql` | Inserta con `OVERRIDING SYSTEM VALUE` sin adelantar las secuencias. El próximo pedido choca con el id 1 | **Descartado** | Ver desarrollo E |
| 14 | 8 | `movil/schema_sqlite.sql` | `item_borrador` no tiene clave primaria. Un borrador puede tener el mismo producto en dos renglones, y el semáforo compara cada uno contra el stock por separado | **Corregido** | Ver desarrollo C |
| 15 | 8 | `movil/servidor_snapshot.sql` | "`v_snapshot_movil` no filtra `eliminado = FALSE`, como pide la regla del proyecto" | **Descartado** | Es a propósito. Las bajas tienen que viajar como lápidas para que la tablet deje de ofrecer el producto. Si se filtraran, el caso C4 daría `SIMULADO_APROBADO` con una Coca Cola dada de baja. La regla de borrado lógico vale para las consultas de negocio, no para la instantánea de sincronización |

### Desarrollo de cinco hallazgos (unidades 1-2, 5, 7 y 8)

**A. No se puede vender la última unidad (U1-2, corregido).** El CHECK `disponible = FALSE OR stock > 0` de `schema.sql` y el `UPDATE producto SET stock = stock - v_cantidad` del procedimiento se contradicen.

- **Comprobación:** con la Fugazzeta en stock 8, `CALL sp_crear_pedido(1, 'EFECTIVO', '[{"producto_id":1,"cantidad":8}]')` dio `violates check constraint "chk_producto_stock_si_disponible"`. Se revirtió todo, sin pedido nuevo y con el stock en 8. El cliente se queda sin comprar la última pizza.
- **Corrección:** el mismo `UPDATE` pone `disponible = (stock - v_cantidad > 0)`.
- **Resultado:** ahora el pedido se crea, la Fugazzeta queda en `stock = 0`, `disponible = f`, y un pedido siguiente da `Producto 1 no disponible`.
- **Efecto en la tablet:** la instantánea lleva `disponible = f`, así que el semáforo lo marca en rojo, igual que hoy.

**B. La API no puede crear pedidos (U5, corregido).** En `roles.sql`, `REVOKE ALL ON ALL PROCEDURES FROM PUBLIC` deja sin permiso a todos, y el `GRANT EXECUTE` a `rol_app_escritura` estaba comentado.

- **Comprobación**, con `SET ROLE app_web`:
  - `CALL sp_crear_pedido(...)` dio `permission denied for procedure sp_crear_pedido`.
  - El camino alternativo, `INSERT INTO pedido`, sí se ejecutó, pero el `INSERT` del detalle falló dentro del trigger `fn_recalcular_total` (`permission denied for table pedido`). Quedó un pedido 3 con total 0 y sin detalles.
- **Corrección:**
  - `sp_crear_pedido` pasa a `SECURITY DEFINER` con `search_path` fijo (el mismo patrón que `fn_autenticar`) y se le da `GRANT EXECUTE` a `rol_app_escritura`.
  - Se le quita el `INSERT` directo sobre `pedido` y `detalle_pedido`. Así queda una sola puerta para crear pedidos, como dice la regla del proyecto.
- **Resultado:** `app_web` crea el pedido 5 (total 1500, descuenta una Muzzarella) y su `INSERT` directo da `permission denied`. `roles.sql` se puede seguir corriendo dos veces sin errores.

**C. El semáforo aprueba más unidades de las que hay (U8, corregido).**

- **Comprobación:** sobre una copia de `foodstore_movil.db` se armó un borrador con dos renglones de 20 Empanadas (40 en total), con 24 en stock. El semáforo dio `SIMULADO_APROBADO`, porque ningún renglón supera 24 por sí solo. En PostgreSQL ese pedido ni siquiera entra, por el `UNIQUE (pedido_id, producto_id)` de `detalle_pedido`.
- **Corrección:** `PRIMARY KEY (id_local, producto_id)` en `item_borrador`, el mismo criterio que el servidor. Para agregar unidades se actualiza `cantidad`.
- **Migración de la base:** `foodstore_movil.db` se migró con crear, copiar, borrar y renombrar la tabla. Quedaron las mismas 4 filas, `integrity_check = ok`, sin errores de FK, y los estados de C2 a C6 no cambiaron.
- **Resultado:** ahora el segundo renglón da `UNIQUE constraint failed: item_borrador.id_local, item_borrador.producto_id`. `schema_sqlite.sql` y `pruebas_sqlite.sql` se volvieron a correr desde cero: C1 devuelve el catálogo y C7 sigue dando los dos errores esperados.

**D. "Falta el trigger de DELETE" (U1-2, descartado con fundamento).** Es cierto que `trg_total_ins` y `trg_total_upd` no cubren el `DELETE`, pero en Food Store nunca se borra físicamente un detalle:

- todas las bajas son lógicas;
- la FK de `pedido` es `ON DELETE RESTRICT`;
- ningún rol de `roles.sql` tiene `DELETE`.

La baja lógica sí está cubierta. `UPDATE detalle_pedido SET eliminado = TRUE WHERE pedido_id = 2 AND producto_id = 3` bajó el total del pedido 2 de 3900 a 1500, porque `calcular_total_pedido` filtra `eliminado = FALSE`. Agregar el trigger sería código para un caso que el diseño prohíbe.

**E. Secuencias sin adelantar en la reconstrucción (U7, descartado con fundamento).**

- **Reproducción:** después de `reconstruccion_pedidos_pg.sql`, `pedido_id_seq` quedó en 1 y un `CALL sp_crear_pedido` dio `duplicate key ... Key (id)=(1)`.
- **Por qué se descarta:** `food_store_nosql` es una base de solo comparación contra MongoDB, con los 5 pedidos migrados, y nunca recibe pedidos nuevos. `consultas_postgresql.sql`, que es su único uso, devolvió lo esperado (TERMINADO: 1 y 2; producto 43068: 1; totales 16986.52).
- **Si alguna vez se usara para escribir**, bastaría con `SELECT setval('pedido_id_seq', (SELECT MAX(id) FROM pedido));`.
