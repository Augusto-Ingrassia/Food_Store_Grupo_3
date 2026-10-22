# Informe post-incidente — TP Unidad 6: simulacro de restauración

**Fecha del simulacro:** 2026-10-22, 02:10:14 (-03). **Entorno:** servidor PostgreSQL 18.6 descartable (`localhost:5499`) con la base `food_store` cargada desde `schema.sql`, `objects.sql` y `data.sql`. La restauración se hizo en `foodstore_restore_test`; la base principal no se eliminó ni se reemplazó.

## 1. Respaldo utilizado

`backups/foodstore_20261022_021004.dump`: generado el **2026-10-22 a las 02:10:04** por `backup_foodstore.ps1` (formato custom, 22.063 bytes, log en `logs/backup_log.txt`). Las filas registradas antes del respaldo quedaron en `backups/foodstore_20261022_021004.conteo.txt`.

## 2. RPO y RTO

| Indicador | Qué mide | Previsto (`SPEC_U6.md`) | Observado |
|---|---|---|---|
| **RTO** | Tiempo hasta volver a tener la base operativa: `createdb` + `pg_restore` + validaciones | ≤ 10 min | **0,99 s** |
| **RPO** | Datos que se pierden: antigüedad del respaldo al iniciar el simulacro | ≤ 24 h | **11 s** |

Para que el RPO se viera en los datos, a las 02:10:14 (después del respaldo) se creó un pedido en `food_store`. El origen quedó con 3 pedidos y 6 detalles, y la base restaurada tiene 2 pedidos y 4 detalles: ese pedido es la pérdida observada. Con el respaldo diario del plan, la pérdida puede llegar a un día completo de pedidos. El RTO de 1 s corresponde a una base de 22 KB restaurada por script; una base real o una restauración manual tardarían bastante más. Una segunda ejecución (02:10:42) confirmó que el script se puede repetir cada semana: 0,54 s.

## 3. Validaciones (`validacion_restore.sql` sobre `foodstore_restore_test`)

| categoria | usuario | producto | pedido | detalle_pedido | productos inválidos | detalles inválidos |
|---|---|---|---|---|---|---|
| 3 = 3 | 3 = 3 | 4 = 4 | 2 = 2 | 4 = 4 | 0 | 0 |

Todas las filas coinciden con las registradas antes del respaldo y los controles lógicos dan 0. También se restauraron todos los objetos, igual que en el origen: 5 tablas, 4 vistas, 4 funciones/procedimientos, 3 triggers y 11 índices. `v_pedidos_resumen` devuelve los 2 pedidos con totales de 4400 y 3900. El enunciado cuenta la tabla `cliente`; en Food Store esa tabla es `usuario`. Evidencias en `logs/restore_test_log.txt` y `logs/evidencia_simulacro.txt`.

## 4. Problema real encontrado

Los 6 respaldos del 14/10 (`foodstore_20261014_*.dump`) que estaban en el repositorio **pesaban 0 bytes** y el log estaba vacío: no había ningún respaldo restaurable. Reprodujimos la causa: `pg_dump` crea el archivo de salida antes de conectarse, así que si la conexión falla (por contraseña, base o puerto) queda un `.dump` vacío. El script registraba el error, pero el archivo quedaba y parecía un respaldo válido, y el simulacro lo habría tomado como "último respaldo". Corrección: `backup_foodstore.ps1` ahora borra el `.dump` cuando falla (probado con una base inexistente: termina con código 1 y no deja ningún archivo), y `restore_test.ps1` ignora los archivos vacíos. Se eliminaron los 6 archivos vacíos. También se detectó un problema secundario: al cargar `data.sql` con psql en Windows, los acentos se guardaron mal ("PÃ©rez") porque psql usó la codificación de la consola. Se resolvió con `PGCLIENTENCODING=UTF8`.

## 5. Mejora para la próxima ejecución

Programar `backup_foodstore.ps1` (diario) y `restore_test.ps1` (semanal) en el Programador de tareas de Windows, con un aviso cuando terminen con código 1. Los respaldos vacíos pasaron una semana sin que nadie lo notara porque el error solo quedaba en el log. Con el aviso se detectaría el mismo día, y el ensayo semanal automático confirmaría que el último respaldo se puede restaurar.

## 6. Asistencia de IA y verificación

La corrección de `backup_foodstore.ps1`, `restore_test.ps1`, `validacion_restore.sql` y la redacción de este informe se hicieron con asistencia de IA (Claude Code; la consigna sugiere OpenCode). La IA detectó los respaldos vacíos y propuso las correcciones. El equipo decidió usar un servidor descartable, corregir el script y borrar los archivos vacíos. Nada se aceptó sin ejecutarlo: se probó el camino de error del respaldo, se reprodujo la causa con `pg_dump` contra una base inexistente, se corrió la restauración dos veces y los conteos se contrastaron con consultas directas (`logs/evidencia_simulacro.txt`).
