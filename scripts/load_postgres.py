"""Carrega os CSVs da Olist no PostgreSQL e constrói a camada para Power BI."""

from __future__ import annotations

import os
import time
from pathlib import Path

import psycopg
from psycopg import sql


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
SQL_DIR = ROOT / "sql" / "postgres"

TABLES = {
    "customers": (
        "olist_customers_dataset.csv",
        ["customer_id", "customer_unique_id", "customer_zip_code_prefix", "customer_city", "customer_state"],
    ),
    "geolocation": (
        "olist_geolocation_dataset.csv",
        ["geolocation_zip_code_prefix", "geolocation_lat", "geolocation_lng", "geolocation_city", "geolocation_state"],
    ),
    "orders": (
        "olist_orders_dataset.csv",
        ["order_id", "customer_id", "order_status", "order_purchase_timestamp", "order_approved_at", "order_delivered_carrier_date", "order_delivered_customer_date", "order_estimated_delivery_date"],
    ),
    "order_items": (
        "olist_order_items_dataset.csv",
        ["order_id", "order_item_id", "product_id", "seller_id", "shipping_limit_date", "price", "freight_value"],
    ),
    "order_payments": (
        "olist_order_payments_dataset.csv",
        ["order_id", "payment_sequential", "payment_type", "payment_installments", "payment_value"],
    ),
    "order_reviews": (
        "olist_order_reviews_dataset.csv",
        ["review_id", "order_id", "review_score", "review_comment_title", "review_comment_message", "review_creation_date", "review_answer_timestamp"],
    ),
    "products": (
        "olist_products_dataset.csv",
        ["product_id", "product_category_name", "product_name_lenght", "product_description_lenght", "product_photos_qty", "product_weight_g", "product_length_cm", "product_height_cm", "product_width_cm"],
    ),
    "sellers": (
        "olist_sellers_dataset.csv",
        ["seller_id", "seller_zip_code_prefix", "seller_city", "seller_state"],
    ),
    "category_translation": (
        "product_category_name_translation.csv",
        ["product_category_name", "product_category_name_english"],
    ),
}


def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Variável de ambiente obrigatória não definida: {name}")
    return value


def connection_string() -> str:
    return (
        f"host={os.getenv('POSTGRES_HOST', 'localhost')} "
        f"port={os.getenv('POSTGRES_PORT', '55432')} "
        f"dbname={os.getenv('POSTGRES_DB', 'olist_analytics')} "
        f"user={os.getenv('POSTGRES_USER', 'olist')} "
        f"password={required_env('POSTGRES_PASSWORD')}"
    )


def connect_with_retry(attempts: int = 30, delay_seconds: int = 2) -> psycopg.Connection:
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            return psycopg.connect(connection_string())
        except psycopg.OperationalError as error:
            last_error = error
            print(f"PostgreSQL ainda não está pronto ({attempt}/{attempts})...")
            time.sleep(delay_seconds)
    raise RuntimeError("Não foi possível conectar ao PostgreSQL.") from last_error


def execute_file(connection: psycopg.Connection, file_name: str) -> None:
    statement = (SQL_DIR / file_name).read_text(encoding="utf-8")
    with connection.cursor() as cursor:
        cursor.execute(statement)
    connection.commit()
    print(f"executed {file_name}")


def configure_powerbi_reader(connection: psycopg.Connection) -> None:
    password = required_env("POWERBI_READER_PASSWORD")
    statement = sql.SQL("ALTER ROLE powerbi_reader WITH LOGIN PASSWORD {}").format(
        sql.Literal(password)
    )
    with connection.cursor() as cursor:
        cursor.execute(statement)
    connection.commit()
    print("configured powerbi_reader credentials from environment")


def copy_csv(connection: psycopg.Connection, table: str, file_name: str, columns: list[str]) -> None:
    file_path = RAW_DIR / file_name
    if not file_path.exists():
        raise FileNotFoundError(f"Arquivo ausente: {file_path}")

    copy_statement = sql.SQL(
        "COPY {}.{} ({}) FROM STDIN WITH (FORMAT CSV, HEADER TRUE, NULL '')"
    ).format(
        sql.Identifier("raw"),
        sql.Identifier(table),
        sql.SQL(", ").join(map(sql.Identifier, columns)),
    )
    with connection.cursor() as cursor:
        with cursor.copy(copy_statement) as copy:
            with file_path.open("r", encoding="utf-8", newline="") as source:
                while chunk := source.read(1024 * 1024):
                    copy.write(chunk)
    connection.commit()
    print(f"loaded raw.{table:20s} <- {file_name}")


def main() -> None:
    with connect_with_retry() as connection:
        execute_file(connection, "00_schemas.sql")
        execute_file(connection, "01_raw_tables.sql")
        for table, (file_name, columns) in TABLES.items():
            copy_csv(connection, table, file_name, columns)
        execute_file(connection, "02_indexes.sql")
        execute_file(connection, "03_model.sql")
        execute_file(connection, "04_marts.sql")
        execute_file(connection, "05_security.sql")
        configure_powerbi_reader(connection)

        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    COUNT(*) AS delivered_orders,
                    COUNT(DISTINCT customer_unique_id) AS customers,
                    ROUND(SUM(gmv), 2) AS gmv
                FROM analytics.fact_orders
                """
            )
            delivered_orders, customers, gmv = cursor.fetchone()
            print(f"validated delivered_orders={delivered_orders:,} customers={customers:,} gmv={gmv}")


if __name__ == "__main__":
    main()
