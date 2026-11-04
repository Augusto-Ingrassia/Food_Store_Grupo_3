# Consigna 2 — Sincronizar y resolver

Todo se probó sobre una copia de pruebas del servidor (`food_store_pruebas`, con los datos inventados de `data.sql`). Los comandos completos están en `movil/casos_consigna2.ps1`, que recrea las dos bases y corre los casos en orden. En cada caso la tablet arma el borrador, se cambia el dato en el servidor si hace falta, se exporta una **instantánea nueva** y se corre el semáforo. La tablet nunca escribe en PostgreSQL y `SIMULADO_APROBADO` **no es una venta**.

## 2.a La instantánea

`v_snapshot_movil` exporta solo el catálogo: id, nombre, precio en centavos, stock, disponible, eliminado y fecha de copia. No filtra los eliminados: las bajas viajan como **lápidas** para que la tablet deje de mostrarlas. En SQLite el CSV se importa en `snapshot_servidor` y con él se actualiza `producto_cache` (upsert, sin borrar filas).

Fechas de las copias (04/11/2026): inicial 02:14:33 · C2 02:14:36 · C3 02:14:39 · C4 02:14:43 · C5 02:14:46.

## 2.c Los casos

Datos de partida: Fugazzeta (id 1) $1800 · Muzzarella (id 2) $1500 · Empanada de Carne (id 3) $400, stock 24 · Coca Cola 1.5L (id 4) $800.

| Caso | Comando clave | Resultado | Explicación |
|---|---|---|---|
| **C2** | Servidor: `UPDATE producto SET precio = 1700.00 WHERE id = 2;` | `CONFLICTO`: "precio de Muzzarella cambió: visto 150000, actual 170000 centavos" | No hay rojo, solo cambió el precio. El cliente acepta: se actualiza `precio_centavos_visto` y una **solicitud nueva** da `SIMULADO_APROBADO`. La anterior queda como historial. |
| **C3** | Tablet: borrador de 999 Empanadas | `RECHAZADO`: "sin stock suficiente: pide 999, hay 24" | La tablet lo permite porque su stock es solo una foto. Decide el servidor. |
| **C4** | Servidor: `UPDATE producto SET eliminado = TRUE WHERE id = 4;` | `RECHAZADO`: "Coca Cola 1.5L fue dado de baja" | Al recargar, el catálogo muestra solo los ids 1 a 3. La fila 4 queda con `eliminado = 1` porque el borrador la referencia. |
| **C5** | Tablet: borrador de 1 Fugazzeta | `SIMULADO_APROBADO` | Precio, stock y estado coinciden con la instantánea. No es una venta: eso solo lo hace `sp_crear_pedido` en el servidor. |
| **C6** | Tablet: `INSERT` en `cola_sync` con el UUID de C5 | `UNIQUE constraint failed: cola_sync.solicitud_uuid` y repetir el semáforo evalúa 0 | El UUID es la clave primaria, así que no se duplica. El semáforo solo toma las `PENDIENTE`, así que no reevalúa. |

**C6 en un sistema real (parada 8):** la protección iría en el servidor. PostgreSQL guardaría el `solicitud_uuid` como `UNIQUE` y, en la misma transacción que crea el pedido, haría `INSERT … ON CONFLICT DO NOTHING`. Así un reenvío no crea otro pedido ni descuenta stock dos veces.

## PostgreSQL no cambió

```sql
SELECT (SELECT COUNT(*) FROM pedido) AS pedidos, (SELECT SUM(stock) FROM producto) AS stock_total,
       (SELECT string_agg(id || ':' || stock, ' ' ORDER BY id) FROM producto) AS stock_por_producto;
```

| Momento | Pedidos | Stock total | Stock por producto |
|---|---|---|---|
| Antes | 2 | 65 | 1:8 2:14 3:24 4:19 |
| Después | 2 | 65 | 1:8 2:14 3:24 4:19 |

El precio de C2 y la baja de C4 los cambiamos nosotros en la copia del servidor para preparar los casos. La tablet no modificó nada.
