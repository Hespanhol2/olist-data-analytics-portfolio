# Conexão Power BI ↔ PostgreSQL

## 1. Subir e carregar o banco

Na raiz do projeto, execute:

```powershell
.\run_postgres.ps1
```

O fluxo executado é:

```text
CSVs Olist → Python/Psycopg COPY → raw.* → analytics.* → bi.* → Power BI
```

Credenciais locais:

| Campo | Valor |
|---|---|
| Servidor | `localhost:55432` |
| Banco | `olist_analytics` |
| Usuário | `powerbi_reader` |
| Senha | valor de `POWERBI_READER_PASSWORD` no arquivo `.env` |
| Schema para o BI | `bi` |

As senhas não são versionadas. Antes de executar, copie `.env.example` para `.env` e preencha `POSTGRES_PASSWORD` e `POWERBI_READER_PASSWORD`. O usuário do Power BI possui somente leitura no schema `bi`; em produção, a senha deve ficar em um cofre de segredos.

## 2. Conectar no Power BI Desktop

1. Selecione **Obter dados → Banco de dados PostgreSQL**.
2. Informe servidor `localhost:55432` e banco `olist_analytics`.
3. Para este portfólio, escolha **Importar**: o volume é pequeno, a interação fica rápida e o modo oferece o conjunto mais amplo de recursos.
4. Autentique com usuário e senha acima.
5. No Navegador, selecione as tabelas do schema `bi`.

O conector PostgreSQL também aceita DirectQuery. Use essa alternativa somente para demonstrar consultas em tempo quase real; neste case, ela adiciona latência sem benefício prático.

## 3. Tabelas recomendadas

- `bi.fact_orders`: KPIs de pedidos, clientes, GMV, entrega e avaliação.
- `bi.fact_order_items`: análises por produto e categoria.
- `bi.dim_date`: inteligência de tempo.
- `bi.dim_customer`: primeiro/último pedido, frequência e GMV do cliente.
- `bi.dim_category`: dimensão de categoria.
- `bi.monthly_performance`: tendência mensal já validada no PostgreSQL.
- `bi.customer_segments`: segmentação para CRM.
- `bi.cohort_retention`: retenção por coorte.
- `bi.delivery_experience`: relação entre atraso e avaliação.

## 4. Relacionamentos

```text
dim_date[date] 1 ─── * fact_orders[purchase_date]
dim_date[date] 1 ─── * fact_order_items[purchase_date]
dim_customer[customer_unique_id] 1 ─── * fact_orders[customer_unique_id]
dim_customer[customer_unique_id] 1 ─── * fact_order_items[customer_unique_id]
dim_category[product_category] 1 ─── * fact_order_items[product_category]
```

Use direção de filtro única, das dimensões para os fatos. Não relacione `fact_orders` diretamente a `fact_order_items`: os dois fatos compartilham dimensões, evitando ambiguidade e dupla contagem.

## 5. Medidas e páginas

Copie as medidas de `power_bi/medidas.dax`. Estrutura sugerida:

1. **Visão executiva:** GMV, pedidos, clientes, ticket, pontualidade e nota.
2. **Drivers de crescimento:** volume versus ticket, categorias e estados.
3. **Clientes e CRM:** recorrência, segmentos e coortes.
4. **Retenção e valor:** retenção M+1, curva pós-aquisição, churn proxy e LTV histórico proxy.
5. **Experiência:** atraso, nota e taxa de avaliações baixas.

## 6. Power Query opcional

Consulta M equivalente para abrir a fonte:

```powerquery
let
    Fonte = PostgreSQL.Database(
        "localhost:55432",
        "olist_analytics",
        [CreateNavigationProperties = false]
    )
in
    Fonte
```

Fonte técnica: https://learn.microsoft.com/en-us/power-query/connectors/postgresql
