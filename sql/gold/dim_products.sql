USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.dim_products','U') IS NULL CREATE TABLE dbo.dim_products (
    product_key INT IDENTITY(1,1) PRIMARY KEY, 
    product_id NVARCHAR(50),
    product_category_name NVARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);
 IF EXISTS(SELECT 1 FROM dbo.silver_products WHERE product_id IS NULL OR product_id='') OR EXISTS(SELECT 1 FROM dbo.silver_products GROUP BY product_id HAVING COUNT(*)>1)
 THROW 51000,'Invalid dimension business keys',1;
 IF EXISTS(SELECT 1 FROM dbo.dim_products WHERE product_id IS NULL OR product_id='') OR EXISTS(SELECT 1 FROM dbo.dim_products GROUP BY product_id HAVING COUNT(*)>1)
 THROW 51000,'Existing dimension requires controlled deduplication; no rows changed',1;
 IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.dim_products') AND name='UX_dim_products_business')
 CREATE UNIQUE INDEX UX_dim_products_business ON dbo.dim_products(product_id);
 UPDATE d SET d.[product_category_name]=s.[product_category_name],
d.[product_name_length]=s.[product_name_length],
d.[product_description_length]=s.[product_description_length],
d.[product_photos_qty]=s.[product_photos_qty],
d.[product_weight_g]=s.[product_weight_g],
d.[product_length_cm]=s.[product_length_cm],
d.[product_height_cm]=s.[product_height_cm],
d.[product_width_cm]=s.[product_width_cm] FROM dbo.dim_products d JOIN dbo.silver_products s ON d.product_id=s.product_id;
 INSERT dbo.dim_products ([product_id],[product_category_name],[product_name_length],[product_description_length],[product_photos_qty],[product_weight_g],[product_length_cm],[product_height_cm],[product_width_cm])
 SELECT s.[product_id],s.[product_category_name],s.[product_name_length],s.[product_description_length],s.[product_photos_qty],s.[product_weight_g],s.[product_length_cm],s.[product_height_cm],s.[product_width_cm] FROM dbo.silver_products s
 WHERE NOT EXISTS(SELECT 1 FROM dbo.dim_products d WITH(UPDLOCK,HOLDLOCK) WHERE d.product_id=s.product_id);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
