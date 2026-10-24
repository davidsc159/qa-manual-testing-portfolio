-- ============================================================================
-- PROYECTO: QA DATABASE INTEGRITY & DATA VALIDATION SUITE
-- Archivo: 01_schema_and_mock_data.sql
-- Motor compatible: SQLite 3 / PostgreSQL 14+ / MySQL 8+
-- ============================================================================

-- 1. Eliminación de tablas previas (Limpieza)
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;

-- 2. Creación de Tablas Principales
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'ACTIVE',
    created_at DATE NOT NULL
);

CREATE TABLE categories (
    category_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(50) NOT NULL
);

CREATE TABLE products (
    product_id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    order_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL, -- PENDING, COMPLETED, DELIVERED, CANCELLED
    total_amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(30),
    delivered_at DATE,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE order_items (
    item_id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id INTEGER NOT NULL,
    product_id INTEGER,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ============================================================================
-- 3. Inserción de Datos Mock (Con anomalías controladas para pruebas de QA)
-- ============================================================================

-- Categorías
INSERT INTO categories (category_id, name) VALUES
(1, 'Accesorios'),
(2, 'Ropa y Calzado'),
(3, 'Equipamiento Deportivo');

-- Usuarios (Nota QA: Hay un correo duplicado deliberado para probar validación)
INSERT INTO users (user_id, username, email, status, created_at) VALUES
(1, 'standard_user', 'erick.tester@example.com', 'ACTIVE', '2026-01-15'),
(2, 'locked_out_user', 'locked@example.com', 'SUSPENDED', '2026-02-10'),
(3, 'problem_user', 'problem@example.com', 'ACTIVE', '2026-03-05'),
(4, 'carlos_gomez', 'carlos.gomez@empresa.pe', 'ACTIVE', '2026-03-20'),
(5, 'carlos_duplicado', 'carlos.gomez@empresa.pe', 'ACTIVE', '2026-04-01'), -- ANOMALÍA: Email duplicado
(6, 'usuario_inactivo', 'inactivo@example.com', 'ACTIVE', '2025-10-01');     -- ANOMALÍA: Usuario sin órdenes

-- Catálogo de Productos
INSERT INTO products (product_id, category_id, name, price, stock) VALUES
(101, 1, 'Sauce Labs Backpack', 29.99, 15),
(102, 1, 'Sauce Labs Bike Light', 9.99, 25),
(103, 2, 'Sauce Labs Bolt T-Shirt', 15.99, 40),
(104, 2, 'Sauce Labs Fleece Jacket', 49.99, -1), -- ANOMALÍA (BUG-003): Stock negativo por sobreventa
(105, 3, 'Sauce Labs Onesie', 7.99, 10),
(106, 2, 'Test.allTheThings() T-Shirt', -5.00, 5); -- ANOMALÍA: Precio negativo inválido

-- Órdenes
INSERT INTO orders (order_id, user_id, order_date, status, total_amount, payment_method, delivered_at) VALUES
(1001, 1, '2026-04-10', 'DELIVERED', 39.98, 'CREDIT_CARD', '2026-04-12'), -- OK
(1002, 1, '2026-04-15', 'DELIVERED', 49.99, 'PAYPAL', NULL),              -- ANOMALÍA: Estado DELIVERED sin delivered_at
(1003, 4, '2026-04-16', 'PENDING', 75.00, 'DEBIT_CARD', NULL),              -- ANOMALÍA: Descuadre de monto (Total 75.00 vs Ítems 45.98)
(1004, 3, '2026-04-18', 'COMPLETED', 29.99, 'CREDIT_CARD', '2026-04-20'),
(1005, NULL, '2026-04-22', 'PENDING', 9.99, 'CREDIT_CARD', NULL);          -- ANOMALÍA: Orden huérfana (sin user_id)

-- Líneas de Orden (Order Items)
INSERT INTO order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
-- Para Orden 1001 (Total real: 29.99 + 9.99 = 39.98) -> Cuadra exacto
(1, 1001, 101, 1, 29.99),
(2, 1001, 102, 1, 9.99),

-- Para Orden 1002 (Total real: 49.99)
(3, 1002, 104, 1, 49.99),

-- Para Orden 1003 (Total real: 29.99 + 15.99 = 45.98, pero la orden declara 75.00) -> Descuadre
(4, 1003, 101, 1, 29.99),
(5, 1003, 103, 1, 15.99),

-- Para Orden 1004
(6, 1004, 101, 1, 29.99),

-- Para Orden 1005 (Ítem huérfano: apunta a producto 999 que NO existe)
(7, 1005, 999, 1, 9.99);
