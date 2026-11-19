USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.dim_sellers','U') IS NULL CREATE TABLE dbo.dim_sellers (
    seller_key INT IDENTITY(1,1) PRIMARY KEY, 
    seller_id NVARCHAR(50),
    seller_zip_code_prefix NVARCHAR(10),
    seller_city NVARCHAR(100),
    seller_state NVARCHAR(50)
);
 IF EXISTS(SELECT 1 FROM dbo.silver_sellers WHERE seller_id IS NULL OR seller_id='') OR EXISTS(SELECT 1 FROM dbo.silver_sellers GROUP BY seller_id HAVING COUNT(*)>1)
 THROW 51000,'Invalid dimension business keys',1;
 IF EXISTS(SELECT 1 FROM dbo.dim_sellers WHERE seller_id IS NULL OR seller_id='') OR EXISTS(SELECT 1 FROM dbo.dim_sellers GROUP BY seller_id HAVING COUNT(*)>1)
 THROW 51000,'Existing dimension requires controlled deduplication; no rows changed',1;
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.dim_sellers') AND name='UX_dim_sellers_business')
 CREATE UNIQUE INDEX UX_dim_sellers_business ON dbo.dim_sellers(seller_id);
 UPDATE d SET d.[seller_zip_code_prefix]=s.[seller_zip_code_prefix],
d.[seller_city]=s.[seller_city],
d.[seller_state]=s.[seller_state] FROM dbo.dim_sellers d JOIN dbo.silver_sellers s ON d.seller_id=s.seller_id;
 INSERT dbo.dim_sellers ([seller_id],[seller_zip_code_prefix],[seller_city],[seller_state])
 SELECT s.[seller_id],s.[seller_zip_code_prefix],s.[seller_city],s.[seller_state] FROM dbo.silver_sellers s
 WHERE NOT EXISTS(SELECT 1 FROM dbo.dim_sellers d WITH(UPDLOCK,HOLDLOCK) WHERE d.seller_id=s.seller_id);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
