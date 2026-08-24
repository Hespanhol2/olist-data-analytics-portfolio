-- Clientes: onde está a oportunidade de relacionamento?
SELECT
    segment AS segmento,
    customers AS clientes,
    ROUND(average_recency_days::numeric, 1) AS recencia_media_dias,
    ROUND(average_frequency::numeric, 1) AS frequencia_media,
    ROUND(average_monetary::numeric, 2) AS valor_medio_cliente,
    ROUND(total_gmv::numeric, 2) AS gmv_total,
    ROUND(average_review::numeric, 2) AS nota_media
FROM bi.customer_segment_summary
ORDER BY total_gmv DESC;
