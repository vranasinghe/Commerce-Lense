-- Validated transactional full refresh. Existing target survives a rejected snapshot.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.bronze_orders','U') IS NULL THROW 51000,'Missing Bronze input; run initialize and ingestion',1;
 IF OBJECT_ID('dbo.silver_orders','U') IS NULL CREATE TABLE dbo.silver_orders (
    order_id NVARCHAR(50),
    customer_id NVARCHAR(50),
    order_status NVARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);
 CREATE TABLE #stage (
    order_id NVARCHAR(50),
    customer_id NVARCHAR(50),
    order_status NVARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);
 INSERT INTO #stage (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT 
    LTRIM(RTRIM([Copy of order_id])) AS order_id,
    LTRIM(RTRIM([Copy of customer_id])) AS customer_id,
    ISNULL(LOWER(LTRIM(RTRIM([Copy of order_status]))), 'unknown') AS order_status,
    TRY_CAST(NULLIF(LTRIM(RTRIM([Copy of order_purchase_timestamp])), '') AS DATETIME) AS order_purchase_timestamp,
    TRY_CAST(NULLIF(LTRIM(RTRIM([Copy of order_approved_at])), '') AS DATETIME) AS order_approved_at,
    TRY_CAST(NULLIF(LTRIM(RTRIM([Copy of order_delivered_carrier_date])), '') AS DATETIME) AS order_delivered_carrier_date,
    TRY_CAST(NULLIF(LTRIM(RTRIM([Copy of order_delivered_customer_date])), '') AS DATETIME) AS order_delivered_customer_date,
    TRY_CAST(NULLIF(LTRIM(RTRIM([Copy of order_estimated_delivery_date])), '') AS DATETIME) AS order_estimated_delivery_date
FROM dbo.bronze_orders;
 IF NOT EXISTS(SELECT 1 FROM #stage) THROW 51000,'Empty source; refusing full refresh',1;
 IF EXISTS(SELECT 1 FROM #stage WHERE [order_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[order_id])))='') THROW 51000, 'silver_orders: missing order_id', 1;
IF EXISTS(SELECT 1 FROM #stage GROUP BY [order_id] HAVING COUNT(*)>1) THROW 51000, 'silver_orders: duplicate grain', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_orders WHERE NULLIF(LTRIM(RTRIM([Copy of order_purchase_timestamp])),'') IS NOT NULL AND TRY_CAST([Copy of order_purchase_timestamp] AS DATETIME) IS NULL) THROW 51000, 'silver_orders: failed conversion [Copy of order_purchase_timestamp]', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_orders WHERE NULLIF(LTRIM(RTRIM([Copy of order_approved_at])),'') IS NOT NULL AND TRY_CAST([Copy of order_approved_at] AS DATETIME) IS NULL) THROW 51000, 'silver_orders: failed conversion [Copy of order_approved_at]', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_orders WHERE NULLIF(LTRIM(RTRIM([Copy of order_delivered_carrier_date])),'') IS NOT NULL AND TRY_CAST([Copy of order_delivered_carrier_date] AS DATETIME) IS NULL) THROW 51000, 'silver_orders: failed conversion [Copy of order_delivered_carrier_date]', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_orders WHERE NULLIF(LTRIM(RTRIM([Copy of order_delivered_customer_date])),'') IS NOT NULL AND TRY_CAST([Copy of order_delivered_customer_date] AS DATETIME) IS NULL) THROW 51000, 'silver_orders: failed conversion [Copy of order_delivered_customer_date]', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_orders WHERE NULLIF(LTRIM(RTRIM([Copy of order_estimated_delivery_date])),'') IS NOT NULL AND TRY_CAST([Copy of order_estimated_delivery_date] AS DATETIME) IS NULL) THROW 51000, 'silver_orders: failed conversion [Copy of order_estimated_delivery_date]', 1;
 DELETE FROM dbo.silver_orders WITH (TABLOCKX);
 INSERT INTO dbo.silver_orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
) SELECT 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
 FROM #stage;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.silver_orders') AND name='UX_silver_orders_grain') CREATE UNIQUE INDEX UX_silver_orders_grain ON dbo.silver_orders(order_id);
 DROP TABLE #stage;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
