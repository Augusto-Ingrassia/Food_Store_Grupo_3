CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pedido_tarjeta_vigente
ON pedido (forma_pago, usuario_id, total)
WHERE eliminado = FALSE;


CREATE INDEX idx_detalle_pedido_ventas_alto_valor
    ON detalle_pedido (subtotal DESC)
    WHERE eliminado = FALSE;