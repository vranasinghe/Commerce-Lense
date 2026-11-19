-- Validated transactional full refresh. Existing target survives a rejected snapshot.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.bronze_sellers','U') IS NULL THROW 51000,'Missing Bronze input; run initialize and ingestion',1;
 IF OBJECT_ID('dbo.silver_sellers','U') IS NULL CREATE TABLE dbo.silver_sellers (
    seller_id NVARCHAR(50),
    seller_zip_code_prefix NVARCHAR(10),
    seller_city NVARCHAR(100),
    seller_state NVARCHAR(10)
);
 CREATE TABLE #stage (
    seller_id NVARCHAR(50),
    seller_zip_code_prefix NVARCHAR(10),
    seller_city NVARCHAR(100),
    seller_state NVARCHAR(10)
);
 INSERT INTO #stage (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT 
    LTRIM(RTRIM([Copy of seller_id])) AS seller_id,
    LTRIM(RTRIM(seller_zip_code_prefix)) AS seller_zip_code_prefix,
    LTRIM(RTRIM([Copy of seller_city])) AS seller_city,
    UPPER(LTRIM(RTRIM([Copy of seller_state]))) AS seller_state
FROM dbo.bronze_sellers;
 IF NOT EXISTS(SELECT 1 FROM #stage) THROW 51000,'Empty source; refusing full refresh',1;
 IF EXISTS(SELECT 1 FROM #stage WHERE [seller_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[seller_id])))='') THROW 51000, 'silver_sellers: missing seller_id', 1;
IF EXISTS(SELECT 1 FROM #stage GROUP BY [seller_id] HAVING COUNT(*)>1) THROW 51000, 'silver_sellers: duplicate grain', 1;
 DELETE FROM dbo.silver_sellers WITH (TABLOCKX);
 INSERT INTO dbo.silver_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
) SELECT 
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
 FROM #stage;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.silver_sellers') AND name='UX_silver_sellers_grain') CREATE UNIQUE INDEX UX_silver_sellers_grain ON dbo.silver_sellers(seller_id);
 DROP TABLE #stage;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
