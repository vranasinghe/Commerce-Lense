-- Validated transactional full refresh. Existing target survives a rejected snapshot.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.bronze_order_items','U') IS NULL THROW 51000,'Missing Bronze input; run initialize and ingestion',1;
 IF OBJECT_ID('dbo.silver_order_items','U') IS NULL CREATE TABLE dbo.silver_order_items (
    order_id NVARCHAR(50),
    order_item_id INT,
    product_id NVARCHAR(50),
    seller_id NVARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(18, 2),
    freight_value DECIMAL(18, 2)
);
 CREATE TABLE #stage (
    order_id NVARCHAR(50),
    order_item_id INT,
    product_id NVARCHAR(50),
    seller_id NVARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(18, 2),
    freight_value DECIMAL(18, 2)
);
 INSERT INTO #stage (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT 
    LTRIM(RTRIM([Copy of order_id])) AS order_id,
    TRY_CAST(NULLIF(LTRIM(RTRIM(order_item_id)), '') AS INT) AS order_item_id,
    LTRIM(RTRIM([Copy of product_id])) AS product_id,
    LTRIM(RTRIM([Copy of seller_id])) AS seller_id,
    TRY_CAST(NULLIF(LTRIM(RTRIM(shipping_limit_date)), '') AS DATETIME) AS shipping_limit_date,
    TRY_CAST(NULLIF(LTRIM(RTRIM(price)), '') AS DECIMAL(18, 2)) AS price,
    TRY_CAST(NULLIF(LTRIM(RTRIM(freight_value)), '') AS DECIMAL(18, 2)) AS freight_value
FROM dbo.bronze_order_items;
 IF NOT EXISTS(SELECT 1 FROM #stage) THROW 51000,'Empty source; refusing full refresh',1;
 IF EXISTS(SELECT 1 FROM #stage WHERE [order_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[order_id])))='') THROW 51000, 'silver_order_items: missing order_id', 1;
IF EXISTS(SELECT 1 FROM #stage WHERE [order_item_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[order_item_id])))='') THROW 51000, 'silver_order_items: missing order_item_id', 1;
IF EXISTS(SELECT 1 FROM #stage GROUP BY [order_id],[order_item_id] HAVING COUNT(*)>1) THROW 51000, 'silver_order_items: duplicate grain', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_items WHERE NULLIF(LTRIM(RTRIM(order_item_id)),'') IS NOT NULL AND TRY_CAST(order_item_id AS INT) IS NULL) THROW 51000, 'silver_order_items: failed conversion order_item_id', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_items WHERE NULLIF(LTRIM(RTRIM(shipping_limit_date)),'') IS NOT NULL AND TRY_CAST(shipping_limit_date AS DATETIME) IS NULL) THROW 51000, 'silver_order_items: failed conversion shipping_limit_date', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_items WHERE NULLIF(LTRIM(RTRIM([price])),'') IS NOT NULL AND TRY_CONVERT(DECIMAL(18,2),[price]) IS NULL) THROW 51000, 'silver_order_items: invalid price', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_items WHERE NULLIF(LTRIM(RTRIM([freight_value])),'') IS NOT NULL AND TRY_CONVERT(DECIMAL(18,2),[freight_value]) IS NULL) THROW 51000, 'silver_order_items: invalid freight_value', 1;
IF EXISTS(SELECT 1 FROM #stage WHERE order_item_id<=0 OR price IS NULL OR price<0 OR freight_value IS NULL OR freight_value<0) THROW 51000, 'Invalid item values',1;
 DELETE FROM dbo.silver_order_items WITH (TABLOCKX);
 INSERT INTO dbo.silver_order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
) SELECT 
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
 FROM #stage;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.silver_order_items') AND name='UX_silver_order_items_grain') CREATE UNIQUE INDEX UX_silver_order_items_grain ON dbo.silver_order_items(order_id,order_item_id);
 DROP TABLE #stage;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
