"""Constrói o banco SQLite e exporta os marts usados no portfólio."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
PROCESSED = ROOT / "data" / "processed"
DB_PATH = ROOT / "data" / "olist.db"
SQL_DIR = ROOT / "sql"

TABLES = {
    "customers": "olist_customers_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}

EXPORTS = {
    "executive_kpis.csv": "02_executive_kpis.sql",
    "monthly_performance.csv": "03_monthly_performance.sql",
    "growth_drivers.csv": "04_growth_drivers.sql",
    "category_growth.csv": "05_category_growth.sql",
    "customer_segments.csv": "06_customer_segments.sql",
    "cohort_retention.csv": "07_cohort_retention.sql",
    "delivery_experience.csv": "08_delivery_experience.sql",
    "state_performance.csv": "09_state_performance.sql",
}


def require_files() -> None:
    missing = [filename for filename in TABLES.values() if not (RAW / filename).exists()]
    if missing:
        raise FileNotFoundError(
            "Arquivos ausentes em data/raw: " + ", ".join(missing)
            + ". Baixe e extraia a base Brazilian E-Commerce Public Dataset by Olist."
        )


def load_raw_tables(connection: sqlite3.Connection) -> None:
    for table, filename in TABLES.items():
        frame = pd.read_csv(RAW / filename, low_memory=False)
        frame.to_sql(table, connection, if_exists="replace", index=False, chunksize=20_000)
        print(f"loaded {table:20s} {len(frame):>9,} rows")


def run_sql(connection: sqlite3.Connection, filename: str) -> pd.DataFrame:
    sql = (SQL_DIR / filename).read_text(encoding="utf-8")
    return pd.read_sql_query(sql, connection)


def scalar(frame: pd.DataFrame, metric: str, column: str = "value_2018") -> float:
    return float(frame.loc[frame["metric"] == metric, column].iloc[0])


def main() -> None:
    require_files()
    PROCESSED.mkdir(parents=True, exist_ok=True)

    with sqlite3.connect(DB_PATH) as connection:
        load_raw_tables(connection)
        connection.executescript((SQL_DIR / "00_model.sql").read_text(encoding="utf-8"))

        exported: dict[str, pd.DataFrame] = {}
        for output_name, sql_name in EXPORTS.items():
            frame = run_sql(connection, sql_name)
            frame.to_csv(PROCESSED / output_name, index=False, encoding="utf-8-sig")
            exported[output_name] = frame
            print(f"exported {output_name:28s} {len(frame):>6,} rows")

        order_level = pd.read_sql_query(
            """
            SELECT * FROM v_order_base
            WHERE purchase_date BETWEEN '2017-01-01' AND '2018-08-31'
            ORDER BY order_purchase_timestamp
            """,
            connection,
        )
        order_level.to_csv(PROCESSED / "power_bi_orders.csv", index=False, encoding="utf-8-sig")

    kpis = exported["executive_kpis.csv"]
    drivers = exported["growth_drivers.csv"]
    segments = exported["customer_segments.csv"]
    delivery = exported["delivery_experience.csv"]
    categories = exported["category_growth.csv"]

    summary = {
        "comparison": "Jan-Ago 2018 vs Jan-Ago 2017",
        "gmv_2017": scalar(kpis, "GMV", "value_2017"),
        "gmv_2018": scalar(kpis, "GMV"),
        "gmv_growth": scalar(kpis, "GMV", "variation"),
        "orders_growth": scalar(kpis, "Pedidos", "variation"),
        "aov_growth": scalar(kpis, "Ticket médio", "variation"),
        "on_time_rate_2018": scalar(kpis, "Entrega no prazo"),
        "average_review_2018": scalar(kpis, "Nota média"),
        "volume_contribution": float(
            drivers.loc[drivers["driver"] == "Efeito volume de pedidos", "contribution_to_growth"].iloc[0]
        ),
        "top_growth_categories": categories.head(5)[
            ["product_category", "absolute_growth", "growth_contribution"]
        ].to_dict(orient="records"),
        "repeat_customer_count": int(
            segments.loc[
                segments["segment"].str.startswith("Recorrentes"), "customers"
            ].sum()
        ),
        "total_customers": int(segments["customers"].sum()),
        "late_8_plus_review": float(
            delivery.loc[delivery["delivery_band"] == "8+ dias de atraso", "average_review"].iloc[0]
        ),
        "early_review": float(
            delivery.loc[delivery["delivery_band"] == "3+ dias antes do prazo", "average_review"].iloc[0]
        ),
    }
    summary["repeat_customer_rate"] = summary["repeat_customer_count"] / summary["total_customers"]
    (PROCESSED / "analysis_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

