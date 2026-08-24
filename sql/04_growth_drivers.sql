-- Decomposição exata por ponto médio: crescimento do GMV = volume + ticket.
WITH period AS (
    SELECT
        CASE
            WHEN purchase_date BETWEEN '2017-01-01' AND '2017-08-31' THEN 2017
            WHEN purchase_date BETWEEN '2018-01-01' AND '2018-08-31' THEN 2018
        END AS year,
        COUNT(*) AS orders,
        SUM(gmv) / COUNT(*) AS aov,
        SUM(gmv) AS gmv
    FROM v_order_base
    WHERE purchase_date BETWEEN '2017-01-01' AND '2017-08-31'
       OR purchase_date BETWEEN '2018-01-01' AND '2018-08-31'
    GROUP BY year
), p AS (
    SELECT
        MAX(CASE WHEN year = 2017 THEN orders END) AS orders_0,
        MAX(CASE WHEN year = 2018 THEN orders END) AS orders_1,
        MAX(CASE WHEN year = 2017 THEN aov END) AS aov_0,
        MAX(CASE WHEN year = 2018 THEN aov END) AS aov_1,
        MAX(CASE WHEN year = 2017 THEN gmv END) AS gmv_0,
        MAX(CASE WHEN year = 2018 THEN gmv END) AS gmv_1
    FROM period
), bridge AS (
    SELECT 'Efeito volume de pedidos' AS driver,
           (orders_1 - orders_0) * ((aov_0 + aov_1) / 2.0) AS impact
    FROM p
    UNION ALL
    SELECT 'Efeito ticket médio',
           (aov_1 - aov_0) * ((orders_0 + orders_1) / 2.0)
    FROM p
)
SELECT
    driver,
    impact,
    impact / SUM(impact) OVER () AS contribution_to_growth
FROM bridge;

