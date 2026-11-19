-- Item grain: exactly one row per (order_id, source order_item_id).
USE olist_dw;
GO
SET XACT_ABORT ON;
IF OBJECT_ID('dbo.fact_orders','U') IS NOT NULL AND COL_LENGTH('dbo.fact_orders','order_item_key') IS NULL
 THROW 51000,'Legacy fact detected. Back up database and run sql/migrations/001_archive_legacy_fact.sql first.',1;
GO
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.fact_orders','U') IS NULL
 CREATE TABLE dbo.fact_orders(
 order_item_key BIGINT IDENTITY PRIMARY KEY,
 order_id VARCHAR(50) NOT NULL, order_item_id INT NOT NULL,
 customer_key INT NOT NULL REFERENCES dbo.dim_customers(customer_key),
 product_key INT NOT NULL REFERENCES dbo.dim_products(product_key),
 seller_key INT NOT NULL REFERENCES dbo.dim_sellers(seller_key),
 order_purchase_date_key INT NULL REFERENCES dbo.dim_date(date_key),
 price DECIMAL(18,2) NOT NULL,freight_value DECIMAL(18,2) NOT NULL,
 -- Compatibility columns: never allocate payments or weight reviews by items.
 payment_value DECIMAL(18,2) NULL CHECK(payment_value IS NULL),
 review_score INT NULL CHECK(review_score IS NULL),
 UNIQUE(order_id,order_item_id));
 IF OBJECT_ID('dbo.fact_payments','U') IS NULL
 CREATE TABLE dbo.fact_payments(order_id VARCHAR(50) NOT NULL,payment_sequential INT NOT NULL,payment_type NVARCHAR(50),payment_installments INT,payment_value DECIMAL(18,2) NOT NULL,PRIMARY KEY(order_id,payment_sequential));
 IF OBJECT_ID('dbo.fact_reviews','U') IS NULL
 CREATE TABLE dbo.fact_reviews(order_id VARCHAR(50) NOT NULL,review_id VARCHAR(50) NOT NULL,review_score INT NOT NULL CHECK(review_score BETWEEN 1 AND 5),review_creation_date DATETIME,review_answer_timestamp DATETIME,PRIMARY KEY(order_id,review_id));
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.fact_reviews') AND name='IX_fact_reviews_latest')
 CREATE INDEX IX_fact_reviews_latest ON dbo.fact_reviews(order_id,review_answer_timestamp DESC,review_creation_date DESC,review_id DESC) INCLUDE(review_score);
 IF EXISTS(SELECT 1 FROM dbo.silver_orders GROUP BY order_id HAVING COUNT(*)>1)
 THROW 51000,'Duplicate Silver orders',1;
 IF EXISTS(SELECT 1 FROM dbo.silver_order_items GROUP BY order_id,order_item_id HAVING COUNT(*)>1)
 THROW 51000,'Duplicate Silver items',1;
 IF EXISTS(SELECT 1 FROM dbo.silver_order_payments p LEFT JOIN dbo.silver_orders o ON p.order_id=o.order_id WHERE o.order_id IS NULL)
 OR EXISTS(SELECT 1 FROM dbo.silver_order_reviews r LEFT JOIN dbo.silver_orders o ON r.order_id=o.order_id WHERE o.order_id IS NULL)
 THROW 51000,'Orphan payment or review',1;
 -- Resolve every dimension before deleting any previous fact snapshot.
 SELECT i.order_id,i.order_item_id,c.customer_key,p.product_key,s.seller_key,
 CONVERT(INT,CONVERT(CHAR(8),o.order_purchase_timestamp,112)) order_purchase_date_key,
 i.price,i.freight_value,o.order_id matched_order
 INTO #items
 FROM dbo.silver_order_items i
 LEFT JOIN dbo.silver_orders o ON i.order_id=o.order_id
 LEFT JOIN dbo.dim_customers c ON o.customer_id=c.customer_id
 LEFT JOIN dbo.dim_products p ON i.product_id=p.product_id
 LEFT JOIN dbo.dim_sellers s ON i.seller_id=s.seller_id;
 IF NOT EXISTS(SELECT 1 FROM #items) THROW 51000,'Empty item snapshot',1;
 IF EXISTS(SELECT 1 FROM #items i LEFT JOIN dbo.dim_date d ON i.order_purchase_date_key=d.date_key
 WHERE matched_order IS NULL OR customer_key IS NULL OR product_key IS NULL OR seller_key IS NULL OR (i.order_purchase_date_key IS NOT NULL AND d.date_key IS NULL) OR price IS NULL OR freight_value IS NULL)
 THROW 51000,'Unresolved fact references or amounts; previous snapshot retained',1;
 IF (SELECT COUNT_BIG(*) FROM #items)<>(SELECT COUNT_BIG(*) FROM dbo.silver_order_items)
 THROW 51000,'Item join multiplied rows',1;
 DELETE FROM dbo.fact_orders WITH(TABLOCKX);
 INSERT dbo.fact_orders(order_id,order_item_id,customer_key,product_key,seller_key,order_purchase_date_key,price,freight_value)
 SELECT order_id,order_item_id,customer_key,product_key,seller_key,order_purchase_date_key,price,freight_value FROM #items;
 DELETE FROM dbo.fact_payments WITH(TABLOCKX);
 INSERT dbo.fact_payments SELECT order_id,payment_sequential,payment_type,payment_installments,payment_value FROM dbo.silver_order_payments;
 DELETE FROM dbo.fact_reviews WITH(TABLOCKX);
 INSERT dbo.fact_reviews SELECT order_id,review_id,review_score,review_creation_date,review_answer_timestamp FROM dbo.silver_order_reviews;
 IF (SELECT SUM(price) FROM dbo.fact_orders)<>(SELECT SUM(price) FROM dbo.silver_order_items)
 OR (SELECT SUM(freight_value) FROM dbo.fact_orders)<>(SELECT SUM(freight_value) FROM dbo.silver_order_items)
 OR (SELECT SUM(payment_value) FROM dbo.fact_payments)<>(SELECT SUM(payment_value) FROM dbo.silver_order_payments)
 THROW 51000,'Financial reconciliation failed',1;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
