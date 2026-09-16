Consulta 2:

Antes:

"QUERY PLAN"
"Gather Merge  (cost=4743.61..4743.73 rows=1 width=27) (actual time=97.373..102.909 rows=0.00 loops=1)"
"  Workers Planned: 1"
"  Workers Launched: 1"
"  Buffers: shared hit=37 read=2273"
"  ->  Sort  (cost=3743.60..3743.60 rows=1 width=27) (actual time=40.576..40.577 rows=0.00 loops=2)"
"        Sort Key: subtotal DESC"
"        Sort Method: quicksort  Memory: 25kB"
"        Buffers: shared hit=37 read=2273"
"        Worker 0:  Sort Method: quicksort  Memory: 25kB"
"        ->  Parallel Seq Scan on detalle_pedido  (cost=0.00..3743.59 rows=1 width=27) (actual time=40.523..40.524 rows=0.00 loops=2)"
"              Filter: ((NOT eliminado) AND (subtotal > '15000'::numeric))"
"              Rows Removed by Filter: 100000"
"              Buffers: shared read=2273"
"Planning:"
"  Buffers: shared hit=90 read=5 dirtied=2"
"Planning Time: 5.828 ms"
"Execution Time: 102.969 ms"

Despues:

"QUERY PLAN"
"Index Scan using idx_detalle_pedido_ventas_alto_valor on detalle_pedido  (cost=0.42..4.44 rows=1 width=27) (actual time=0.072..0.072 rows=0.00 loops=1)"
"  Index Cond: (subtotal > '15000'::numeric)"
"  Index Searches: 1"
"  Buffers: shared read=3"
"Planning:"
"  Buffers: shared hit=2 read=1"
"Planning Time: 2.304 ms"
"Execution Time: 0.093 ms"