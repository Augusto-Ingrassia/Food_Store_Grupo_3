-- 1. Creación de Tipos Enumerados
CREATE TYPE rol AS ENUM ('ADMIN','USUARIO');
CREATE TYPE estado_pedido AS ENUM ('PENDIENTE','CONFIRMADO', 'TERMINADO','CANCELADO');
CREATE TYPE forma_pago AS ENUM ('TARJETA','TRANSFERENCIA','EFECTIVO');

-- 2. Creación de Tabla Categoria
CREATE TABLE categoria (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- Error BIGGINT corregido
    nombre      VARCHAR(80)  NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    eliminado   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- 3. Creación de Tabla Producto
CREATE TABLE producto (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(120) NOT NULL,
    precio       NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    descripcion  VARCHAR(255),
    stock        INTEGER      NOT NULL DEFAULT 0 CHECK (stock >= 0),
    imagen       VARCHAR(255),
    disponible   BOOLEAN      NOT NULL DEFAULT TRUE,
    categoria_id BIGINT       NOT NULL REFERENCES categoria(id),
    eliminado    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- 4. Creación de Tabla Usuario
CREATE TABLE usuario (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL,
    apellido    VARCHAR(80)  NOT NULL,
    mail        VARCHAR(120) NOT NULL UNIQUE,
    celular     VARCHAR(30),
    contrasena  VARCHAR(255) NOT NULL,
    rol         rol          NOT NULL DEFAULT 'USUARIO',
    eliminado   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- 5. Creación de Tabla Pedido
CREATE TABLE pedido (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha      DATE          NOT NULL DEFAULT CURRENT_DATE,
    estado     estado_pedido NOT NULL DEFAULT 'PENDIENTE',
    total      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    forma_pago forma_pago    NOT NULL,
    usuario_id BIGINT        NOT NULL REFERENCES usuario(id),
    eliminado  BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- 6. Creación de Tabla Detalle_Pedido
CREATE TABLE detalle_pedido (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal        NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    pedido_id       BIGINT        NOT NULL REFERENCES pedido(id) ON DELETE RESTRICT,
    producto_id     BIGINT        NOT NULL REFERENCES producto(id),
    eliminado       BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    UNIQUE (pedido_id, producto_id)
);

-- Índice para soportar el listado de productos por categoría
CREATE INDEX idx_producto_categoria ON producto(categoria_id);

-- Índice para soportar el historial de pedidos por usuario
CREATE INDEX idx_pedido_usuario ON pedido(usuario_id);

-- Índice parcial sobre filas no eliminadas (ejemplo sobre el nombre del producto)
CREATE INDEX idx_producto_nombre_vigente ON producto(nombre) WHERE eliminado = FALSE;

-- 7. Constraints CHECK adicionales
ALTER TABLE detalle_pedido
  DROP CONSTRAINT detalle_pedido_precio_unitario_check,
  ADD CONSTRAINT detalle_pedido_precio_unitario_check CHECK (precio_unitario > 0);

ALTER TABLE producto
  ADD CONSTRAINT chk_producto_stock_si_disponible
  CHECK (disponible = FALSE OR stock > 0);

-- Trabajo 2 Parte 1:
ALTER TABLE detalle_pedido DROP CONSTRAINT IF EXISTS detalle_pedido_precio_unitario_check;
ALTER TABLE detalle_pedido ADD CONSTRAINT detalle_pedido_precio_unitario_check CHECK (precio_unitario > 0);

ALTER TABLE producto DROP CONSTRAINT IF EXISTS chk_producto_stock_si_disponible;
ALTER TABLE producto ADD CONSTRAINT chk_producto_stock_si_disponible CHECK (disponible = FALSE OR stock > 0);
