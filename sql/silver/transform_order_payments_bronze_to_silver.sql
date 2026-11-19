-- Validated transactional full refresh. Existing target survives a rejected snapshot.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.bronze_order_payments','U') IS NULL THROW 51000,'Missing Bronze input; run initialize and ingestion',1;
 IF OBJECT_ID('dbo.silver_order_payments','U') IS NULL CREATE TABLE dbo.silver_order_payments (
    order_id NVARCHAR(50),
    payment_sequential INT,
    payment_type NVARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(18, 2)
);
 CREATE TABLE #stage (
    order_id NVARCHAR(50),
    payment_sequential INT,
    payment_type NVARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(18, 2)
);
 INSERT INTO #stage (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT 
    LTRIM(RTRIM([Copy of order_id])) AS order_id,
    TRY_CAST(NULLIF(LTRIM(RTRIM(payment_sequential)), '') AS INT) AS payment_sequential,
    ISNULL(LOWER(LTRIM(RTRIM(payment_type))), 'unknown') AS payment_type,
    TRY_CAST(NULLIF(LTRIM(RTRIM(payment_installments)), '') AS INT) AS payment_installments,
    TRY_CAST(NULLIF(LTRIM(RTRIM(payment_value)), '') AS DECIMAL(18, 2)) AS payment_value
FROM dbo.bronze_order_payments;
 IF NOT EXISTS(SELECT 1 FROM #stage) THROW 51000,'Empty source; refusing full refresh',1;
 IF EXISTS(SELECT 1 FROM #stage WHERE [order_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[order_id])))='') THROW 51000, 'silver_order_payments: missing order_id', 1;
IF EXISTS(SELECT 1 FROM #stage WHERE [payment_sequential] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[payment_sequential])))='') THROW 51000, 'silver_order_payments: missing payment_sequential', 1;
IF EXISTS(SELECT 1 FROM #stage GROUP BY [order_id],[payment_sequential] HAVING COUNT(*)>1) THROW 51000, 'silver_order_payments: duplicate grain', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_payments WHERE NULLIF(LTRIM(RTRIM(payment_sequential)),'') IS NOT NULL AND TRY_CAST(payment_sequential AS INT) IS NULL) THROW 51000, 'silver_order_payments: failed conversion payment_sequential', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_payments WHERE NULLIF(LTRIM(RTRIM(payment_installments)),'') IS NOT NULL AND TRY_CAST(payment_installments AS INT) IS NULL) THROW 51000, 'silver_order_payments: failed conversion payment_installments', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_payments WHERE NULLIF(LTRIM(RTRIM([payment_value])),'') IS NOT NULL AND TRY_CONVERT(DECIMAL(18,2),[payment_value]) IS NULL) THROW 51000, 'silver_order_payments: invalid payment_value', 1;
IF EXISTS(SELECT 1 FROM #stage WHERE payment_value IS NULL OR payment_value<0 OR payment_sequential<1 OR payment_installments<0) THROW 51000,'Invalid payment values',1;
 DELETE FROM dbo.silver_order_payments WITH (TABLOCKX);
 INSERT INTO dbo.silver_order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
) SELECT 
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
 FROM #stage;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.silver_order_payments') AND name='UX_silver_order_payments_grain') CREATE UNIQUE INDEX UX_silver_order_payments_grain ON dbo.silver_order_payments(order_id,payment_sequential);
 DROP TABLE #stage;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
