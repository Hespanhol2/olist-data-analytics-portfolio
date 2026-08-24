-- Ambiente local de portfólio: a carga é integral e recria as camadas.
DROP SCHEMA IF EXISTS bi CASCADE;
DROP SCHEMA IF EXISTS analytics CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;

CREATE SCHEMA raw;
CREATE SCHEMA analytics;
CREATE SCHEMA bi;

COMMENT ON SCHEMA raw IS 'Cópia tipada dos CSVs públicos da Olist.';
COMMENT ON SCHEMA analytics IS 'Fatos, dimensões e marts calculados no PostgreSQL.';
COMMENT ON SCHEMA bi IS 'Camada estável e simplificada para consumo no Power BI.';

