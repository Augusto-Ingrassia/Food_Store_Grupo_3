-- =====================================================================
-- TP Unidad 4 - Parte 1: FNBC sobre control_lote_almacen
-- =====================================================================
-- Dependencias funcionales (b, c en el informe):
--   FD1: {lote_id, deposito_id} -> responsable_control_id
--   FD2: responsable_control_id -> deposito_id
-- Claves candidatas: {lote_id, deposito_id} y {lote_id, responsable_control_id}
-- (todos los atributos son primos). Viola FNBC por FD2: responsable_control_id
-- no es superclave (su clausura es {responsable_control_id, deposito_id}).
-- Detalle completo de clausuras y anomalias: ver informe.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Tablas maestras que la consigna asume preexistentes (lote, deposito),
--    igual que 'sucursal' se asumio existente en AsignacionEntrega.
--    Se crean minimamente aca solo para que este script sea autoejecutable
--    contra la base de Food Store; no son objeto de analisis de este TP.
-- ---------------------------------------------------------------------
CREATE TABLE lote (
    id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

CREATE TABLE deposito (
    id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

INSERT INTO lote (id) OVERRIDING SYSTEM VALUE VALUES (501), (502), (503);
INSERT INTO deposito (id) OVERRIDING SYSTEM VALUE VALUES (30), (31);

-- ---------------------------------------------------------------------
-- 1. Esquema original + instancia de ejemplo (tal cual la consigna)
-- ---------------------------------------------------------------------
CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- ---------------------------------------------------------------------
-- 2. Descomposicion sin perdida (algoritmo BCNF sobre FD2: R -> D)
--    R1 = clausura(R) = {responsable_control_id, deposito_id}
--    R2 = todos - (clausura(R) - R) = {lote_id, responsable_control_id}
-- ---------------------------------------------------------------------
CREATE TABLE responsable_control_deposito (
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    PRIMARY KEY (responsable_control_id)
);

CREATE TABLE control_lote (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id  BIGINT NOT NULL
                            REFERENCES responsable_control_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);
-- responsable_control_id ya queda validado contra usuario(id) de forma
-- transitiva, porque responsable_control_deposito.responsable_control_id
-- referencia a usuario(id).

-- ---------------------------------------------------------------------
-- 3. Vista de compatibilidad: reconstruye control_lote_almacen
--    mediante reunion natural sobre responsable_control_id.
--    Sin perdida porque responsable_control_id es clave (PK) de
--    responsable_control_deposito, es decir superclave del atributo
--    comun entre ambas tablas descompuestas.
-- ---------------------------------------------------------------------
CREATE VIEW v_control_lote_almacen AS
SELECT cl.lote_id,
       rcd.deposito_id,
       cl.responsable_control_id
FROM control_lote cl
JOIN responsable_control_deposito rcd
  ON rcd.responsable_control_id = cl.responsable_control_id;

-- ---------------------------------------------------------------------
-- 4. Migracion de datos de la instancia de ejemplo
-- ---------------------------------------------------------------------
INSERT INTO responsable_control_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen;

INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id
FROM control_lote_almacen;

-- ---------------------------------------------------------------------
-- 5. Verificacion de equivalencia (debe devolver 0 filas de diferencia)
-- ---------------------------------------------------------------------
(SELECT * FROM control_lote_almacen
 EXCEPT
 SELECT * FROM v_control_lote_almacen)
UNION ALL
(SELECT * FROM v_control_lote_almacen
 EXCEPT
 SELECT * FROM control_lote_almacen);
