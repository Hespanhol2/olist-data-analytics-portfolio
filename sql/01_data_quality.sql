-- Validações que evitam conclusões incorretas por duplicação de grão.
SELECT 'orders' AS check_name, COUNT(*) AS row_count, COUNT(DISTINCT order_id) AS distinct_keys
FROM orders
UNION ALL
SELECT 'customers', COUNT(*), COUNT(DISTINCT customer_id)
FROM customers
UNION ALL
SELECT 'products', COUNT(*), COUNT(DISTINCT product_id)
FROM products
UNION ALL
SELECT 'sellers', COUNT(*), COUNT(DISTINCT seller_id)
FROM sellers;

-- A diferença pequena entre pagamentos e itens pode incluir vouchers e ajustes.
SELECT
    ROUND(SUM(gmv), 2) AS item_gmv,
    ROUND(SUM(payment_value), 2) AS payment_value,
    ROUND(SUM(payment_value) - SUM(gmv), 2) AS reconciliation_difference
FROM v_order_base;

