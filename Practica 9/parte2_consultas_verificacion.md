# Parte 2 · Consultas y verificación

**Entorno.** MongoDB 9.0.4 (mongosh 2.14.1), base `food_store`, colección `pedidos`, cargada con `consultas_mongodb.js`. PostgreSQL 17, base `food_store_nosql`.

**Procedencia de los datos en PostgreSQL.** Los pedidos 1 a 5 salen de la base del equipo poblada con `Practica 3/seed_masivo.sql`. Ese script genera los datos con `random()`, así que no se pueden volver a generar iguales. Para comparar se cargaron esos mismos 5 pedidos con `reconstruccion_pedidos_pg.sql`, sobre `schema.sql` y `objects.sql`:

- Se conservaron los identificadores, cantidades, precios históricos y estados de la migración.
- Los subtotales y el total no se cargaron a mano: los calcularon los triggers de Food Store.

Las salidas completas están en `salida_mongodb.txt` y `salida_postgresql.txt`.

## Consigna 4 · Consultas en MongoDB

| Apartado | Consulta (`db.pedidos…`) | Resultado |
|---|---|---|
| a) Todos los pedidos | `find({}, {_id:1, estado:1})` | 5 pedidos: 1 y 2 TERMINADO, 3 CANCELADO, 4 PENDIENTE, 5 CONFIRMADO |
| b) Por estado | `find({estado:"TERMINADO"}, {_id:1, estado:1})` | 2 pedidos: 1 y 2 |
| c) Por producto en el arreglo | `find({"detalles.producto.producto_id":43068}, {_id:1})` | 1 pedido: 1 |
| c') Producto presente en todos | `find({"detalles.producto.producto_id":1}, {_id:1})` | 5 pedidos: 1 a 5 |
| d) Total > 15000 | `find({total:{$gt:15000}}, {_id:1, total:1})` | **0 pedidos** (ver diferencia 1) |
| d corregida | `find({$expr:{$gt:[{$sum:"$detalles.subtotal"},15000]}}, …)` | 5 pedidos: 1 a 5, con `total_calculado` 16986.52 |

**Elección del producto en c).** El producto 1 aparece en los 5 pedidos, así que no distingue nada. Por eso la consulta principal usa el 43068, que aparece en un solo pedido. El c') queda como control.

**Umbral de d): 15000.** Es el mismo criterio de "ventas de alto valor" que el equipo definió en la Práctica 5 (`subtotal > 15000`). Ninguna línea lo supera por sí sola: la mayor vale exactamente 15000. Por lo tanto, solo lo superan los pedidos cuyo total suma varias líneas, que es justamente lo que se quiere detectar.

## Consigna 5 · Verificación contra PostgreSQL

Las consultas equivalentes están en `consultas_postgresql.sql`.

- b) usa `WHERE estado = 'TERMINADO'`.
- c) usa `JOIN detalle_pedido` con `producto_id = 43068`.
- Las dos filtran `eliminado = FALSE` y `p.id IN (1,2,3,4,5)`.

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
|---|---|---|---|
| Estado seleccionado (TERMINADO) | 2 (1, 2) | 2 (1, 2) | **Sí** |
| Producto seleccionado (43068) | 1 (1) | 1 (1) | **Sí** |
| Control: producto 1 | 5 (1–5) | 5 (1–5) | Sí |
| Control: total > 15000 | 5 (1–5) | 0 → corregida: 5 (1–5) | No → Sí tras corregir |

### Diferencias detectadas y correcciones

1. **El total de los pedidos no coincide.** En los 5 documentos, `total` migró como `0`, mientras que en PostgreSQL vale 16986.52. Ese valor es la suma de las líneas (1986.52 + 15000), que el trigger `trg_total_ins` mantiene actualizada.
   - **Consecuencia:** la consulta d) devolvió 0 pedidos en MongoDB y 5 en PostgreSQL.
   - **Corrección aplicada:** la consulta ahora calcula el total desde el arreglo embebido (`$sum: "$detalles.subtotal"`) y recupera los mismos 5 IDs que PostgreSQL.
   - **Corrección pendiente del modelo:** MongoDB no tiene triggers que mantengan `total`. La migración debería calcularlo al insertar, o habría que actualizarlo con `updateMany` y un pipeline `$set: {total: {$sum: "$detalles.subtotal"}}`. Si no, cualquier consulta sobre el total almacenado da resultados incorrectos.
2. **El alcance de las consultas.** La base completa del equipo tiene 200.000 pedidos y MongoDB solo los 5 migrados. Sin el filtro `p.id IN (1..5)`, la consulta b) en PostgreSQL devolvería miles de pedidos TERMINADO y la comparación no tendría sentido. Por eso las consultas SQL se limitan explícitamente al subconjunto migrado.
3. **El borrado lógico.** PostgreSQL filtra `eliminado = FALSE` en pedido y detalle, pero los documentos no tienen ese campo. Hoy no cambia el resultado, porque los 5 pedidos y sus líneas tienen `eliminado = FALSE`. Sin embargo, si una línea se diera de baja en PostgreSQL después de migrar, MongoDB seguiría encontrándola en la consulta c). La migración debería excluir las líneas eliminadas o llevar el campo al documento.

**Observación sobre los tipos de datos.**

- `fecha` quedó guardada como texto, no como `Date`.
- Los importes quedaron mezclados entre `Int32` (7500) y `Double` (993.26), en lugar de `Decimal128`, que sí se corresponde con `NUMERIC`.

Esto no afecta a b) ni a c), pero obliga a redondear (`$round`) los totales calculados. Además, los filtros por rango de fechas tendrían que comparar texto.
