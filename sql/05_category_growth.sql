WITH agg AS (
    SELECT
        product_category,
        SUM(CASE WHEN purchase_date BETWEEN '2017-01-01' AND '2017-08-31' THEN item_gmv ELSE 0 END) AS gmv_2017,
        SUM(CASE WHEN purchase_date BETWEEN '2018-01-01' AND '2018-08-31' THEN item_gmv ELSE 0 END) AS gmv_2018
    FROM v_order_item_base
    WHERE purchase_date BETWEEN '2017-01-01' AND '2017-08-31'
       OR purchase_date BETWEEN '2018-01-01' AND '2018-08-31'
    GROUP BY product_category
), ranked AS (
    SELECT
        *,
        gmv_2018 - gmv_2017 AS absolute_growth,
        CASE WHEN gmv_2017 > 0 THEN gmv_2018 / gmv_2017 - 1 END AS growth_rate,
        (gmv_2018 - gmv_2017) / SUM(gmv_2018 - gmv_2017) OVER () AS growth_contribution
    FROM agg
)
SELECT *
FROM ranked
ORDER BY absolute_growth DESC;

