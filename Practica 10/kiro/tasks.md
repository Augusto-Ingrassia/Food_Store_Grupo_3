# Tareas de Implementación

- [ ] **Task 1:** Crear `schema_sqlite.sql` asegurando `PRAGMA foreign_keys = ON;`, constraints `STRICT` y verificaciones de tipo (`CHECK`).
- [ ] **Task 2:** Redactar `pruebas_sqlite.sql` validando transacciones locales (COMMIT/ROLLBACK) y restricciones (ej. cantidades en 0).
- [ ] **Task 3:** Exportar tabla CSV desde PostgreSQL e importarla en SQLite como `snapshot_servidor`.
- [ ] **Task 4:** Desarrollar `semaforo.sql` utilizando agrupamiento (`GROUP BY`) y `CASE WHEN SUM(...) > 0` para determinar conflictos y rechazos.