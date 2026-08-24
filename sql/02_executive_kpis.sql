-- Comparação justa: janeiro a agosto de 2017 versus janeiro a agosto de 2018.
WITH period AS (
    SELECT
        CASE
            WHEN purchase_date BETWEEN '2017-01-01' AND '2017-08-31' THEN '2017 Jan-Ago'
            WHEN purchase_date BETWEEN '2018-01-01' AND '2018-08-31' THEN '2018 Jan-Ago'
        END AS comparison_period,
        *
    FROM v_order_base
    WHERE purchase_date BETWEEN '2017-01-01' AND '2017-08-31'
       OR purchase_date BETWEEN '2018-01-01' AND '2018-08-31'
), agg AS (
    SELECT
        comparison_period,
        SUM(gmv) AS gmv,
        COUNT(*) AS orders,
        COUNT(DISTINCT customer_unique_id) AS customers,
        SUM(gmv) / COUNT(*) AS average_order_value,
        AVG(item_count) AS items_per_order,
        AVG(on_time_flag) AS on_time_rate,
        AVG(review_score) AS average_review
    FROM period
    GROUP BY comparison_period
), pivot AS (
    SELECT
        MAX(CASE WHEN comparison_period = '2017 Jan-Ago' THEN gmv END) AS gmv_2017,
        MAX(CASE WHEN comparison_period = '2018 Jan-Ago' THEN gmv END) AS gmv_2018,
        MAX(CASE WHEN comparison_period = '2017 Jan-Ago' THEN orders END) AS orders_2017,
        MAX(CASE WHEN comparison_period = '2018 Jan-Ago' THEN orders END) AS orders_2018,
        MAX(CASE WHEN comparison_period = '2017 Jan-Ago' THEN customers END) AS customers_2017,
        MAX(CASE WHEN comparison_period = '2018 Jan-Ago' THEN customers END) AS customers_2018,
        MAX(CASE WHEN comparison_period = '2017 Jan-Ago' THEN average_order_value END) AS aov_2017,
        MAX(CASE WHEN comparison_period = '2018 Jan-Ago' THEN average_order_value END) AS aov_2018,
        MAX(CASE WHEN comparison_period = '2017 Jan-Ago' THEN items_per_order END) AS ipo_2017,
        MAX(CASE WHEN comparison_period = '2018 Jan-Ago' THEN items_per_order END) AS ipo_2018,
        MAX(CASE WHEN comparison_period = '2017 Jan-Ago' THEN on_time_rate END) AS ontime_2017,
        MAX(CASE WHEN comparison_period = '2018 Jan-Ago' THEN on_time_rate END) AS ontime_2018,
        MAX(CASE WHEN comparison_period = '2017 Jan-Ago' THEN average_review END) AS review_2017,
        MAX(CASE WHEN comparison_period = '2018 Jan-Ago' THEN average_review END) AS review_2018
    FROM agg
)
SELECT 'GMV' AS metric, gmv_2017 AS value_2017, gmv_2018 AS value_2018, gmv_2018 / gmv_2017 - 1 AS variation FROM pivot
UNION ALL SELECT 'Pedidos', orders_2017, orders_2018, 1.0 * orders_2018 / orders_2017 - 1 FROM pivot
UNION ALL SELECT 'Clientes', customers_2017, customers_2018, 1.0 * customers_2018 / customers_2017 - 1 FROM pivot
UNION ALL SELECT 'Ticket médio', aov_2017, aov_2018, aov_2018 / aov_2017 - 1 FROM pivot
UNION ALL SELECT 'Itens por pedido', ipo_2017, ipo_2018, ipo_2018 / ipo_2017 - 1 FROM pivot
UNION ALL SELECT 'Entrega no prazo', ontime_2017, ontime_2018, ontime_2018 - ontime_2017 FROM pivot
UNION ALL SELECT 'Nota média', review_2017, review_2018, review_2018 - review_2017 FROM pivot;

