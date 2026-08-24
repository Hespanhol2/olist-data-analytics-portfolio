-- Retenção por coorte mensal; formato longo para uso em Power BI/Excel.
WITH customer_month AS (
    SELECT DISTINCT customer_unique_id, purchase_month
    FROM v_order_base
    WHERE purchase_month BETWEEN '2017-01' AND '2018-08'
), cohort AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM customer_month
    GROUP BY customer_unique_id
), activity AS (
    SELECT
        c.cohort_month,
        m.purchase_month AS activity_month,
        (CAST(SUBSTR(m.purchase_month, 1, 4) AS INTEGER) - CAST(SUBSTR(c.cohort_month, 1, 4) AS INTEGER)) * 12
          + CAST(SUBSTR(m.purchase_month, 6, 2) AS INTEGER) - CAST(SUBSTR(c.cohort_month, 6, 2) AS INTEGER) AS months_since,
        COUNT(DISTINCT m.customer_unique_id) AS active_customers
    FROM customer_month m
    JOIN cohort c ON c.customer_unique_id = m.customer_unique_id
    GROUP BY c.cohort_month, m.purchase_month
), sized AS (
    SELECT cohort_month, active_customers AS cohort_size
    FROM activity
    WHERE months_since = 0
)
SELECT
    a.cohort_month,
    a.activity_month,
    a.months_since,
    a.active_customers,
    s.cohort_size,
    1.0 * a.active_customers / s.cohort_size AS retention_rate
FROM activity a
JOIN sized s USING (cohort_month)
ORDER BY a.cohort_month, a.months_since;

