-- Evolução: como o desempenho mudou ao longo do tempo?
SELECT
    purchase_month AS mes,
    ROUND(gmv::numeric, 2) AS gmv,
    orders AS pedidos,
    customers AS clientes,
    ROUND(average_order_value::numeric, 2) AS ticket_medio,
    ROUND((on_time_rate * 100)::numeric, 1) AS entrega_no_prazo_pct,
    ROUND(average_review::numeric, 2) AS nota_media,
    ROUND((gmv_mom * 100)::numeric, 1) AS crescimento_gmv_mom_pct
FROM bi.monthly_performance
ORDER BY purchase_month;
