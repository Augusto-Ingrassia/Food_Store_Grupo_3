# Bitácora de Uso de IA

| Fecha | Prompt / Consulta a la IA | Decisión | Motivo / Ajuste |
| :--- | :--- | :--- | :--- |
| 05/11/2026 | "Generar script SQLite para las 4 tablas solicitadas en la consigna 1.b con modo STRICT." | **Aceptado (con ajustes)** | La IA generó las tablas bien, pero omitió agregar `PRAGMA foreign_keys = ON;` al inicio del script. Lo agregué manualmente para que las FK funcionen. |
| 05/11/2026 | "Escribir la consulta del semáforo para evaluar conflictos comparando `item_borrador` con `snapshot_servidor`." | **Corregido** | La IA sugirió actualizar fila por fila con subconsultas correlacionadas muy complejas. Lo corregí agrupando por solicitud y usando la estructura `CASE WHEN SUM(...) > 0` recomendada por el apunte para hacerlo eficiente. |
| 05/11/2026 | "Cómo evitar que se duplique una solicitud en SQLite si se reenvía el mismo UUID (Caso C6)." | **Descartado** | La IA propuso crear un `TRIGGER` que lance una excepción antes del `INSERT`. Lo descarté porque la columna `solicitud_uuid` ya es `PRIMARY KEY` en `cola_sync`, por lo que el motor rechaza el duplicado naturalmente sin necesidad de un trigger. |