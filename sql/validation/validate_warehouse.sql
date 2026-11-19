USE olist_dw;
GO
SET NOCOUNT ON;
IF (SELECT COUNT_BIG(*) FROM dbo.bronze_customers)<>(SELECT COUNT_BIG(*) FROM dbo.silver_customers) THROW 51000,'silver_customers: Bronze count mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.bronze_orders)<>(SELECT COUNT_BIG(*) FROM dbo.silver_orders) THROW 51000,'silver_orders: Bronze count mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.bronze_order_items)<>(SELECT COUNT_BIG(*) FROM dbo.silver_order_items) THROW 51000,'silver_order_items: Bronze count mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.bronze_products)<>(SELECT COUNT_BIG(*) FROM dbo.silver_products) THROW 51000,'silver_products: Bronze count mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.bronze_sellers)<>(SELECT COUNT_BIG(*) FROM dbo.silver_sellers) THROW 51000,'silver_sellers: Bronze count mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.bronze_order_payments)<>(SELECT COUNT_BIG(*) FROM dbo.silver_order_payments) THROW 51000,'silver_order_payments: Bronze count mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.bronze_order_reviews)<>(SELECT COUNT_BIG(*) FROM dbo.silver_order_reviews) THROW 51000,'silver_order_reviews: Bronze count mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.bronze_landing_geolocation)<>(SELECT COUNT_BIG(*) FROM dbo.silver_geolocation) THROW 51000,'silver_geolocation: Bronze count mismatch',1;
IF EXISTS(SELECT 1 FROM dbo.fact_orders f
 LEFT JOIN dbo.dim_customers c ON f.customer_key=c.customer_key
 LEFT JOIN dbo.dim_products p ON f.product_key=p.product_key
 LEFT JOIN dbo.dim_sellers s ON f.seller_key=s.seller_key
 WHERE c.customer_key IS NULL OR p.product_key IS NULL OR s.seller_key IS NULL)
 THROW 51000,'Orphan dimension reference',1;
IF EXISTS(SELECT 1 FROM dbo.fact_payments p LEFT JOIN dbo.silver_orders o ON p.order_id=o.order_id WHERE o.order_id IS NULL)
 OR EXISTS(SELECT 1 FROM dbo.fact_reviews r LEFT JOIN dbo.silver_orders o ON r.order_id=o.order_id WHERE o.order_id IS NULL)
 THROW 51000,'Orphan payment/review',1;

IF (SELECT COUNT_BIG(*) FROM dbo.fact_orders)<>(SELECT COUNT_BIG(*) FROM dbo.silver_order_items)
 THROW 51000,'Fact item count differs from Silver',1;
IF EXISTS(SELECT 1 FROM dbo.fact_orders GROUP BY order_id,order_item_id HAVING COUNT(*)>1)
 THROW 51000,'Duplicate fact grain',1;
IF EXISTS(SELECT order_id,order_item_id,price,freight_value FROM dbo.silver_order_items EXCEPT SELECT order_id,order_item_id,price,freight_value FROM dbo.fact_orders)
 OR EXISTS(SELECT order_id,order_item_id,price,freight_value FROM dbo.fact_orders EXCEPT SELECT order_id,order_item_id,price,freight_value FROM dbo.silver_order_items)
 THROW 51000,'Item financial mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.fact_payments)<>(SELECT COUNT_BIG(*) FROM dbo.silver_order_payments)
 OR EXISTS(SELECT order_id,payment_sequential,payment_value FROM dbo.silver_order_payments EXCEPT SELECT order_id,payment_sequential,payment_value FROM dbo.fact_payments)
 THROW 51000,'Payment reconciliation mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.fact_reviews)<>(SELECT COUNT_BIG(*) FROM dbo.silver_order_reviews)
 THROW 51000,'Review reconciliation mismatch',1;
SELECT * INTO #customer_mart FROM dbo.dm_customer_insights;
CREATE UNIQUE INDEX UX_validation_order ON #customer_mart(order_id);
IF (SELECT COUNT_BIG(*) FROM #customer_mart)<>(SELECT COUNT_BIG(*) FROM dbo.silver_orders)
 OR EXISTS(SELECT 1 FROM #customer_mart GROUP BY order_id HAVING COUNT(*)>1)
 THROW 51000,'Order mart count or grain mismatch',1;
IF (SELECT COUNT_BIG(*) FROM dbo.dm_sales_performance)<>(SELECT COUNT_BIG(*) FROM dbo.fact_orders)
 THROW 51000,'Sales mart multiplied items',1;
IF EXISTS(SELECT 1 FROM dbo.silver_orders o LEFT JOIN dbo.dim_customers c ON o.customer_id=c.customer_id WHERE c.customer_key IS NULL)
 THROW 51000,'Unresolved order customer',1;
IF EXISTS(SELECT 1 FROM dbo.fact_orders f LEFT JOIN dbo.dim_date d ON f.order_purchase_date_key=d.date_key WHERE f.order_purchase_date_key IS NOT NULL AND d.date_key IS NULL)
 THROW 51000,'Invalid purchase date FK',1;
DBCC CHECKCONSTRAINTS ('dbo.fact_orders') WITH ALL_CONSTRAINTS;
-- Separate finances: a difference is diagnostic, not an automatic error.
SELECT SUM(merchandise_value) merchandise_brl,SUM(freight_value) freight_brl,
 SUM(gross_order_value) gross_brl,SUM(payment_value) payments_brl,
 SUM(COALESCE(payment_value,0)-gross_order_value) payment_gross_difference_brl
FROM #customer_mart;
SELECT order_status,COUNT_BIG(*) orders,SUM(merchandise_value) merchandise_brl FROM #customer_mart GROUP BY order_status;
SELECT COUNT_BIG(*) total_orders,COUNT(DISTINCT customer_unique_id) unique_customers,
 AVG(CONVERT(DECIMAL(18,6),review_score)) latest_review_average,
 SUM(merchandise_value)/NULLIF(CONVERT(DECIMAL(18,6),COUNT_BIG(*)),0) merchandise_aov_brl
FROM #customer_mart;
DROP TABLE #customer_mart;
SELECT 'Warehouse assertions passed' result;
GO
