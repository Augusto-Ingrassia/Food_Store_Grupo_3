Consulta 1:

Antes:

"QUERY PLAN"
"Sort  (cost=6068.17..6110.79 rows=17047 width=23) (actual time=63.529..65.778 rows=16723.00 loops=1)"
"  Sort Key: fecha DESC"
"  Sort Method: quicksort  Memory: 1422kB"
"  Buffers: shared hit=3 read=1870"
"  ->  Seq Scan on pedido  (cost=0.00..4870.00 rows=17047 width=23) (actual time=1.826..55.671 rows=16723.00 loops=1)"
"        Filter: ((NOT eliminado) AND (estado = 'CANCELADO'::estado_pedido) AND (forma_pago = 'EFECTIVO'::forma_pago))"
"        Rows Removed by Filter: 183277"
"        Buffers: shared read=1870"
"Planning:"
"  Buffers: shared hit=95 read=9 dirtied=1"
"Planning Time: 7.921 ms"
"Execution Time: 68.013 ms"

Despues:
Propuesta de IA: CREATE INDEX idx_pedido_cancelado_efectivo ON pedido (estado, forma_pago, eliminado, fecha DESC);

Plan Después: No aplica (el índice no fue creado).

Justificación del rechazo (Sobreindexación): Se descartó explícitamente esta propuesta. La IA propuso un índice compuesto masivo de 4 columnas que aplicaría sobre absolutamente toda la tabla (sin cláusula WHERE). Incluir columnas de bajísima cardinalidad como el booleano eliminado generaría un índice muy pesado con un costo de mantenimiento altísimo para las escrituras (sobreindexación). Preferimos mantener el Seq Scan antes que penalizar toda la tabla.