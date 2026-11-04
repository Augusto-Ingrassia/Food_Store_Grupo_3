-- Consigna 2.b — El semáforo: simula la respuesta del servidor para cada solicitud PENDIENTE
--   sqlite3 foodstore_movil.db ".read semaforo.sql"
-- Compara contra snapshot_servidor (la foto de PostgreSQL), no contra producto_cache.
-- No toca PostgreSQL: SIMULADO_APROBADO NO es una venta, solo dice que el servidor probablemente la aceptaría.
PRAGMA foreign_keys = ON;

-- Rojo     RECHAZADO          algún producto no existe, no está disponible, fue dado de baja o no alcanza el stock
-- Amarillo CONFLICTO          no hay rojo, pero cambió algún precio
-- Verde    SIMULADO_APROBADO  todo coincide
-- Solo se evalúan las PENDIENTE: repetir la simulación no reevalúa nada (idempotente).
WITH problemas AS (
    SELECT c.solicitud_uuid,
           CASE
               WHEN i.producto_id IS NULL    THEN 'el borrador no tiene ítems'
               WHEN s.id IS NULL             THEN 'producto ' || i.producto_id || ' no existe en el servidor'
               WHEN s.eliminado = 't'        THEN 'producto ' || i.producto_id || ' (' || s.nombre || ') fue dado de baja'
               WHEN s.disponible <> 't'      THEN 'producto ' || i.producto_id || ' (' || s.nombre || ') no está disponible'
               WHEN i.cantidad > s.stock     THEN 'producto ' || i.producto_id || ' (' || s.nombre || ') sin stock suficiente: pide '
                                                  || i.cantidad || ', hay ' || s.stock
           END AS rojo,
           CASE
               WHEN i.precio_centavos_visto <> s.precio_centavos
                   THEN 'precio de ' || s.nombre || ' cambió: visto ' || i.precio_centavos_visto
                        || ', actual ' || s.precio_centavos || ' centavos'
           END AS amarillo
    FROM cola_sync c
    LEFT JOIN item_borrador i     ON i.id_local = c.id_local
    LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
    WHERE c.estado = 'PENDIENTE'
),
resultado AS (
    SELECT solicitud_uuid,
           CASE
               WHEN COUNT(rojo) > 0     THEN 'RECHAZADO'
               WHEN COUNT(amarillo) > 0 THEN 'CONFLICTO'
               ELSE 'SIMULADO_APROBADO'
           END AS estado,
           CASE
               WHEN COUNT(rojo) > 0     THEN group_concat(rojo, '; ')
               WHEN COUNT(amarillo) > 0 THEN group_concat(amarillo, '; ')
               ELSE 'coincide con la instantánea del ' || (SELECT MAX(fecha_copia) FROM snapshot_servidor)
           END AS motivo
    FROM problemas
    GROUP BY solicitud_uuid
)
UPDATE cola_sync
SET estado = resultado.estado,
    motivo = resultado.motivo
FROM resultado
WHERE cola_sync.solicitud_uuid = resultado.solicitud_uuid;

SELECT changes() AS solicitudes_evaluadas;

SELECT solicitud_uuid, id_local, estado, motivo
FROM cola_sync
ORDER BY id_local, solicitud_uuid;
