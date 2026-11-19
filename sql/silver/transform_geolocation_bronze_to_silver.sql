-- Validated transactional full refresh. Existing target survives a rejected snapshot.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRANSACTION;
 IF OBJECT_ID('dbo.bronze_landing_geolocation','U') IS NULL THROW 51000,'Missing Bronze input; run initialize and ingestion',1;
 IF OBJECT_ID('dbo.silver_geolocation','U') IS NULL CREATE TABLE dbo.silver_geolocation (
    geolocation_zip_code_prefix NVARCHAR(10),
    geolocation_lat FLOAT,
    geolocation_lng FLOAT,
    geolocation_city NVARCHAR(100),
    geolocation_state NVARCHAR(50) -- Expanded to 50 to safely handle any length
);
 CREATE TABLE #stage (
    geolocation_zip_code_prefix NVARCHAR(10),
    geolocation_lat FLOAT,
    geolocation_lng FLOAT,
    geolocation_city NVARCHAR(100),
    geolocation_state NVARCHAR(50) -- Expanded to 50 to safely handle any length
);
 INSERT INTO #stage (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT 
    LTRIM(RTRIM(["geolocation_zip_code_prefix"])) AS geolocation_zip_code_prefix,
    TRY_CAST(NULLIF(LTRIM(RTRIM(["geolocation_lat"])), '') AS FLOAT) AS geolocation_lat,
    TRY_CAST(NULLIF(LTRIM(RTRIM(["geolocation_lng"])), '') AS FLOAT) AS geolocation_lng,
    LTRIM(RTRIM(["geolocation_city"])) AS geolocation_city,
    UPPER(LTRIM(RTRIM(["geolocation_state"]))) AS geolocation_state
FROM dbo.bronze_landing_geolocation;
 IF NOT EXISTS(SELECT 1 FROM #stage) THROW 51000,'Empty source; refusing full refresh',1;
 IF EXISTS(SELECT 1 FROM dbo.bronze_landing_geolocation WHERE NULLIF(LTRIM(RTRIM(["geolocation_lat"])),'') IS NOT NULL AND TRY_CAST(["geolocation_lat"] AS FLOAT) IS NULL) THROW 51000, 'silver_geolocation: failed conversion ["geolocation_lat"]', 1;
IF EXISTS(SELECT 1 FROM dbo.bronze_landing_geolocation WHERE NULLIF(LTRIM(RTRIM(["geolocation_lng"])),'') IS NOT NULL AND TRY_CAST(["geolocation_lng"] AS FLOAT) IS NULL) THROW 51000, 'silver_geolocation: failed conversion ["geolocation_lng"]', 1;
IF EXISTS(SELECT 1 FROM #stage WHERE geolocation_lat NOT BETWEEN -90 AND 90 OR geolocation_lng NOT BETWEEN -180 AND 180) THROW 51000,'Invalid coordinates',1;
 DELETE FROM dbo.silver_geolocation WITH (TABLOCKX);
 INSERT INTO dbo.silver_geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
) SELECT 
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
 FROM #stage;
 DROP TABLE #stage;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
