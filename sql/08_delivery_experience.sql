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
    FROM v_order_base
    WHERE delay_days IS NOT NULL
)
SELECT
    delivery_band,
    COUNT(*) AS orders,
    AVG(review_score) AS average_review,
    AVG(CASE WHEN review_score <= 2 THEN 1.0 ELSE 0.0 END) AS low_review_rate,
    SUM(gmv) AS gmv
FROM banded
GROUP BY delivery_band, band_order
ORDER BY band_order;

