-- Validated transactional full refresh. Existing target survives a rejected snapshot.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.bronze_products','U') IS NULL THROW 51000,'Missing Bronze input; run initialize and ingestion',1;
 IF OBJECT_ID('dbo.silver_products','U') IS NULL CREATE TABLE dbo.silver_products (
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
 CREATE TABLE #stage (
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
 INSERT INTO #stage (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT 
    LTRIM(RTRIM([Copy of product_id])) AS product_id, -- Maps from the correct shifted column
    ISNULL(LOWER(LTRIM(RTRIM([Copy of product_category_name]))), 'unknown') AS product_category_name,
    TRY_CAST(NULLIF(LTRIM(RTRIM(product_name_lenght)), '') AS INT) AS product_name_length,
    TRY_CAST(NULLIF(LTRIM(RTRIM(product_description_lenght)), '') AS INT) AS product_description_length,
    TRY_CAST(NULLIF(LTRIM(RTRIM(product_photos_qty)), '') AS INT) AS product_photos_qty,
    TRY_CAST(NULLIF(LTRIM(RTRIM(product_weight_g)), '') AS INT) AS product_weight_g,
    TRY_CAST(NULLIF(LTRIM(RTRIM(product_length_cm)), '') AS INT) AS product_length_cm,
    TRY_CAST(NULLIF(LTRIM(RTRIM(product_height_cm)), '') AS INT) AS product_height_cm,
    TRY_CAST(NULLIF(LTRIM(RTRIM(product_width_cm)), '') AS INT) AS product_width_cm
FROM dbo.bronze_products;
 IF NOT EXISTS(SELECT 1 FROM #stage) THROW 51000,'Empty source; refusing full refresh',1;
 IF EXISTS(SELECT 1 FROM #stage WHERE [product_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[product_id])))='') THROW 51000, 'silver_products: missing product_id', 1;
IF EXISTS(SELECT 1 FROM #stage GROUP BY [product_id] HAVING COUNT(*)>1) THROW 51000, 'silver_products: duplicate grain', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_products WHERE NULLIF(LTRIM(RTRIM(product_name_lenght)),'') IS NOT NULL AND TRY_CAST(product_name_lenght AS INT) IS NULL) THROW 51000, 'silver_products: failed conversion product_name_lenght', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_products WHERE NULLIF(LTRIM(RTRIM(product_description_lenght)),'') IS NOT NULL AND TRY_CAST(product_description_lenght AS INT) IS NULL) THROW 51000, 'silver_products: failed conversion product_description_lenght', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_products WHERE NULLIF(LTRIM(RTRIM(product_photos_qty)),'') IS NOT NULL AND TRY_CAST(product_photos_qty AS INT) IS NULL) THROW 51000, 'silver_products: failed conversion product_photos_qty', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_products WHERE NULLIF(LTRIM(RTRIM(product_weight_g)),'') IS NOT NULL AND TRY_CAST(product_weight_g AS INT) IS NULL) THROW 51000, 'silver_products: failed conversion product_weight_g', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_products WHERE NULLIF(LTRIM(RTRIM(product_length_cm)),'') IS NOT NULL AND TRY_CAST(product_length_cm AS INT) IS NULL) THROW 51000, 'silver_products: failed conversion product_length_cm', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_products WHERE NULLIF(LTRIM(RTRIM(product_height_cm)),'') IS NOT NULL AND TRY_CAST(product_height_cm AS INT) IS NULL) THROW 51000, 'silver_products: failed conversion product_height_cm', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_products WHERE NULLIF(LTRIM(RTRIM(product_width_cm)),'') IS NOT NULL AND TRY_CAST(product_width_cm AS INT) IS NULL) THROW 51000, 'silver_products: failed conversion product_width_cm', 1;
 DELETE FROM dbo.silver_products WITH (TABLOCKX);
 INSERT INTO dbo.silver_products (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
) SELECT 
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
 FROM #stage;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.silver_products') AND name='UX_silver_products_grain') CREATE UNIQUE INDEX UX_silver_products_grain ON dbo.silver_products(product_id);
 DROP TABLE #stage;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
