-- Modelo analítico Olist (SQLite)
-- Grão principal: um registro por pedido entregue.
-- GMV = preço dos itens + frete. A base não contém comissão/receita líquida da Olist.

DROP VIEW IF EXISTS v_order_base;
DROP VIEW IF EXISTS v_order_item_base;
DROP VIEW IF EXISTS v_review_order;
DROP VIEW IF EXISTS v_payment_order;
DROP VIEW IF EXISTS v_item_order;

CREATE VIEW v_item_order AS
SELECT
    order_id,
    COUNT(*) AS item_count,
    COUNT(DISTINCT product_id) AS distinct_products,
    COUNT(DISTINCT seller_id) AS seller_count,
    SUM(price) AS product_value,
    SUM(freight_value) AS freight_value,
    SUM(price + freight_value) AS gmv
FROM order_items
GROUP BY order_id;

CREATE VIEW v_payment_order AS
SELECT
    order_id,
    COUNT(*) AS payment_count,
    COUNT(DISTINCT payment_type) AS payment_type_count,
    SUM(payment_value) AS payment_value,
    MAX(payment_installments) AS max_installments
FROM order_payments
GROUP BY order_id;

CREATE VIEW v_review_order AS
SELECT
    order_id,
    COUNT(*) AS review_count,
    AVG(review_score) AS review_score
FROM order_reviews
GROUP BY order_id;

CREATE VIEW v_order_base AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    DATE(o.order_purchase_timestamp) AS purchase_date,
    SUBSTR(o.order_purchase_timestamp, 1, 7) AS purchase_month,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    i.item_count,
    i.distinct_products,
    i.seller_count,
    i.product_value,
    i.freight_value,
    i.gmv,
    p.payment_value,
    p.payment_count,
    p.payment_type_count,
    p.max_installments,
    r.review_score,
    r.review_count,
    JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_purchase_timestamp) AS delivery_days,
    JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date) AS delay_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN DATETIME(o.order_delivered_customer_date) <= DATETIME(o.order_estimated_delivery_date) THEN 1
        ELSE 0
    END AS on_time_flag
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN v_item_order i ON i.order_id = o.order_id
LEFT JOIN v_payment_order p ON p.order_id = o.order_id
LEFT JOIN v_review_order r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered';

CREATE VIEW v_order_item_base AS
SELECT
    oi.order_id,
    oi.order_item_id,
    o.customer_unique_id,
    o.customer_state,
    o.purchase_date,
    o.purchase_month,
    oi.product_id,
    oi.seller_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS product_category,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS item_gmv
FROM order_items oi
JOIN v_order_base o ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name;

