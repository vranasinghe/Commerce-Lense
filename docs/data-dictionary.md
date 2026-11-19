# Data dictionary and source-to-target mapping

SQL DDL is authoritative for exact SQL types. Bronze fields are Unicode text; Silver casts numeric/date values, trims strings and normalizes status/state/category fields. Existing database metadata is never assumed to match initialization.

## customers

Source: `docs/olist_customers_dataset.csv`; 99,441 records. Bronze: `dbo.bronze_customers`. Business key: `customer_id`.

- `customer_id` → `[customer_id]`.
- `customer_unique_id` → `[customer_unique_id]`.
- `customer_zip_code_prefix` → `[customer_zip_code_prefix]`.
- `customer_city` → `[customer_city]`.
- `customer_state` → `[customer_state]`.

## orders

Source: `docs/olist_orders_dataset.csv`; 99,441 records. Bronze: `dbo.bronze_orders`. Business key: `order_id`.

- `order_id` → `[Copy of order_id]`.
- `customer_id` → `[Copy of customer_id]`.
- `order_status` → `[Copy of order_status]`.
- `order_purchase_timestamp` → `[Copy of order_purchase_timestamp]`.
- `order_approved_at` → `[Copy of order_approved_at]`.
- `order_delivered_carrier_date` → `[Copy of order_delivered_carrier_date]`.
- `order_delivered_customer_date` → `[Copy of order_delivered_customer_date]`.
- `order_estimated_delivery_date` → `[Copy of order_estimated_delivery_date]`.

## order_items

Source: `docs/olist_order_items_dataset.csv`; 112,650 records. Bronze: `dbo.bronze_order_items`. Business key: `order_id`, `order_item_id`.

- `order_id` → `[Copy of order_id]`.
- `order_item_id` → `[order_item_id]`.
- `product_id` → `[Copy of product_id]`.
- `seller_id` → `[Copy of seller_id]`.
- `shipping_limit_date` → `[shipping_limit_date]`.
- `price` → `[price]`.
- `freight_value` → `[freight_value]`.

## products

Source: `docs/olist_products_dataset.csv`; 32,951 records. Bronze: `dbo.bronze_products`. Business key: `product_id`.

- `product_id` → `[Copy of product_id]`.
- `product_category_name` → `[Copy of product_category_name]`.
- `product_name_lenght` → `[product_name_lenght]` → `product_name_length`.
- `product_description_lenght` → `[product_description_lenght]` → `product_description_length`.
- `product_photos_qty` → `[product_photos_qty]`.
- `product_weight_g` → `[product_weight_g]`.
- `product_length_cm` → `[product_length_cm]`.
- `product_height_cm` → `[product_height_cm]`.
- `product_width_cm` → `[product_width_cm]`.

## sellers

Source: `docs/olist_sellers_dataset.csv`; 3,095 records. Bronze: `dbo.bronze_sellers`. Business key: `seller_id`.

- `seller_id` → `[Copy of seller_id]`.
- `seller_zip_code_prefix` → `[seller_zip_code_prefix]`.
- `seller_city` → `[Copy of seller_city]`.
- `seller_state` → `[Copy of seller_state]`.

## order_payments

Source: `docs/olist_order_payments_dataset.csv`; 103,886 records. Bronze: `dbo.bronze_order_payments`. Business key: `order_id`, `payment_sequential`.

- `order_id` → `[Copy of order_id]`.
- `payment_sequential` → `[payment_sequential]`.
- `payment_type` → `[payment_type]`.
- `payment_installments` → `[payment_installments]`.
- `payment_value` → `[payment_value]`.

## order_reviews

Source: `docs/olist_order_reviews_dataset.csv`; 99,224 records. Bronze: `dbo.bronze_order_reviews`. Business key: `review_id`, `order_id`.

- `review_id` → `[Copy of review_id]`.
- `order_id` → `[Copy of order_id]`.
- `review_score` → `[review_score]`.
- `review_comment_title` → `[review_comment_title]`.
- `review_comment_message` → `[review_comment_message]`.
- `review_creation_date` → `[review_creation_date]`.
- `review_answer_timestamp` → `[review_answer_timestamp]`.

## geolocation

Source: `docs/olist_geolocation_dataset.csv`; 1,000,163 records. Bronze: `dbo.bronze_landing_geolocation`. Business key: no unique ZIP key; retain geographic observations.

- `geolocation_zip_code_prefix` → `["geolocation_zip_code_prefix"]`.
- `geolocation_lat` → `["geolocation_lat"]`.
- `geolocation_lng` → `["geolocation_lng"]`.
- `geolocation_city` → `["geolocation_city"]`.
- `geolocation_state` → `["geolocation_state"]`.

## category_translation

Source: `docs/product_category_name_translation.csv`; 71 records. Bronze: `dbo.bronze_category_translation`. Business key: `product_category_name`.

- `product_category_name` → `[product_category_name]`.
- `product_category_name_english` → `[product_category_name_english]`.

## Analytical entities

`dim_customers` uses identity `customer_key`; `customer_id` is unique, `customer_unique_id` may repeat. Products/sellers have analogous stable surrogate/business keys. `dim_date` uses YYYYMMDD integer keys, Monday=1, English names, full-year continuous coverage. NULL facts mean missing date, not a 1900 timestamp.

`fact_orders` retains source item ordinal and BRL `price`, `freight_value` (DECIMAL(18,2)). `order_item_key` is not the source ID. `fact_payments` retains sequential/payment type/installments and BRL amount. `fact_reviews` retains score and both review timestamps. Review comments remain in Silver Unicode text; they do not enter the analytical fact.

`dm_sales_performance` is item-grain: old column names remain; `total_order_value` is the item's price + freight, despite its legacy name. It adds source item ID, month number, seller ID and order status. Never average `total_order_value` to calculate AOV. Legacy item-level payment/review fields are NULL; use the order mart or separate fact.

`dm_customer_insights` is order-grain: order/customer/geography/date, independently aggregated payment, selected review and satisfaction category. Added merchandise/freight/gross/item-count/status/review fields support order-based KPIs.

`silver_usd_brl_rates.rate_value` is the source SGS 10813 value. Legacy `bid_rate` and `ask_rate` remain NULL because this response supplies a single `valor`. Do not infer a bid/ask spread or convert BRL amounts without a verified rate-series definition and conversion policy. `silver_holidays.holiday_type` retains the JSON `types` array. IBGE states/regions are in `silver_states_regions`. Reference APIs do not join directly to item facts.

Category translation is retained in Bronze and legacy XLSX; the original Portuguese product category remains the analytical field. An English-name join would require a separately reviewed one-to-one mapping. Source table geolocation is not joined to facts: multiple observations per ZIP would multiply rows.
