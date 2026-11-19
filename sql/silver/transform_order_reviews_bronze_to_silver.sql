-- Validated transactional full refresh. Existing target survives a rejected snapshot.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.bronze_order_reviews','U') IS NULL THROW 51000,'Missing Bronze input; run initialize and ingestion',1;
 IF OBJECT_ID('dbo.silver_order_reviews','U') IS NULL CREATE TABLE dbo.silver_order_reviews (
    review_id NVARCHAR(50),
    order_id NVARCHAR(50),
    review_score INT,
    review_comment_title NVARCHAR(255),
    review_comment_message NVARCHAR(MAX),
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);
 CREATE TABLE #stage (
    review_id NVARCHAR(50),
    order_id NVARCHAR(50),
    review_score INT,
    review_comment_title NVARCHAR(255),
    review_comment_message NVARCHAR(MAX),
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);
 INSERT INTO #stage (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT 
    LTRIM(RTRIM([Copy of review_id])) AS review_id,
    LTRIM(RTRIM([Copy of order_id])) AS order_id,
    TRY_CAST(NULLIF(LTRIM(RTRIM(review_score)), '') AS INT) AS review_score,
    LTRIM(RTRIM(review_comment_title)) AS review_comment_title,
    LTRIM(RTRIM(review_comment_message)) AS review_comment_message,
    TRY_CAST(NULLIF(LTRIM(RTRIM(review_creation_date)), '') AS DATETIME) AS review_creation_date,
    TRY_CAST(NULLIF(LTRIM(RTRIM(review_answer_timestamp)), '') AS DATETIME) AS review_answer_timestamp
FROM dbo.bronze_order_reviews;
 IF NOT EXISTS(SELECT 1 FROM #stage) THROW 51000,'Empty source; refusing full refresh',1;
 IF EXISTS(SELECT 1 FROM #stage WHERE [review_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[review_id])))='') THROW 51000, 'silver_order_reviews: missing review_id', 1;
IF EXISTS(SELECT 1 FROM #stage WHERE [order_id] IS NULL OR LTRIM(RTRIM(CONVERT(NVARCHAR(MAX),[order_id])))='') THROW 51000, 'silver_order_reviews: missing order_id', 1;
IF EXISTS(SELECT 1 FROM #stage GROUP BY [review_id],[order_id] HAVING COUNT(*)>1) THROW 51000, 'silver_order_reviews: duplicate grain', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_reviews WHERE NULLIF(LTRIM(RTRIM(review_score)),'') IS NOT NULL AND TRY_CAST(review_score AS INT) IS NULL) THROW 51000, 'silver_order_reviews: failed conversion review_score', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_reviews WHERE NULLIF(LTRIM(RTRIM(review_creation_date)),'') IS NOT NULL AND TRY_CAST(review_creation_date AS DATETIME) IS NULL) THROW 51000, 'silver_order_reviews: failed conversion review_creation_date', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_order_reviews WHERE NULLIF(LTRIM(RTRIM(review_answer_timestamp)),'') IS NOT NULL AND TRY_CAST(review_answer_timestamp AS DATETIME) IS NULL) THROW 51000, 'silver_order_reviews: failed conversion review_answer_timestamp', 1;
IF EXISTS(SELECT 1 FROM #stage WHERE review_score IS NULL OR review_score NOT BETWEEN 1 AND 5) THROW 51000,'Invalid review score',1;
 DELETE FROM dbo.silver_order_reviews WITH (TABLOCKX);
 INSERT INTO dbo.silver_order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
) SELECT 
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
 FROM #stage;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.silver_order_reviews') AND name='UX_silver_order_reviews_grain') CREATE UNIQUE INDEX UX_silver_order_reviews_grain ON dbo.silver_order_reviews(order_id,review_id);
 DROP TABLE #stage;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
