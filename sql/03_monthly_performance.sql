-- Meses completos do intervalo principal. Sequência de pedido identifica recompra real.
WITH sequenced AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp, order_id
        ) AS customer_order_number
    FROM v_order_base
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
        AVG(CASE WHEN customer_order_number > 1 THEN 1.0 ELSE 0.0 END) AS repeat_order_share
    FROM sequenced
    WHERE purchase_month BETWEEN '2017-01' AND '2018-08'
    GROUP BY purchase_month
)
SELECT
    *,
    gmv / LAG(gmv) OVER (ORDER BY purchase_month) - 1 AS gmv_mom,
    orders * 1.0 / LAG(orders) OVER (ORDER BY purchase_month) - 1 AS orders_mom,
    average_order_value / LAG(average_order_value) OVER (ORDER BY purchase_month) - 1 AS aov_mom
FROM monthly
ORDER BY purchase_month;

