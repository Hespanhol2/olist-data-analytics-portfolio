-- Segmentação comportamental simples, explicável e acionável.
-- Data de referência: primeiro dia após o último mês completo (2018-09-01).
WITH customer AS (
    SELECT
        customer_unique_id,
        MAX(customer_state) AS customer_state,
        CAST(JULIANDAY('2018-09-01') - JULIANDAY(MAX(purchase_date)) AS INTEGER) AS recency_days,
        COUNT(*) AS frequency,
        SUM(gmv) AS monetary,
        AVG(review_score) AS average_review
    FROM v_order_base
    WHERE purchase_date <= '2018-08-31'
    GROUP BY customer_unique_id
), scored AS (
    SELECT
        *,
        NTILE(2) OVER (ORDER BY monetary) AS monetary_half
    FROM customer
), segmented AS (
    SELECT
        *,
        CASE
            WHEN frequency >= 2 AND recency_days <= 90 THEN 'Recorrentes ativos'
            WHEN frequency >= 2 THEN 'Recorrentes em risco'
            WHEN recency_days <= 90 AND monetary_half = 2 THEN 'Recentes de alto valor'
            WHEN recency_days <= 90 THEN 'Recentes'
            WHEN monetary_half = 2 THEN 'Alto valor inativos'
            ELSE 'Inativos de baixo valor'
        END AS segment
    FROM scored
)
SELECT
    segment,
    COUNT(*) AS customers,
    AVG(recency_days) AS average_recency_days,
    AVG(frequency) AS average_frequency,
    AVG(monetary) AS average_monetary,
    SUM(monetary) AS total_gmv,
    AVG(average_review) AS average_review
FROM segmented
GROUP BY segment
ORDER BY total_gmv DESC;

