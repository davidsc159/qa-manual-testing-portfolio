-- ============================================================================
-- PROYECTO: QA DATABASE INTEGRITY & DATA VALIDATION SUITE
-- Archivo: 02_qa_validation_queries.sql
-- Objetivo: Consultas de auditoría de datos, integridad referencial y
--           detección de anomalías para aseguramiento de calidad (QA).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CONSULTA 1: Validación de Unicidad (Duplicados)
-- Regla de Negocio: Ningún correo electrónico debe registrarse más de una vez.
-- Criterio QA: Si el resultado retorna filas, existe una falla de integridad de datos.
-- ----------------------------------------------------------------------------
SELECT 
    email, 
    COUNT(*) AS total_duplicados,
    GROUP_CONCAT(username, ', ') AS usuarios_asociados
FROM users
GROUP BY email
HAVING COUNT(*) > 1;


-- ----------------------------------------------------------------------------
-- CONSULTA 2: Integridad Referencial - Detección de Ítems Huérfanos
-- Regla de Negocio: Todo ítem de una orden debe apuntar a un producto existente en catálogo.
-- Criterio QA: El LEFT JOIN busca registros en 'order_items' cuyo 'product_id' no existe en 'products'.
-- ----------------------------------------------------------------------------
SELECT 
    oi.item_id,
    oi.order_id,
    oi.product_id AS id_producto_invalido,
    oi.quantity,
    oi.unit_price
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- ----------------------------------------------------------------------------
-- CONSULTA 3: Consistencia Financiera - Auditoría de Cuadre de Órdenes
-- Regla de Negocio: El 'total_amount' de la cabecera de la orden debe coincidir exactamente
--                   con la sumatoria de (cantidad * precio_unitario) de sus ítems asociados.
-- Criterio QA: Detecta discrepancias de redondeo, manipulación indebida o fallos de cálculo.
-- ----------------------------------------------------------------------------
SELECT 
    o.order_id,
    o.total_amount AS total_registrado_en_orden,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS total_calculado_de_items,
    ROUND(o.total_amount - SUM(oi.quantity * oi.unit_price), 2) AS discrepancia
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING ROUND(o.total_amount, 2) != ROUND(SUM(oi.quantity * oi.unit_price), 2);


-- ----------------------------------------------------------------------------
-- CONSULTA 4: Validación de Reglas de Negocio en Estados de Transacción
-- Regla de Negocio: Una orden con estado 'DELIVERED' (Entregada) DEBE tener obligatoriamente
--                   registrada la fecha de entrega ('delivered_at' NO NULL).
-- Criterio QA: Detecta transacciones incompletas o transiciones de estado anómalas.
-- ----------------------------------------------------------------------------
SELECT 
    order_id,
    user_id,
    order_date,
    status,
    total_amount,
    delivered_at
FROM orders
WHERE status = 'DELIVERED' 
  AND delivered_at IS NULL;


-- ----------------------------------------------------------------------------
-- CONSULTA 5: Validación de Restricciones de Dominio y Valores Límite
-- Regla de Negocio: Ningún producto puede tener precio <= 0 ni stock < 0 (sobreventa).
-- Criterio QA: Valida directamente el defecto BUG-003 (stock negativo por condición de carrera).
-- ----------------------------------------------------------------------------
SELECT 
    product_id,
    name,
    price,
    stock,
    CASE 
        WHEN stock < 0 THEN 'FALLA CRÍTICA: Stock negativo (Sobreventa)'
        WHEN price <= 0 THEN 'FALLA: Precio menor o igual a cero'
        ELSE 'OK'
    END AS tipo_de_anomalia
FROM products
WHERE stock < 0 OR price <= 0;


-- ----------------------------------------------------------------------------
-- CONSULTA 6: Integridad Referencial - Órdenes sin Cliente Asignado
-- Regla de Negocio: Toda orden debe estar asociada a un usuario válido registrado.
-- Criterio QA: Detecta registros huérfanos generados por sesiones corruptas o compras anónimas sin ID.
-- ----------------------------------------------------------------------------
SELECT 
    order_id,
    order_date,
    total_amount,
    status
FROM orders
WHERE user_id IS NULL;


-- ----------------------------------------------------------------------------
-- CONSULTA 7: Cruce Relacional Complejo (Multi-Table JOIN) para Auditoría Consolidada
-- Objetivo: Generar la vista 360° de pedidos cruzando usuarios, órdenes, ítems y categorías.
-- Criterio QA: Prueba la capacidad de análisis y trazabilidad end-to-end en la base de datos.
-- ----------------------------------------------------------------------------
SELECT 
    o.order_id,
    o.order_date,
    COALESCE(u.username, 'SIN_USUARIO') AS cliente,
    COALESCE(u.email, 'N/A') AS email_cliente,
    c.name AS categoria_producto,
    COALESCE(p.name, 'PRODUCTO_INEXISTENTE') AS producto,
    oi.quantity AS cantidad,
    oi.unit_price AS precio_unitario,
    ROUND(oi.quantity * oi.unit_price, 2) AS subtotal_linea,
    o.status AS estado_orden
FROM orders o
LEFT JOIN users u ON o.user_id = u.user_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN categories c ON p.category_id = c.category_id
ORDER BY o.order_id ASC, oi.item_id ASC;
