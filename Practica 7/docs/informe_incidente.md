# Parte C — Informe del simulacro de incidente de acceso indebido

Entorno: PostgreSQL 17 local del equipo, base `food_store` (desarrollo propio).
Fecha de ejecución: 2026-10-05, 16:51:34 (-03).
Script: `sql/simulacro_incidente.sql`.

## 1. Escenario ejecutado (punto 1)

El script corre en tres secciones:

1. **Precondiciones (como `postgres`)**
   - Se activa la auditoría con `ALTER SYSTEM` y `pg_reload_conf()`, sin reiniciar el servidor:
     - `log_connections = on`
     - `log_disconnections = on`
     - `log_statement = 'all'`
     - `log_line_prefix = '%m [%p] %q%u@%d %r '`
   - Se usa `'all'` y no `'mod'`. Con `'mod'`, los `SELECT` no quedan registrados: ni los intentos de login ni la lectura masiva.
   - Se reconstruye `fn_autenticar` (Clase 2), que no estaba en el repositorio:
     - Es `SECURITY DEFINER` y tiene `search_path` fijo.
     - Registra cada intento fallido con `RAISE LOG`.
   - Se crea el login temporal `analista_bi`. Pertenece solo a `rol_reportes`, que es de solo lectura. Simula una credencial de bajo privilegio comprometida.
2. **Sesión del atacante (como `analista_bi`)**
   - 5 llamadas a `fn_autenticar` con contraseñas incorrectas contra la cuenta ADMIN de la aplicación.
   - 1 llamada con la contraseña correcta, que devuelve `t`.
   - `SELECT * FROM usuario`: lectura masiva.
   - 4 intentos de escalamiento:
     - `GRANT admin_datos TO analista_bi`
     - `GRANT admin_datos TO rol_reportes`
     - `SET ROLE admin_datos`
     - `CREATE TABLE public.copia_usuario AS SELECT * FROM usuario`: operación reservada a `admin_datos`.
3. **Verificación y limpieza (como `postgres`)**
   - Se consulta `pg_has_role` y se comprueba que la tabla no exista.
   - Se elimina el rol temporal.

## 2. ¿Falló el escalamiento? (punto 2)

**Sí. Los cuatro intentos fallaron.** No hay hallazgo que corregir en el modelo de membresías de la Parte A.

| Intento | Resultado |
|---|---|
| `GRANT admin_datos TO analista_bi` | `ERROR: permission denied to grant role "admin_datos"` |
| `GRANT admin_datos TO rol_reportes` | `ERROR: permission denied to grant role "admin_datos"` |
| `SET ROLE admin_datos` | `ERROR: permission denied to set role "admin_datos"` |
| `CREATE TABLE public.copia_usuario ...` | `ERROR: permission denied for schema public` |

Verificación posterior, ejecutada como `postgres`:

```
     rol      | es_miembro_admin_datos
--------------+------------------------
 rol_reportes | f
 analista_bi  | f

 copia_usuario_existe
----------------------
 f
```

**Hallazgo colateral sobre la Parte A.** No es escalamiento, pero es grave. La lectura masiva **sí funcionó** y devolvió la columna `contrasena` de todos los usuarios, **en texto plano**. Sale del `GRANT SELECT ON TABLE usuario TO rol_reportes` de `roles.sql`. El `design.md` ya advertía este riesgo ("las herramientas de BI deben acceder únicamente a través de las vistas"), pero el permiso quedó otorgado sobre la tabla completa. Ver la corrección propuesta en la sección 6.

## 3. Extracción y anonimización del log (punto 3)

- Se tomaron del log del servidor (`log/postgresql-2026-10-05_164453.log`) solo las líneas de la sesión del atacante, PID `17632`.
- No se incluyen las líneas de preparación y limpieza ejecutadas por `postgres`. Revelarían que se trataba de un simulacro y agregarían contexto que el log del incidente no tiene.

Reemplazos aplicados (criterio determinista por `id`, el mismo de `usuario_anon`):

| Dato real | Valor sintético |
|---|---|
| Mail de la cuenta atacada (usuario id 3) | `usuario_3@ejemplo.com` |
| Contraseñas probadas, en orden (incluida la correcta) | `clave_anon_1` … `clave_anon_6` |

Comando utilizado:

```bash
grep "\[17632\]" postgresql-2026-10-05_164453.log | sed \
  -e "s/<mail_real>/usuario_3@ejemplo.com/g" \
  -e "s/'<clave_1>'/'clave_anon_1'/g" ... -e "s/'<clave_6>'/'clave_anon_6'/g" \
  > docs/log_simulacro_anonimizado.txt
```

- Después se verificó con `grep` que no quedara ningún mail, contraseña, nombre ni hash real: 0 coincidencias.
- No se anonimizaron los nombres de roles, de base, el PID ni la IP `::1`. Son datos técnicos, no personales, y hacen falta para reconstruir el incidente.

Resultado: `docs/log_simulacro_anonimizado.txt` (41 líneas).

## 4. Entrega a la IA (punto 4)

- Prompt enviado a OpenCode: *"Te paso un fragmento de log de PostgreSQL. Reconstruí qué ocurrió y proponé una hipótesis de contención."*, seguido del log completo.
- Respuesta completa: `docs/respuesta_ia_simulacro.md`.

## 5. Contraste entre la reconstrucción de la IA y lo ejecutado (punto 5)

### Qué acertó

