-- Fato de pedidos: um registro por pedido entregue.
-- GMV = preço dos produtos + frete; não representa receita líquida da Olist.
CREATE MATERIALIZED VIEW analytics.fact_orders AS
WITH item_order AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(DISTINCT product_id) AS distinct_products,
        COUNT(DISTINCT seller_id) AS seller_count,
        SUM(price) AS product_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS gmv
    FROM raw.order_items
    GROUP BY order_id
), payment_order AS (
    SELECT
        order_id,
        COUNT(*) AS payment_count,
        COUNT(DISTINCT payment_type) AS payment_type_count,
        SUM(payment_value) AS payment_value,
        MAX(payment_installments) AS max_installments
    FROM raw.order_payments
    GROUP BY order_id
), review_order AS (
    SELECT
        order_id,
        COUNT(*) AS review_count,
        AVG(review_score)::numeric(5,2) AS review_score
    FROM raw.order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS purchase_date,
    date_trunc('month', o.order_purchase_timestamp)::date AS purchase_month,
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
    EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0 AS delivery_days,
    EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 AS delay_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1
        ELSE 0
    END AS on_time_flag
FROM raw.orders o
JOIN raw.customers c USING (customer_id)
JOIN item_order i USING (order_id)
LEFT JOIN payment_order p USING (order_id)
LEFT JOIN review_order r USING (order_id)
WHERE o.order_status = 'delivered';

CREATE UNIQUE INDEX fact_orders_pk ON analytics.fact_orders(order_id);
CREATE INDEX fact_orders_purchase_date ON analytics.fact_orders(purchase_date);
CREATE INDEX fact_orders_customer ON analytics.fact_orders(customer_unique_id);

CREATE MATERIALIZED VIEW analytics.fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id,
    fo.customer_unique_id,
    fo.customer_state,
    fo.purchase_date,
    fo.purchase_month,
    oi.product_id,
    oi.seller_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS product_category,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS item_gmv
FROM raw.order_items oi
JOIN analytics.fact_orders fo USING (order_id)
LEFT JOIN raw.products p USING (product_id)
LEFT JOIN raw.category_translation t USING (product_category_name);

CREATE UNIQUE INDEX fact_order_items_pk ON analytics.fact_order_items(order_id, order_item_id);
CREATE INDEX fact_order_items_category ON analytics.fact_order_items(product_category);

CREATE MATERIALIZED VIEW analytics.dim_date AS
SELECT
    d::date AS date,
    EXTRACT(YEAR FROM d)::integer AS year,
    EXTRACT(QUARTER FROM d)::integer AS quarter,
    EXTRACT(MONTH FROM d)::integer AS month_number,
    to_char(d, 'YYYY-MM') AS year_month,
    to_char(d, 'Mon') AS month_short,
    date_trunc('month', d)::date AS month_start
FROM generate_series('2016-01-01'::date, '2018-12-31'::date, interval '1 day') d;

CREATE UNIQUE INDEX dim_date_pk ON analytics.dim_date(date);

CREATE MATERIALIZED VIEW analytics.dim_customer AS
SELECT
    customer_unique_id,
    MAX(customer_state) AS customer_state,
    MIN(purchase_date) AS first_purchase_date,
    MAX(purchase_date) AS last_purchase_date,
    COUNT(*) AS lifetime_orders,
    SUM(gmv) AS lifetime_gmv
FROM analytics.fact_orders
GROUP BY customer_unique_id;

CREATE UNIQUE INDEX dim_customer_pk ON analytics.dim_customer(customer_unique_id);

CREATE MATERIALIZED VIEW analytics.dim_category AS
SELECT
    product_category,
    dense_rank() OVER (ORDER BY product_category) AS category_key
FROM (SELECT DISTINCT product_category FROM analytics.fact_order_items) c;

CREATE UNIQUE INDEX dim_category_name ON analytics.dim_category(product_category);

COMMENT ON MATERIALIZED VIEW analytics.fact_orders IS 'Grão: pedido entregue. Fonte principal dos KPIs de pedidos, clientes, GMV e entrega.';
COMMENT ON MATERIALIZED VIEW analytics.fact_order_items IS 'Grão: item do pedido entregue. Usar para análises por produto/categoria.';

