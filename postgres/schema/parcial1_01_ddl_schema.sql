-- =========================================================
-- FOODSTORE - PostgreSQL
-- Schema definitivo
-- =========================================================

CREATE DATABASE foodstore;

-- Conectarse a la base de datos foodstore antes de ejecutar
-- el resto del script.

-- =========================================================
-- TIPOS ENUMERADOS
-- =========================================================

CREATE TYPE estado_pedido AS ENUM (
    'PENDIENTE',
    'CONFIRMADO',
    'TERMINADO',
    'CANCELADO'
);

CREATE TYPE forma_pago AS ENUM (
    'TARJETA',
    'TRANSFERENCIA',
    'EFECTIVO'
);

-- =========================================================
-- TABLA: categorias
-- =========================================================

CREATE TABLE categorias (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    eliminado   BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP WITH TIME ZONE,
    deleted_at  TIMESTAMP WITH TIME ZONE
);

-- =========================================================
-- TABLA: productos
-- =========================================================

CREATE TABLE productos (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL UNIQUE,
    precio        NUMERIC(10,2) NOT NULL,
    descripcion   TEXT,
    stock         INTEGER NOT NULL,
    imagen        VARCHAR(255),
    disponible    BOOLEAN NOT NULL DEFAULT FALSE,
    categoria_id  BIGINT NOT NULL,
    eliminado     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP WITH TIME ZONE,
    deleted_at    TIMESTAMP WITH TIME ZONE,

    CONSTRAINT chk_producto_precio
        CHECK (precio >= 0),

    CONSTRAINT chk_producto_stock
        CHECK (stock >= 0),

    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (categoria_id)
        REFERENCES categorias(id)
        ON DELETE restrict -- no se puede eliminar un producto que figure en algún detalle de pedido, porque se perdería información histórica sobre qué producto fue vendido.

);

-- =========================================================
-- TABLA: clientes
-- =========================================================

CREATE TABLE clientes (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    apellido      VARCHAR(100) NOT NULL,
    mail          VARCHAR(100) NOT NULL UNIQUE,
    celular       VARCHAR(30) NOT NULL,
    contrasenia   VARCHAR(255) NOT NULL,
    rol           VARCHAR(50) NOT NULL,
    eliminado     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP WITH TIME ZONE,
    deleted_at    TIMESTAMP WITH TIME ZONE,

    CONSTRAINT chk_cliente_mail
        CHECK (POSITION('@' IN mail) > 1)
);

-- =========================================================
-- TABLA: pedidos
-- =========================================================

CREATE TABLE pedidos (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado        estado_pedido NOT NULL DEFAULT 'PENDIENTE',
    total         NUMERIC(12,2) NOT NULL DEFAULT 0,
    forma_pago    forma_pago NOT NULL DEFAULT 'EFECTIVO',
    cliente_id    BIGINT NOT NULL,
    eliminado     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP WITH TIME ZONE,
    deleted_at    TIMESTAMP WITH TIME ZONE,

    CONSTRAINT chk_pedido_total
        CHECK (total >= 0),

    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (cliente_id)
        REFERENCES clientes(id)
        ON DELETE restrict -- no se puede eliminar un pedido si tiene detalles asociados. Esto evita que queden registros de productos vendidos sin un pedido al que pertenezcan.

);

-- =========================================================
-- TABLA: detalle_pedido
-- Tabla intermedia entre pedidos y productos (N:M)
-- =========================================================

CREATE TABLE detalle_pedido (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id        BIGINT NOT NULL,
    producto_id      BIGINT NOT NULL,
    cantidad         INTEGER NOT NULL,
    precio_unitario  NUMERIC(10,2) NOT NULL,
    subtotal         NUMERIC(12,2) NOT NULL,

    CONSTRAINT chk_detalle_cantidad
        CHECK (cantidad > 0),

    CONSTRAINT chk_detalle_precio
        CHECK (precio_unitario >= 0),

    CONSTRAINT chk_detalle_subtotal
        CHECK (subtotal >= 0),

    CONSTRAINT fk_detalle_pedido
        FOREIGN KEY (pedido_id)
        REFERENCES pedidos(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (producto_id)
        REFERENCES productos(id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_detalle_pedido_producto
        UNIQUE (pedido_id, producto_id)
); 
