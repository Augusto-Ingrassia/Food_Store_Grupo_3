# Parte C — Respuesta completa de la IA (OpenCode)

## Prompt enviado

Se envió únicamente esta consigna, seguida del contenido completo de
`log_simulacro_anonimizado.txt` (41 líneas), sin agregar contexto adicional:

```
Te paso un fragmento de log de PostgreSQL. Reconstruí qué ocurrió y proponé una hipótesis de contención.
```

## Respuesta recibida (transcripción literal)

> No encontré el código de fn_autenticar en el workspace, así que la hipótesis va a ser inferida solo del log. Acá va el análisis:
>
> **Reconstrucción de los hechos**
>
> Sesión única — PID 17632, usuario analista_bi, base food_store, desde ::1 con psql. Duración total: 155 ms (16:51:34.628 → .746).
>
> | Hora | Evento |
> |---|---|
> | 34.628–.648 | Conexión aceptada, autenticación scram-sha-256 y autorización OK |
> | 34.652 | SELECT current_user, session_user → reconocimiento de identidad |
> | 34.653–.664 | 6 llamadas seguidas a fn_autenticar('usuario_3@ejemplo.com', 'clave_anon_1..6'), todas fallidas, con RAISE en línea 14 |
> | 34.664 | SELECT * FROM usuario → sin error en el log (aparentemente tuvo éxito) |
> | 34.665 | GRANT admin_datos TO analista_bi → ❌ permission denied (falta WITH ADMIN OPTION) |
> | 34.668 | GRANT admin_datos TO rol_reportes → ❌ mismo error |
> | 34.668 | SET ROLE admin_datos → ❌ permission denied |
> | 34.669 | CREATE TABLE public.copia_usuario AS SELECT * FROM usuario → ❌ permission denied for schema public |
> | 34.746 | Desconexión |
>
> Lectura: es una secuencia típica de sondeo de escalada de privilegios (o un script de auditoría de seguridad corriendo en loop). Probó fuerza bruta sobre fn_autenticar, intentó auto-otorgarse el rol administrador y copiar la tabla usuario a un schema propio. Todo falló por permisos... excepto SELECT * FROM usuario, que fue permitido — eso es lo único que "pegó".
>
> Detalle importante: los fn_autenticar fallidos loguean a nivel LOG (RAISE LOG/NOTICE), no excepción, por eso la sesión continuó.
>
> **Hipótesis de contención**
>
> El patrón de 6 llamadas fallidas en ~10 ms sugiere llamadas automatizadas. Si fn_autenticar implementa un rate limiting o auditoría escribiendo (INSERT en tabla de intentos, UPDATE de un contador, o pg_advisory_lock), ese código es un cuello de botella clásico de contención:
>
> - Fila caliente: si cada intento fallido hace UPDATE contadores SET intentos = intentos + 1 WHERE id = X, todos los logins concurrentes se serializan sobre esa fila (lock row exclusive).
> - Lock advisory exclusivo: si usa pg_advisory_lock(hashtext(email)) sin ..._xact con timeout, logins concurrentes de distintos usuarios podrían quedar bloqueados unos a otros.
> - Escrituras en usuario: si hace UPDATE usuario SET intentos_fallidos = ... WHERE email = ..., genera dead tuples y HOT updates que degradan la tabla.
>
> Señales para confirmarlo (no visibles en este log):
>
> - pg_stat_activity.wait_event_type = 'Lock' / wait_event = 'relation' mientras fn_autenticar corre.
> - Deadlocks o lock timeouts en el log de otras sesiones a la misma hora.
> - pg_stat_user_tables: n_dead_tup alto, n_tup_hot_upd creciente en la tabla de usuarios.
> - Revisar el cuerpo: SELECT pg_get_functiondef('fn_autenticar'::regproc);
>
> Veredicto del log: no hay evidencia directa de contención acá (no hay esperas registradas, todo falló rápido). Lo que sí muestra el log con certeza es una escalada de privilegios bloqueada y un agujero real: analista_bi puede leer SELECT * FROM usuario. Si querés, revisá los GRANTs sobre esa tabla y el schema public.

El análisis crítico de esta respuesta está en `informe_incidente.md`, sección 5.
