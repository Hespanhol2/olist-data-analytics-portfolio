-- Experiência: o atraso está associado à avaliação do cliente?
SELECT
    delivery_band AS faixa_de_entrega,
    orders AS pedidos,
    ROUND(average_review::numeric, 2) AS nota_media,
    ROUND((low_review_rate * 100)::numeric, 1) AS notas_1_ou_2_pct,
    ROUND(gmv::numeric, 2) AS gmv
FROM bi.delivery_experience
ORDER BY band_order;
