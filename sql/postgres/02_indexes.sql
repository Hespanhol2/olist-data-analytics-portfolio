CREATE INDEX idx_customers_unique ON raw.customers(customer_unique_id);
CREATE INDEX idx_orders_customer ON raw.orders(customer_id);
CREATE INDEX idx_orders_purchase ON raw.orders(order_purchase_timestamp);
CREATE INDEX idx_orders_status ON raw.orders(order_status);
CREATE INDEX idx_items_product ON raw.order_items(product_id);
CREATE INDEX idx_items_seller ON raw.order_items(seller_id);
CREATE INDEX idx_payments_order ON raw.order_payments(order_id);
CREATE INDEX idx_reviews_order ON raw.order_reviews(order_id);
CREATE INDEX idx_geolocation_zip ON raw.geolocation(geolocation_zip_code_prefix);

ANALYZE raw.customers;
ANALYZE raw.orders;
ANALYZE raw.order_items;
ANALYZE raw.order_payments;
ANALYZE raw.order_reviews;
ANALYZE raw.products;

