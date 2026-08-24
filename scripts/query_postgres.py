"""Exporta para Excel/QA os mesmos marts que o Power BI consome no PostgreSQL."""

from __future__ import annotations

import json
import os
from decimal import Decimal
from pathlib import Path

import pandas as pd
import psycopg


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "data" / "processed"

EXPORTS = {
    "executive_kpis.csv": "SELECT * FROM bi.executive_kpis ORDER BY CASE metric WHEN 'GMV' THEN 1 WHEN 'Pedidos' THEN 2 WHEN 'Clientes' THEN 3 WHEN 'Ticket médio' THEN 4 WHEN 'Itens por pedido' THEN 5 WHEN 'Entrega no prazo' THEN 6 ELSE 7 END",
    "monthly_performance.csv": "SELECT * FROM bi.monthly_performance ORDER BY purchase_month",
    "growth_drivers.csv": "SELECT * FROM bi.growth_drivers ORDER BY contribution_to_growth DESC",
    "category_growth.csv": "SELECT * FROM bi.category_growth ORDER BY absolute_growth DESC",
    "customer_segments.csv": "SELECT * FROM bi.customer_segment_summary ORDER BY total_gmv DESC",
    "cohort_retention.csv": "SELECT * FROM bi.cohort_retention ORDER BY cohort_month, months_since",
    "delivery_experience.csv": "SELECT delivery_band, orders, average_review, low_review_rate, gmv FROM bi.delivery_experience ORDER BY band_order",
    "state_performance.csv": "SELECT * FROM bi.state_performance ORDER BY gmv DESC",
}


def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Variável de ambiente obrigatória não definida: {name}")
    return value


def dsn() -> str:
    return (
        f"host={os.getenv('POSTGRES_HOST', 'localhost')} "
        f"port={os.getenv('POSTGRES_PORT', '55432')} "
        f"dbname={os.getenv('POSTGRES_DB', 'olist_analytics')} "
        f"user={os.getenv('POSTGRES_USER', 'olist')} "
        f"password={required_env('POSTGRES_PASSWORD')}"
    )


def frame_from_query(connection: psycopg.Connection, query: str) -> pd.DataFrame:
    with connection.cursor() as cursor:
        cursor.execute(query)
        rows = cursor.fetchall()
        columns = [column.name for column in cursor.description]
    return pd.DataFrame(rows, columns=columns)


def metric(frame: pd.DataFrame, name: str, column: str) -> float:
    return float(frame.loc[frame["metric"] == name, column].iloc[0])


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    exported: dict[str, pd.DataFrame] = {}
    with psycopg.connect(dsn()) as connection:
        for file_name, query in EXPORTS.items():
            frame = frame_from_query(connection, query)
            frame.to_csv(OUTPUT_DIR / file_name, index=False, encoding="utf-8-sig")
            exported[file_name] = frame
            print(f"exported {file_name:28s} {len(frame):>6,} rows")

        order_level = frame_from_query(
            connection,
            """
            SELECT * FROM bi.fact_orders
            WHERE purchase_date BETWEEN DATE '2017-01-01' AND DATE '2018-08-31'
            ORDER BY order_purchase_timestamp
            """,
        )
        order_level.to_csv(OUTPUT_DIR / "power_bi_orders.csv", index=False, encoding="utf-8-sig")

    kpis = exported["executive_kpis.csv"]
    drivers = exported["growth_drivers.csv"]
    segments = exported["customer_segments.csv"]
    delivery = exported["delivery_experience.csv"]
    categories = exported["category_growth.csv"]
    repeat_mask = segments["segment"].str.startswith("Recorrentes")

    summary = {
        "comparison": "Jan-Ago 2018 vs Jan-Ago 2017",
        "gmv_2017": metric(kpis, "GMV", "value_2017"),
        "gmv_2018": metric(kpis, "GMV", "value_2018"),
        "gmv_growth": metric(kpis, "GMV", "variation"),
        "orders_growth": metric(kpis, "Pedidos", "variation"),
        "aov_growth": metric(kpis, "Ticket médio", "variation"),
        "on_time_rate_2018": metric(kpis, "Entrega no prazo", "value_2018"),
        "average_review_2018": metric(kpis, "Nota média", "value_2018"),
        "volume_contribution": float(drivers.loc[drivers["driver"] == "Efeito volume de pedidos", "contribution_to_growth"].iloc[0]),
        "top_growth_categories": [
            {key: (float(value) if isinstance(value, Decimal) else value) for key, value in row.items()}
            for row in categories.head(5)[["product_category", "absolute_growth", "growth_contribution"]].to_dict(orient="records")
        ],
        "repeat_customer_count": int(segments.loc[repeat_mask, "customers"].sum()),
        "total_customers": int(segments["customers"].sum()),
        "late_8_plus_review": float(delivery.loc[delivery["delivery_band"] == "8+ dias de atraso", "average_review"].iloc[0]),
        "early_review": float(delivery.loc[delivery["delivery_band"] == "3+ dias antes do prazo", "average_review"].iloc[0]),
    }
    summary["repeat_customer_rate"] = summary["repeat_customer_count"] / summary["total_customers"]
    (OUTPUT_DIR / "analysis_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
