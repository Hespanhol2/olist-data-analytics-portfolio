CREATE TABLE raw.customers (
    customer_id text PRIMARY KEY,
    customer_unique_id text NOT NULL,
    customer_zip_code_prefix integer,
    customer_city text,
    customer_state char(2)
);

CREATE TABLE raw.geolocation (
    geolocation_zip_code_prefix integer,
    geolocation_lat double precision,
    geolocation_lng double precision,
    geolocation_city text,
    geolocation_state char(2)
);

CREATE TABLE raw.orders (
    order_id text PRIMARY KEY,
    customer_id text NOT NULL REFERENCES raw.customers(customer_id),
    order_status text NOT NULL,
    order_purchase_timestamp timestamp,
    order_approved_at timestamp,
    order_delivered_carrier_date timestamp,
    order_delivered_customer_date timestamp,
    order_estimated_delivery_date timestamp
);

CREATE TABLE raw.order_items (
    order_id text NOT NULL REFERENCES raw.orders(order_id),
    order_item_id integer NOT NULL,
    product_id text NOT NULL,
    seller_id text NOT NULL,
    shipping_limit_date timestamp,
    price numeric(14,2),
    freight_value numeric(14,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE raw.order_payments (
    order_id text NOT NULL REFERENCES raw.orders(order_id),
    payment_sequential integer NOT NULL,
    payment_type text,
    payment_installments integer,
    payment_value numeric(14,2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE raw.order_reviews (
    review_id text NOT NULL,
    order_id text NOT NULL REFERENCES raw.orders(order_id),
    review_score integer,
    review_comment_title text,
    review_comment_message text,
    review_creation_date timestamp,
    review_answer_timestamp timestamp
);

CREATE TABLE raw.products (
    product_id text PRIMARY KEY,
    product_category_name text,
    product_name_lenght integer,
    product_description_lenght integer,
    product_photos_qty integer,
    product_weight_g integer,
    product_length_cm integer,
    product_height_cm integer,
    product_width_cm integer
);

CREATE TABLE raw.sellers (
    seller_id text PRIMARY KEY,
    seller_zip_code_prefix integer,
    seller_city text,
    seller_state char(2)
);

CREATE TABLE raw.category_translation (
    product_category_name text PRIMARY KEY,
    product_category_name_english text
);

