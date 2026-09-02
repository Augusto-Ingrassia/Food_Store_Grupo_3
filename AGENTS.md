# AGENTS.md

## What this is

PostgreSQL 16+ database project for a food store (university assignment — UTN Base de Datos II). Pure SQL, no application code. All comments and identifiers are in Spanish.

## Correct script execution order

The README lists the wrong order. `data.sql` calls `sp_crear_pedido()` defined in `objects.sql` and will fail if run first.

```
1. schema.sql       — enums, tables, constraints, indexes
2. objects.sql      — views, functions, triggers, stored procedures
3. data.sql         — sample data (depends on objects.sql)
4. queries.sql      — ad-hoc queries per user story (HU-*)
5. transacciones.sql — duplicate of some queries in queries.sql
```

Run against an **empty database**. To reset: drop and recreate the DB, then run in this order.

## Key patterns to preserve

- **Soft-delete everywhere**: every table has `eliminado BOOLEAN DEFAULT FALSE`. All queries must filter `WHERE eliminado = FALSE`.
- **Enum types** `rol`, `estado_pedido`, `forma_pago` are defined in `schema.sql`. Do not use raw strings where enums exist.
- **Auto-calculated fields**: `detalle_pedido.subtotal` and `pedido.total` are maintained by triggers (`trg_subtotal`, `trg_total_ins`, `trg_total_upd`). Never INSERT/UPDATE these columns manually — the triggers handle it.
- **`sp_crear_pedido(p_usuario_id, p_forma_pago, p_items JSONB)`**: the only way to create orders. It validates stock, locks rows with `FOR UPDATE`, deducts stock, and inserts details — all transactionally. Use `CALL`, not `SELECT`.
- **Identity columns**: all PKs use `GENERATED ALWAYS AS IDENTITY`. Do not provide explicit id values in INSERTs.

## Verification

After setup, run `SELECT * FROM v_pedidos_resumen;` to confirm data loaded correctly. Expect at least 2 orders with non-zero totals.
