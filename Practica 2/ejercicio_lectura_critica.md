# Ejercicio de Lectura Crítica — Parte 3: Concurrencia

---

## Script 1

### Problema identificado

El `UPDATE` original no tiene cláusula `WHERE`, por lo que afecta todas las filas de la tabla sin distinción. Independientemente de si una función está activa o no, o si su película fue retirada, todas quedarán con `activa = FALSE`. Es un error silencioso: la sentencia ejecuta sin error pero produce un efecto destructivo e irreversible sobre los datos.

### Versión corregida

```
UPDATE funcion
SET activa = FALSE
WHERE pelicula_id IN (
    SELECT id
    FROM pelicula
    WHERE estado = 'retirada'
);
```

El `WHERE` restringe la actualización únicamente a las funciones cuya película asociada tiene estado `'retirada'`, que es el comportamiento esperado.

---

## Script 2

### Problema identificado

El `NOT IN` falla silenciosamente cuando la subconsulta devuelve **algún valor `NULL`**. En SQL, cualquier comparación con `NULL` produce `UNKNOWN`, no `TRUE` ni `FALSE`. Como resultado, la condición `NOT IN` nunca se evalúa como verdadera y el `DELETE` **no borra ninguna fila**, aunque existan categorías sin productos asociados. Es un bug difícil de detectar porque la sentencia ejecuta sin errores y sin advertencias.

### Versión corregida

```
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.categoria_id = c.id
);
```

`NOT EXISTS` evalúa si la subconsulta retorna alguna fila, sin importar si hay `NULL`s de por medio. Si no existe ningún producto que referencie la categoría, la condición es verdadera y la fila se elimina. Es la forma correcta y segura de expresar "sin registros relacionados".