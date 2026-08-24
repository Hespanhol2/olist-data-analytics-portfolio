CREATE MATERIALIZED VIEW analytics.mart_monthly_performance AS
WITH sequenced AS (
    SELECT
        f.*,
        row_number() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS customer_order_number
    FROM analytics.fact_orders f
), monthly AS (
    SELECT
        purchase_month,
        SUM(gmv) AS gmv,
        COUNT(*) AS orders,
        COUNT(DISTINCT customer_unique_id) AS customers,
        SUM(gmv) / COUNT(*) AS average_order_value,
        AVG(item_count) AS items_per_order,
        AVG(on_time_flag) AS on_time_rate,
        AVG(review_score) AS average_review,
        AVG((customer_order_number > 1)::integer) AS repeat_order_share
    FROM sequenced
    WHERE purchase_month BETWEEN DATE '2017-01-01' AND DATE '2018-08-01'
    GROUP BY purchase_month
)
SELECT
    *,
    gmv / lag(gmv) OVER (ORDER BY purchase_month) - 1 AS gmv_mom,
    orders::numeric / lag(orders) OVER (ORDER BY purchase_month) - 1 AS orders_mom,
    average_order_value / lag(average_order_value) OVER (ORDER BY purchase_month) - 1 AS aov_mom
FROM monthly;

CREATE UNIQUE INDEX mart_monthly_pk ON analytics.mart_monthly_performance(purchase_month);

CREATE MATERIALIZED VIEW analytics.mart_executive_kpis AS
WITH period AS (
    SELECT
        CASE
            WHEN purchase_date BETWEEN DATE '2017-01-01' AND DATE '2017-08-31' THEN '2017 Jan-Ago'
            WHEN purchase_date BETWEEN DATE '2018-01-01' AND DATE '2018-08-31' THEN '2018 Jan-Ago'
        END AS comparison_period,
        *
    FROM analytics.fact_orders
    WHERE purchase_date BETWEEN DATE '2017-01-01' AND DATE '2017-08-31'
       OR purchase_date BETWEEN DATE '2018-01-01' AND DATE '2018-08-31'
), agg AS (
    SELECT
        comparison_period,
        SUM(gmv) AS gmv,
        COUNT(*)::numeric AS orders,
        COUNT(DISTINCT customer_unique_id)::numeric AS customers,
        SUM(gmv) / COUNT(*) AS average_order_value,
        AVG(item_count) AS items_per_order,
        AVG(on_time_flag) AS on_time_rate,
        AVG(review_score) AS average_review
    FROM period
    GROUP BY comparison_period
), p AS (
    SELECT
        MAX(gmv) FILTER (WHERE comparison_period = '2017 Jan-Ago') AS gmv_2017,
        MAX(gmv) FILTER (WHERE comparison_period = '2018 Jan-Ago') AS gmv_2018,
        MAX(orders) FILTER (WHERE comparison_period = '2017 Jan-Ago') AS orders_2017,
        MAX(orders) FILTER (WHERE comparison_period = '2018 Jan-Ago') AS orders_2018,
        MAX(customers) FILTER (WHERE comparison_period = '2017 Jan-Ago') AS customers_2017,
        MAX(customers) FILTER (WHERE comparison_period = '2018 Jan-Ago') AS customers_2018,
        MAX(average_order_value) FILTER (WHERE comparison_period = '2017 Jan-Ago') AS aov_2017,
        MAX(average_order_value) FILTER (WHERE comparison_period = '2018 Jan-Ago') AS aov_2018,
        MAX(items_per_order) FILTER (WHERE comparison_period = '2017 Jan-Ago') AS ipo_2017,
        MAX(items_per_order) FILTER (WHERE comparison_period = '2018 Jan-Ago') AS ipo_2018,
        MAX(on_time_rate) FILTER (WHERE comparison_period = '2017 Jan-Ago') AS ontime_2017,
        MAX(on_time_rate) FILTER (WHERE comparison_period = '2018 Jan-Ago') AS ontime_2018,
        MAX(average_review) FILTER (WHERE comparison_period = '2017 Jan-Ago') AS review_2017,
        MAX(average_review) FILTER (WHERE comparison_period = '2018 Jan-Ago') AS review_2018
    FROM agg
)
SELECT 'GMV' AS metric, gmv_2017 AS value_2017, gmv_2018 AS value_2018, gmv_2018 / gmv_2017 - 1 AS variation FROM p
UNION ALL SELECT 'Pedidos', orders_2017, orders_2018, orders_2018 / orders_2017 - 1 FROM p
UNION ALL SELECT 'Clientes', customers_2017, customers_2018, customers_2018 / customers_2017 - 1 FROM p
UNION ALL SELECT 'Ticket médio', aov_2017, aov_2018, aov_2018 / aov_2017 - 1 FROM p
UNION ALL SELECT 'Itens por pedido', ipo_2017, ipo_2018, ipo_2018 / ipo_2017 - 1 FROM p
UNION ALL SELECT 'Entrega no prazo', ontime_2017, ontime_2018, ontime_2018 - ontime_2017 FROM p
UNION ALL SELECT 'Nota média', review_2017, review_2018, review_2018 - review_2017 FROM p;

