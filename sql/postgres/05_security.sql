-- Usuário exclusivo de leitura para a ferramenta de BI.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powerbi_reader') THEN
        CREATE ROLE powerbi_reader LOGIN;
    END IF;
END
$$;

-- A senha é definida pelo carregador Python a partir de POWERBI_READER_PASSWORD.

GRANT CONNECT ON DATABASE olist_analytics TO powerbi_reader;
GRANT USAGE ON SCHEMA bi TO powerbi_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA bi TO powerbi_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA bi GRANT SELECT ON TABLES TO powerbi_reader;

REVOKE ALL ON SCHEMA raw FROM powerbi_reader;
REVOKE ALL ON SCHEMA analytics FROM powerbi_reader;
