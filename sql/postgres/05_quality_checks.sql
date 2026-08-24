-- Deve retornar zero linhas.
SELECT order_id, COUNT(*)
FROM analytics.fact_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Reconciliação: a diferença pequena pode incluir vouchers e ajustes de pagamento.
SELECT
    ROUND(SUM(gmv), 2) AS item_gmv,
    ROUND(SUM(payment_value), 2) AS payment_value,
    ROUND(SUM(payment_value) - SUM(gmv), 2) AS difference
FROM analytics.fact_orders;

-- Jan–ago/2018 versus jan–ago/2017: valida os números centrais do case.
SELECT
    EXTRACT(YEAR FROM purchase_date)::integer AS year,
    COUNT(*) AS orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    ROUND(SUM(gmv), 2) AS gmv,
    ROUND(SUM(gmv) / COUNT(*), 2) AS average_order_value,
    ROUND(AVG(on_time_flag) * 100, 1) AS on_time_pct,
    ROUND(AVG(review_score), 2) AS average_review
FROM analytics.fact_orders
WHERE purchase_date BETWEEN DATE '2017-01-01' AND DATE '2017-08-31'
   OR purchase_date BETWEEN DATE '2018-01-01' AND DATE '2018-08-31'
GROUP BY year
ORDER BY year;

