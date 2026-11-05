# Diseño Arquitectónico - Sincronización Offline

**Modelo de Datos:**
Se utilizará SQLite en la tablet para garantizar la operatividad sin conexión. La base contendrá un catálogo en caché (`producto_cache`) y tablas transaccionales locales (`pedido_borrador`, `item_borrador`, `cola_sync`).

**Flujo de Sincronización (El semáforo):**
1. El servidor PostgreSQL es la única fuente de verdad.
2. La tablet exporta una instantánea (`snapshot_servidor`) del catálogo actual.
3. Un script SQL evalúa cada solicitud `PENDIENTE` en `cola_sync` contra la instantánea mediante un `LEFT JOIN`.
4. Según los hallazgos (falta de stock, producto dado de baja o cambio de precio), el estado muta a `RECHAZADO`, `CONFLICTO` o `SIMULADO_APROBADO`.