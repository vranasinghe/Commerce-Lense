-- Validated transactional full refresh. Existing target survives a rejected snapshot.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.bronze_customers','U') IS NULL THROW 51000,'Missing Bronze input; run initialize and ingestion',1;
 IF OBJECT_ID('dbo.silver_customers','U') IS NULL CREATE TABLE dbo.silver_customers (
    customer_id NVARCHAR(50),
    customer_unique_id NVARCHAR(50),
    customer_zip_code_prefix NVARCHAR(10),
    customer_city NVARCHAR(100),
    customer_state NVARCHAR(10)
);
 CREATE TABLE #stage (
    customer_id NVARCHAR(50),
    customer_unique_id NVARCHAR(50),
    customer_zip_code_prefix NVARCHAR(10),
    customer_city NVARCHAR(100),
    customer_state NVARCHAR(10)
);
 INSERT INTO #stage (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT 
    LTRIM(RTRIM(customer_id)) AS customer_id,
    LTRIM(RTRIM(customer_unique_id)) AS customer_unique_id,
    LTRIM(RTRIM(customer_zip_code_prefix)) AS customer_zip_code_prefix,
    -- Capitalize city names nicely or clean trailing spaces
    LTRIM(RTRIM(customer_city)) AS customer_city,
    UPPER(LTRIM(RTRIM(customer_state))) AS customer_state
FROM dbo.bronze_customers;
 IF NOT EXISTS(SELECT 1 FROM #stage) THROW 51000,'Empty source; refusing full refresh',1;
 IF EXISTS(SELECT 1 FROM #stage WHERE [customer_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[customer_id])))='') THROW 51000, 'silver_customers: missing customer_id', 1;
IF EXISTS(SELECT 1 FROM #stage GROUP BY [customer_id] HAVING COUNT(*)>1) THROW 51000, 'silver_customers: duplicate grain', 1;
 DELETE FROM dbo.silver_customers WITH (TABLOCKX);
 INSERT INTO dbo.silver_customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
) SELECT 
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
 FROM #stage;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.silver_customers') AND name='UX_silver_customers_grain') CREATE UNIQUE INDEX UX_silver_customers_grain ON dbo.silver_customers(customer_id);
 DROP TABLE #stage;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
