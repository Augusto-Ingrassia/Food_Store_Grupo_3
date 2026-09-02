Herramienta: OpenCode.

Prompt/Spec: "Necesito dos sentencias ALTER TABLE para PostgreSQL. La primera debe agregar un constraint CHECK en la tabla detalle_pedido para que precio_unitario sea mayor a 0. La segunda debe agregar un constraint CHECK en la tabla producto para que, si disponible es TRUE, el stock deba ser mayor a 0."

Qué generó la IA: Dos sentencias ALTER TABLE con las reglas solicitadas, un DROP para limpiar la regla preexistente, y dos comandos CREATE INDEX adicionales.

Qué se aceptó/modificó: Se aceptó la sugerencia completa sin modificaciones.

Verificación: Se ejecutó el script dentro de una transacción (BEGIN;) y se intentó ingresar un precio negativo y un producto sin stock. El motor lanzó errores de integridad, validando el funcionamiento.