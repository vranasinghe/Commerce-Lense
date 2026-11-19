-- SQL Server 2016+ (OPENJSON requires compatibility level >=130).
USE master;
GO
IF DB_ID('olist_oltp') IS NULL CREATE DATABASE olist_oltp;
GO
IF DB_ID('olist_dw') IS NULL CREATE DATABASE olist_dw;
GO
USE olist_dw;
GO
IF OBJECT_ID('dbo.bronze_customers', 'U') IS NULL
CREATE TABLE dbo.bronze_customers (
    [customer_id] NVARCHAR(MAX) NULL,
    [customer_unique_id] NVARCHAR(MAX) NULL,
    [customer_zip_code_prefix] NVARCHAR(MAX) NULL,
    [customer_city] NVARCHAR(MAX) NULL,
    [customer_state] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_orders', 'U') IS NULL
CREATE TABLE dbo.bronze_orders (
    [Copy of order_id] NVARCHAR(MAX) NULL,
    [Copy of customer_id] NVARCHAR(MAX) NULL,
    [Copy of order_status] NVARCHAR(MAX) NULL,
    [Copy of order_purchase_timestamp] NVARCHAR(MAX) NULL,
    [Copy of order_approved_at] NVARCHAR(MAX) NULL,
    [Copy of order_delivered_carrier_date] NVARCHAR(MAX) NULL,
    [Copy of order_delivered_customer_date] NVARCHAR(MAX) NULL,
    [Copy of order_estimated_delivery_date] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_order_items', 'U') IS NULL
CREATE TABLE dbo.bronze_order_items (
    [Copy of order_id] NVARCHAR(MAX) NULL,
    [order_item_id] NVARCHAR(MAX) NULL,
    [Copy of product_id] NVARCHAR(MAX) NULL,
    [Copy of seller_id] NVARCHAR(MAX) NULL,
    [shipping_limit_date] NVARCHAR(MAX) NULL,
    [price] NVARCHAR(MAX) NULL,
    [freight_value] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_products', 'U') IS NULL
CREATE TABLE dbo.bronze_products (
    [Copy of product_id] NVARCHAR(MAX) NULL,
    [Copy of product_category_name] NVARCHAR(MAX) NULL,
    [product_name_lenght] NVARCHAR(MAX) NULL,
    [product_description_lenght] NVARCHAR(MAX) NULL,
    [product_photos_qty] NVARCHAR(MAX) NULL,
    [product_weight_g] NVARCHAR(MAX) NULL,
    [product_length_cm] NVARCHAR(MAX) NULL,
    [product_height_cm] NVARCHAR(MAX) NULL,
    [product_width_cm] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_sellers', 'U') IS NULL
CREATE TABLE dbo.bronze_sellers (
    [Copy of seller_id] NVARCHAR(MAX) NULL,
    [seller_zip_code_prefix] NVARCHAR(MAX) NULL,
    [Copy of seller_city] NVARCHAR(MAX) NULL,
    [Copy of seller_state] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_order_payments', 'U') IS NULL
CREATE TABLE dbo.bronze_order_payments (
    [Copy of order_id] NVARCHAR(MAX) NULL,
    [payment_sequential] NVARCHAR(MAX) NULL,
    [payment_type] NVARCHAR(MAX) NULL,
    [payment_installments] NVARCHAR(MAX) NULL,
    [payment_value] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_order_reviews', 'U') IS NULL
CREATE TABLE dbo.bronze_order_reviews (
    [Copy of review_id] NVARCHAR(MAX) NULL,
    [Copy of order_id] NVARCHAR(MAX) NULL,
    [review_score] NVARCHAR(MAX) NULL,
    [review_comment_title] NVARCHAR(MAX) NULL,
    [review_comment_message] NVARCHAR(MAX) NULL,
    [review_creation_date] NVARCHAR(MAX) NULL,
    [review_answer_timestamp] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_landing_geolocation', 'U') IS NULL
CREATE TABLE dbo.bronze_landing_geolocation (
    ["geolocation_zip_code_prefix"] NVARCHAR(MAX) NULL,
    ["geolocation_lat"] NVARCHAR(MAX) NULL,
    ["geolocation_lng"] NVARCHAR(MAX) NULL,
    ["geolocation_city"] NVARCHAR(MAX) NULL,
    ["geolocation_state"] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_category_translation', 'U') IS NULL
CREATE TABLE dbo.bronze_category_translation (
    [product_category_name] NVARCHAR(MAX) NULL,
    [product_category_name_english] NVARCHAR(MAX) NULL
);
GO
IF OBJECT_ID('dbo.bronze_landing_holidays', 'U') IS NULL
CREATE TABLE dbo.bronze_landing_holidays (raw_json NVARCHAR(MAX) NOT NULL CHECK(ISJSON(raw_json)=1));
GO
IF OBJECT_ID('dbo.bronze_landing_usd_brl_rates', 'U') IS NULL
CREATE TABLE dbo.bronze_landing_usd_brl_rates (raw_json NVARCHAR(MAX) NOT NULL CHECK(ISJSON(raw_json)=1));
GO
IF OBJECT_ID('dbo.bronze_landing_states_regions', 'U') IS NULL
CREATE TABLE dbo.bronze_landing_states_regions (raw_json NVARCHAR(MAX) NOT NULL CHECK(ISJSON(raw_json)=1));
GO