CREATE MATERIALIZED VIEW analytics.mart_growth_drivers AS
WITH period AS (
    SELECT
        EXTRACT(YEAR FROM purchase_date)::integer AS year,
        COUNT(*)::numeric AS orders,
        SUM(gmv) / COUNT(*) AS aov
    FROM analytics.fact_orders
    WHERE purchase_date BETWEEN DATE '2017-01-01' AND DATE '2017-08-31'
       OR purchase_date BETWEEN DATE '2018-01-01' AND DATE '2018-08-31'
    GROUP BY year
), p AS (
    SELECT
        MAX(orders) FILTER (WHERE year = 2017) AS orders_0,
        MAX(orders) FILTER (WHERE year = 2018) AS orders_1,
        MAX(aov) FILTER (WHERE year = 2017) AS aov_0,
        MAX(aov) FILTER (WHERE year = 2018) AS aov_1
    FROM period
), bridge AS (
    SELECT 'Efeito volume de pedidos' AS driver,
           (orders_1 - orders_0) * ((aov_0 + aov_1) / 2) AS impact
    FROM p
    UNION ALL
    SELECT 'Efeito ticket médio',
           (aov_1 - aov_0) * ((orders_0 + orders_1) / 2)
    FROM p
)
SELECT driver, impact, impact / SUM(impact) OVER () AS contribution_to_growth
FROM bridge;

CREATE MATERIALIZED VIEW analytics.mart_category_growth AS
WITH agg AS (
    SELECT
        product_category,
        SUM(item_gmv) FILTER (WHERE purchase_date BETWEEN DATE '2017-01-01' AND DATE '2017-08-31') AS gmv_2017,
        SUM(item_gmv) FILTER (WHERE purchase_date BETWEEN DATE '2018-01-01' AND DATE '2018-08-31') AS gmv_2018
    FROM analytics.fact_order_items
    WHERE purchase_date BETWEEN DATE '2017-01-01' AND DATE '2017-08-31'
       OR purchase_date BETWEEN DATE '2018-01-01' AND DATE '2018-08-31'
    GROUP BY product_category
)
SELECT
    product_category,
    COALESCE(gmv_2017, 0) AS gmv_2017,
    COALESCE(gmv_2018, 0) AS gmv_2018,
    COALESCE(gmv_2018, 0) - COALESCE(gmv_2017, 0) AS absolute_growth,
    CASE WHEN gmv_2017 > 0 THEN gmv_2018 / gmv_2017 - 1 END AS growth_rate,
    (COALESCE(gmv_2018, 0) - COALESCE(gmv_2017, 0))
      / SUM(COALESCE(gmv_2018, 0) - COALESCE(gmv_2017, 0)) OVER () AS growth_contribution
FROM agg;

CREATE UNIQUE INDEX mart_category_growth_pk ON analytics.mart_category_growth(product_category);

CREATE MATERIALIZED VIEW analytics.mart_customer_segments AS
WITH customer AS (
    SELECT
        customer_unique_id,
        MAX(customer_state) AS customer_state,
        DATE '2018-09-01' - MAX(purchase_date) AS recency_days,
        COUNT(*) AS frequency,
        SUM(gmv) AS monetary,
        AVG(review_score) AS average_review
    FROM analytics.fact_orders
    WHERE purchase_date <= DATE '2018-08-31'
    GROUP BY customer_unique_id
), threshold AS (
    SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY monetary) AS median_monetary
    FROM customer
)
SELECT
    c.*,
    CASE
        WHEN frequency >= 2 AND recency_days <= 90 THEN 'Recorrentes ativos'
        WHEN frequency >= 2 THEN 'Recorrentes em risco'
        WHEN recency_days <= 90 AND monetary >= median_monetary THEN 'Recentes de alto valor'
        WHEN recency_days <= 90 THEN 'Recentes'
        WHEN monetary >= median_monetary THEN 'Alto valor inativos'
        ELSE 'Inativos de baixo valor'
    END AS segment
FROM customer c
CROSS JOIN threshold;

CREATE UNIQUE INDEX mart_customer_segments_pk ON analytics.mart_customer_segments(customer_unique_id);
CREATE INDEX mart_customer_segments_segment ON analytics.mart_customer_segments(segment);

CREATE MATERIALIZED VIEW analytics.mart_customer_segment_summary AS
SELECT
    segment,
    COUNT(*) AS customers,
    AVG(recency_days) AS average_recency_days,
    AVG(frequency) AS average_frequency,
    AVG(monetary) AS average_monetary,
    SUM(monetary) AS total_gmv,
    AVG(average_review) AS average_review
