"""Perfil inicial e validações da base pública Olist."""

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"


def load(name: str, **kwargs) -> pd.DataFrame:
    return pd.read_csv(RAW / name, **kwargs)


def main() -> None:
    customers = load("olist_customers_dataset.csv", dtype={"customer_zip_code_prefix": "string"})
    orders = load("olist_orders_dataset.csv", parse_dates=[
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ])
    items = load("olist_order_items_dataset.csv", parse_dates=["shipping_limit_date"])
    payments = load("olist_order_payments_dataset.csv")
    reviews = load("olist_order_reviews_dataset.csv")
    products = load("olist_products_dataset.csv")
    sellers = load("olist_sellers_dataset.csv")

    tables = {
        "customers": customers,
        "orders": orders,
        "items": items,
        "payments": payments,
        "reviews": reviews,
        "products": products,
        "sellers": sellers,
    }

    print("ROW_COUNTS")
    for name, df in tables.items():
        print(f"{name:10s} {len(df):>9,}")

    print("\nDATE_RANGE")
    print("purchase_min", orders["order_purchase_timestamp"].min())
    print("purchase_max", orders["order_purchase_timestamp"].max())

    print("\nORDER_STATUS")
    print(orders["order_status"].value_counts(dropna=False).to_string())

    print("\nKEY_QUALITY")
    checks = {
        "orders.order_id_unique": orders["order_id"].is_unique,
        "orders.customer_id_unique": orders["customer_id"].is_unique,
        "customers.customer_id_unique": customers["customer_id"].is_unique,
        "products.product_id_unique": products["product_id"].is_unique,
        "sellers.seller_id_unique": sellers["seller_id"].is_unique,
        "customers.unique_customer_count": customers["customer_unique_id"].nunique(),
        "customers.repeat_customer_count": int((customers.groupby("customer_unique_id").size() > 1).sum()),
        "item_orders": items["order_id"].nunique(),
        "payment_orders": payments["order_id"].nunique(),
        "review_orders": reviews["order_id"].nunique(),
    }
    for label, value in checks.items():
        print(label, value)

    delivered = orders[orders["order_status"] == "delivered"].copy()
    delivered_order_ids = set(delivered["order_id"])
    delivered_items = items[items["order_id"].isin(delivered_order_ids)]
    delivered_payments = payments[payments["order_id"].isin(delivered_order_ids)]
    print("\nDELIVERED_RECONCILIATION")
    print("delivered_orders", len(delivered))
    print("item_value", round((delivered_items["price"] + delivered_items["freight_value"]).sum(), 2))
    print("payment_value", round(delivered_payments["payment_value"].sum(), 2))
    print("orders_without_items", len(delivered_order_ids - set(delivered_items["order_id"])))
    print("orders_without_payments", len(delivered_order_ids - set(delivered_payments["order_id"])))

    print("\nMISSINGNESS_TOP")
    for name, df in tables.items():
        missing = df.isna().mean().sort_values(ascending=False)
        missing = missing[missing > 0]
        if not missing.empty:
            print(f"[{name}]")
            print((missing.head(8) * 100).round(1).astype(str).add("%").to_string())


if __name__ == "__main__":
    main()
