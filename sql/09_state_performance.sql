SELECT
    customer_state,
    COUNT(*) AS orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    SUM(gmv) AS gmv,
    SUM(gmv) / COUNT(*) AS average_order_value,
    AVG(on_time_flag) AS on_time_rate,
    AVG(delivery_days) AS average_delivery_days,
    AVG(review_score) AS average_review
FROM v_order_base
WHERE purchase_date BETWEEN '2017-01-01' AND '2018-08-31'
GROUP BY customer_state
ORDER BY gmv DESC;