FROM analytics.mart_customer_segments
GROUP BY segment;

CREATE MATERIALIZED VIEW analytics.mart_cohort_retention AS
WITH customer_month AS (
    SELECT DISTINCT customer_unique_id, purchase_month
    FROM analytics.fact_orders
    WHERE purchase_month BETWEEN DATE '2017-01-01' AND DATE '2018-08-01'
), cohort AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM customer_month
    GROUP BY customer_unique_id
), activity AS (
    SELECT
        c.cohort_month,
        m.purchase_month AS activity_month,
        (
            EXTRACT(YEAR FROM age(m.purchase_month, c.cohort_month)) * 12
            + EXTRACT(MONTH FROM age(m.purchase_month, c.cohort_month))
        )::integer AS months_since,
        COUNT(DISTINCT m.customer_unique_id) AS active_customers
    FROM customer_month m
    JOIN cohort c USING (customer_unique_id)
    GROUP BY c.cohort_month, m.purchase_month
), sized AS (
    SELECT cohort_month, active_customers AS cohort_size
    FROM activity
    WHERE months_since = 0
)
SELECT
    a.*,
    s.cohort_size,
    a.active_customers::numeric / s.cohort_size AS retention_rate
FROM activity a
JOIN sized s USING (cohort_month);

CREATE UNIQUE INDEX mart_cohort_pk ON analytics.mart_cohort_retention(cohort_month, activity_month);

CREATE MATERIALIZED VIEW analytics.mart_delivery_experience AS
WITH banded AS (
    SELECT
        CASE
            WHEN delay_days <= -3 THEN '3+ dias antes do prazo'
            WHEN delay_days <= 0 THEN 'No prazo (até 2 dias antes)'
            WHEN delay_days <= 3 THEN '1–3 dias de atraso'
            WHEN delay_days <= 7 THEN '4–7 dias de atraso'
            ELSE '8+ dias de atraso'
        END AS delivery_band,
        CASE
            WHEN delay_days <= -3 THEN 1
            WHEN delay_days <= 0 THEN 2
            WHEN delay_days <= 3 THEN 3
            WHEN delay_days <= 7 THEN 4
            ELSE 5
        END AS band_order,
        review_score,
        gmv
    FROM analytics.fact_orders
    WHERE delay_days IS NOT NULL
)
SELECT
    delivery_band,
    MIN(band_order) AS band_order,
    COUNT(*) AS orders,
    AVG(review_score) AS average_review,
    AVG((review_score <= 2)::integer) AS low_review_rate,
    SUM(gmv) AS gmv
FROM banded
GROUP BY delivery_band;

CREATE UNIQUE INDEX mart_delivery_pk ON analytics.mart_delivery_experience(band_order);

CREATE MATERIALIZED VIEW analytics.mart_state_performance AS
SELECT
    customer_state,
    COUNT(*) AS orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    SUM(gmv) AS gmv,
    SUM(gmv) / COUNT(*) AS average_order_value,
    AVG(on_time_flag) AS on_time_rate,
    AVG(delivery_days) AS average_delivery_days,
    AVG(review_score) AS average_review
FROM analytics.fact_orders
WHERE purchase_date BETWEEN DATE '2017-01-01' AND DATE '2018-08-31'
GROUP BY customer_state;

CREATE UNIQUE INDEX mart_state_pk ON analytics.mart_state_performance(customer_state);

-- Camada de consumo: nomes estáveis para o Power BI.
CREATE VIEW bi.fact_orders AS SELECT * FROM analytics.fact_orders;
CREATE VIEW bi.fact_order_items AS SELECT * FROM analytics.fact_order_items;
CREATE VIEW bi.dim_date AS SELECT * FROM analytics.dim_date;
CREATE VIEW bi.dim_customer AS SELECT * FROM analytics.dim_customer;
CREATE VIEW bi.dim_category AS SELECT * FROM analytics.dim_category;
CREATE VIEW bi.executive_kpis AS SELECT * FROM analytics.mart_executive_kpis;
CREATE VIEW bi.monthly_performance AS SELECT * FROM analytics.mart_monthly_performance;
CREATE VIEW bi.growth_drivers AS SELECT * FROM analytics.mart_growth_drivers;
CREATE VIEW bi.category_growth AS SELECT * FROM analytics.mart_category_growth;
CREATE VIEW bi.customer_segments AS SELECT * FROM analytics.mart_customer_segments;
CREATE VIEW bi.customer_segment_summary AS SELECT * FROM analytics.mart_customer_segment_summary;
CREATE VIEW bi.cohort_retention AS SELECT * FROM analytics.mart_cohort_retention;
CREATE VIEW bi.delivery_experience AS SELECT * FROM analytics.mart_delivery_experience;
CREATE VIEW bi.state_performance AS SELECT * FROM analytics.mart_state_performance;
