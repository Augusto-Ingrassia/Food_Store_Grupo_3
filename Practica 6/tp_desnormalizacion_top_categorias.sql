-- =====================================================================
-- TP Unidad 4 - Parte 2: Desnormalizacion controlada (top 5 categorias/dia)
-- Patron elegido: tabla resumen precalculada + disparador (mismo patron
-- que ya usa el proyecto en objects.sql para pedido.total via
-- fn_recalcular_total / trg_total_ins / trg_total_upd).
-- Justificacion completa (evidencia de EXPLAIN ANALYZE, por que no se
-- desincroniza, reversibilidad): ver informe.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.2.a) Consulta original, para referencia (correr con EXPLAIN ANALYZE
--        sobre la base ya poblada por seed_masivo.sql; salida real en
--        el informe).
-- ---------------------------------------------------------------------
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT c.nombre AS categoria,
--        SUM(dp.subtotal) AS total_vendido
-- FROM detalle_pedido dp
-- JOIN producto pr ON pr.id = dp.producto_id
-- JOIN categoria c ON c.id = pr.categoria_id
-- JOIN pedido ped ON ped.id = dp.pedido_id
-- WHERE ped.fecha = CURRENT_DATE
--   AND dp.eliminado = FALSE
--   AND ped.eliminado = FALSE
-- GROUP BY c.nombre
-- ORDER BY total_vendido DESC
-- LIMIT 5;

-- ---------------------------------------------------------------------
-- 5.2.c) Estructura desnormalizada: tabla resumen por categoria y dia
-- ---------------------------------------------------------------------
CREATE TABLE resumen_ventas_categoria_dia (
    categoria_id   BIGINT        NOT NULL REFERENCES categoria(id),
    fecha          DATE          NOT NULL,
    total_vendido  NUMERIC(14,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (categoria_id, fecha)
);

CREATE INDEX idx_resumen_ventas_fecha ON resumen_ventas_categoria_dia(fecha);

-- Backfill inicial con el estado actual de la base
INSERT INTO resumen_ventas_categoria_dia (categoria_id, fecha, total_vendido)
SELECT pr.categoria_id, ped.fecha, SUM(dp.subtotal)
FROM detalle_pedido dp
JOIN pedido ped ON ped.id = dp.pedido_id
JOIN producto pr ON pr.id = dp.producto_id
WHERE dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY pr.categoria_id, ped.fecha;

-- Mecanismo de sincronizacion: recalcula, para un conjunto de pedidos
-- afectados, el total vigente de cada (categoria, fecha) que tocan.
-- Se usa FILTER (no WHERE) para que una categoria/fecha que se quedo
-- sin ventas vigentes (ultimo detalle cancelado) tambien se actualice
-- a 0 en vez de quedar con un valor viejo.
CREATE OR REPLACE FUNCTION fn_recalcular_resumen_por_pedidos(p_pedido_ids BIGINT[])
RETURNS VOID AS $$
BEGIN
    -- Recalcula TODAS las categorias del/los dia(s) de los pedidos
    -- afectados (no solo la categoria del pedido que disparo el cambio):
    -- el total por categoria/dia es un agregado compartido por muchos
    -- pedidos, asi que hay que recomputarlo completo para ese dia y no
    -- solo con las filas del pedido que cambio.
    WITH fechas_afectadas AS (
        SELECT DISTINCT fecha FROM pedido WHERE id = ANY(p_pedido_ids)
    )
    INSERT INTO resumen_ventas_categoria_dia (categoria_id, fecha, total_vendido)
    SELECT pr.categoria_id,
           ped.fecha,
           COALESCE(SUM(dp.subtotal) FILTER (
               WHERE dp.eliminado = FALSE AND ped.eliminado = FALSE
           ), 0)
    FROM detalle_pedido dp
    JOIN pedido ped ON ped.id = dp.pedido_id
    JOIN producto pr ON pr.id = dp.producto_id
    WHERE ped.fecha IN (SELECT fecha FROM fechas_afectadas)
    GROUP BY pr.categoria_id, ped.fecha
    ON CONFLICT (categoria_id, fecha) DO UPDATE
        SET total_vendido = EXCLUDED.total_vendido;
END;
$$ LANGUAGE plpgsql;
-- ponytail: no recalcula si un UPDATE reasigna detalle_pedido.producto_id
-- a otra categoria (la app nunca hace ese UPDATE, solo INSERT y soft-delete
-- via 'eliminado'). Si algun dia se permite reasignar producto, sumar el
-- calculo de las categorias OLD ademas de las de pedido_id.

-- Dispara el recalculo cuando cambian los detalles de un pedido
CREATE OR REPLACE FUNCTION fn_resumen_trigger_detalle()
RETURNS TRIGGER AS $$
DECLARE
    v_pedido_ids BIGINT[];
BEGIN
    SELECT ARRAY_AGG(DISTINCT pedido_id) INTO v_pedido_ids FROM afectados;
    PERFORM fn_recalcular_resumen_por_pedidos(v_pedido_ids);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_resumen_detalle_ins
AFTER INSERT ON detalle_pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_resumen_trigger_detalle();

CREATE TRIGGER trg_resumen_detalle_upd
AFTER UPDATE ON detalle_pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_resumen_trigger_detalle();

-- Dispara el recalculo cuando un pedido completo se marca/desmarca eliminado
CREATE OR REPLACE FUNCTION fn_resumen_trigger_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_pedido_ids BIGINT[];
BEGIN
    SELECT ARRAY_AGG(DISTINCT id) INTO v_pedido_ids FROM afectados;
    PERFORM fn_recalcular_resumen_por_pedidos(v_pedido_ids);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Nota: Postgres no permite REFERENCING (transition tables) combinado con
-- "UPDATE OF columna"; se dispara en cualquier UPDATE de pedido. El
-- recalculo es idempotente (siempre refleja el estado real), asi que
-- disparar de mas ante un UPDATE que no toco 'eliminado' no genera drift,
-- solo trabajo redundante aceptable a esta escala.
CREATE TRIGGER trg_resumen_pedido_upd
AFTER UPDATE ON pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_resumen_trigger_pedido();

-- ---------------------------------------------------------------------
-- 5.2.d) Consulta del reporte leyendo la estructura desnormalizada
-- ---------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       r.total_vendido
FROM resumen_ventas_categoria_dia r
JOIN categoria c ON c.id = r.categoria_id
WHERE r.fecha = CURRENT_DATE
ORDER BY r.total_vendido DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- 5.2.e) Auditoria: compara el resumen contra la fuente de verdad.
--        Debe devolver 0 filas sobre la base ya migrada.
-- ---------------------------------------------------------------------
SELECT r.categoria_id,
       r.fecha,
       r.total_vendido AS total_resumen,
       COALESCE(t.total_real, 0) AS total_real
FROM resumen_ventas_categoria_dia r
LEFT JOIN (
    SELECT pr.categoria_id, ped.fecha, SUM(dp.subtotal) AS total_real
    FROM detalle_pedido dp
    JOIN pedido ped ON ped.id = dp.pedido_id
    JOIN producto pr ON pr.id = dp.producto_id
    WHERE dp.eliminado = FALSE
      AND ped.eliminado = FALSE
    GROUP BY pr.categoria_id, ped.fecha
) t ON t.categoria_id = r.categoria_id AND t.fecha = r.fecha
WHERE r.total_vendido IS DISTINCT FROM COALESCE(t.total_real, 0);