- Sesión única: PID 17632, usuario `analista_bi`, origen `::1`, cliente `psql`, duración 155 ms.
- El ritmo de los eventos indica ejecución automatizada (script) y no tipeo manual.
- Los cuatro intentos de escalamiento fallaron, con la causa correcta de cada error.
- `SELECT * FROM usuario` no registró error y es "lo único que pegó". Es correcto, y la IA fue prudente al decir "aparentemente": el log no muestra filas ni resultado.
- Detecta el permiso excesivo de lectura sobre `usuario`.

### Qué afirmó sin sustento o directamente en contra del log

1. **"6 llamadas ... todas fallidas". Es el error más importante.** El log tiene **5** líneas `fn_autenticar: intento fallido` y la sexta llamada (`clave_anon_6`, 34.664) **no tiene ninguna**. La función solo registra los fallos, así que la ausencia de esa línea es justamente la señal de que el sexto intento **tuvo éxito**. Es lo que se ejecutó: la contraseña correcta, que devolvió `t`. La IA no contó bien las líneas y se le pasó el único dato que convierte un intento de fuerza bruta en una **cuenta ADMIN comprometida**.
2. **Interpretó "contención" como contención de locks** (filas calientes, `pg_advisory_lock`, dead tuples) y no como contención de un incidente de seguridad. Toda esa sección es especulación sobre un código que no vio ("si fn_autenticar implementa…"). La propia IA termina admitiendo que "no hay evidencia directa de contención acá". No propone ninguna medida para frenar el incidente.
3. **"copiar la tabla usuario a un schema propio"**: falso. El destino era `public.copia_usuario`, el esquema `public`, no un esquema propio.
4. **"o un script de auditoría de seguridad corriendo en loop"**: el log no muestra ningún loop. Hay una sola pasada, con seis contraseñas distintas y en orden.
5. **"RAISE LOG/NOTICE"**: el log muestra explícitamente nivel `LOG`. Lo de `NOTICE` es una conjetura innecesaria.

### Qué omitió

- **El login exitoso** del punto anterior, y por lo tanto que la cuenta `usuario_3` (ADMIN de la aplicación) quedó comprometida.
- **La distinción entre los dos "logins"**:
  - `analista_bi` se autenticó **en el motor** al primer intento, con SCRAM.
  - La fuerza bruta fue contra el login **de la aplicación** (`fn_autenticar`).
  - O sea que la credencial de base de datos ya estaba en manos del atacante. Ese es el origen real del incidente, y la IA no lo señala.
- **La exposición de credenciales en el propio log**: con `log_statement = 'all'`, cada contraseña probada queda escrita en texto plano en el log del servidor. En el original la contraseña correcta de la cuenta ADMIN está escrita ahí.
- **Que el origen es `::1` (localhost)**: el atacante operó desde el propio servidor o a través de un túnel. "Bloquear la IP" no sirve como medida.
- **El orden lógico del ataque**: comprueba identidad, prueba contraseñas, lee datos y recién después intenta escalar.

### Un comportamiento a tener en cuenta

La IA abrió su respuesta con "No encontré el código de fn_autenticar en el workspace". Es decir, **buscó contexto por su cuenta en el repositorio**, aunque la consigna pedía que no tuviera otro contexto que el log. No lo encontró, pero si hubiera leído `sql/simulacro_incidente.sql`, la "reconstrucción" habría salido del script y no del log. Para repetir la prueba, conviene correr OpenCode en un directorio vacío.

## 6. Decisión de contención del equipo (punto 6)

**Esta decisión es del equipo.** La tomamos a partir de la evidencia del log y de la verificación con `pg_has_role`. No es una acción ejecutada automáticamente a partir de lo que sugirió la IA. La única propuesta de la IA (revisar posibles locks) **se descartó** porque no tiene sustento en el log.

En un caso real haríamos, en este orden:

1. **Cortar la credencial de base de datos comprometida**, porque el atacante ya la tenía (autenticación SCRAM exitosa al primer intento):
   ```sql
   ALTER ROLE analista_bi NOLOGIN;
   SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = 'analista_bi';
   ```
   Después, rotar su contraseña e investigar cómo se filtró.
2. **Forzar el cambio de contraseña de la cuenta ADMIN de la aplicación (`usuario_3`)**: el sexto intento tuvo éxito.
3. **Forzar el cambio de contraseña de *todos* los usuarios de la aplicación.** El `SELECT * FROM usuario` se completó sin error y la columna `contrasena` está en texto plano, así que hay que tratarlas todas como expuestas.
4. **Corregir el permiso que permitió la fuga** (defecto de la Parte A):
   ```sql
   REVOKE SELECT ON TABLE usuario FROM rol_reportes;
   GRANT SELECT (id, nombre, apellido, mail, celular, rol, eliminado, created_at)
       ON TABLE usuario TO rol_reportes;
   ```
5. **No hace falta revertir ningún rol.** El escalamiento falló y `pg_has_role` confirma que nadie quedó como miembro de `admin_datos`.
6. **No bloquear el origen por IP.** Es `::1`: el acceso fue local. Se revisa quién tiene acceso al host del servidor.
7. **Proteger el log del servidor** como evidencia y como activo sensible: contiene contraseñas en texto plano por `log_statement = 'all'`. Se copia con permisos restringidos para la investigación y después se depura.

Mejoras posteriores, que no son parte de la contención inmediata:

- Guardar las contraseñas con hash (`pgcrypto`).
- Agregar a `fn_autenticar` un límite de intentos por cuenta y el registro de los éxitos.
- Quitar `EXECUTE` sobre `fn_autenticar` a cualquier rol que no sea `app_web`.
- Volver `log_statement` a `'mod'` en producción y registrar los logins desde la función, sin exponer parámetros.
