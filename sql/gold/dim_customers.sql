USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.dim_customers','U') IS NULL CREATE TABLE dbo.dim_customers (
    customer_key INT IDENTITY(1,1) PRIMARY KEY, 
    customer_id NVARCHAR(50),
    customer_unique_id NVARCHAR(50),
    customer_zip_code_prefix NVARCHAR(10),
    customer_city NVARCHAR(100),
    customer_state NVARCHAR(50)
);
 IF EXISTS(SELECT 1 FROM dbo.silver_customers WHERE customer_id IS NULL OR customer_id='') OR EXISTS(SELECT 1 FROM dbo.silver_customers GROUP BY customer_id HAVING COUNT(*)>1)
 THROW 51000,'Invalid dimension business keys',1;
 IF EXISTS(SELECT 1 FROM dbo.dim_customers WHERE customer_id IS NULL OR customer_id='') OR EXISTS(SELECT 1 FROM dbo.dim_customers GROUP BY customer_id HAVING COUNT(*)>1)
 THROW 51000,'Existing dimension requires controlled deduplication; no rows changed',1;
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.dim_customers') AND name='UX_dim_customers_business')
 CREATE UNIQUE INDEX UX_dim_customers_business ON dbo.dim_customers(customer_id);
 UPDATE d SET d.[customer_unique_id]=s.[customer_unique_id],
d.[customer_zip_code_prefix]=s.[customer_zip_code_prefix],
d.[customer_city]=s.[customer_city],
d.[customer_state]=s.[customer_state] FROM dbo.dim_customers d JOIN dbo.silver_customers s ON d.customer_id=s.customer_id;
 INSERT dbo.dim_customers ([customer_id],[customer_unique_id],[customer_zip_code_prefix],[customer_city],[customer_state])
 SELECT s.[customer_id],s.[customer_unique_id],s.[customer_zip_code_prefix],s.[customer_city],s.[customer_state] FROM dbo.silver_customers s
 WHERE NOT EXISTS(SELECT 1 FROM dbo.dim_customers d WITH(UPDLOCK,HOLDLOCK) WHERE d.customer_id=s.customer_id);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
