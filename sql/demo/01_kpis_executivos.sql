-- Visão geral: o que aconteceu com o negócio?
SELECT
    metric AS indicador,
    ROUND(value_2017::numeric, 2) AS valor_2017,
    ROUND(value_2018::numeric, 2) AS valor_2018,
    ROUND(variation::numeric, 4) AS variacao
FROM bi.executive_kpis
ORDER BY CASE metric
    WHEN 'GMV' THEN 1
    WHEN 'Pedidos' THEN 2
    WHEN 'Clientes' THEN 3
    WHEN 'Ticket médio' THEN 4
    WHEN 'Itens por pedido' THEN 5
    WHEN 'Entrega no prazo' THEN 6
    ELSE 7
END;
