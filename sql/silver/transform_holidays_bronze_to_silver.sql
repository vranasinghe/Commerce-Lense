USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.silver_holidays','U') IS NULL
 CREATE TABLE dbo.silver_holidays(holiday_date DATE,local_name NVARCHAR(255),name NVARCHAR(255),country_code NVARCHAR(10),is_fixed BIT,is_global BIT,holiday_type NVARCHAR(100));
 SELECT TRY_CONVERT(DATE,j.dt,23) holiday_date,j.localName local_name,j.name,j.countryCode country_code,
 CASE j.fixed WHEN 'true' THEN CAST(1 AS BIT) WHEN 'false' THEN CAST(0 AS BIT) END is_fixed,
 CASE j.glob WHEN 'true' THEN CAST(1 AS BIT) WHEN 'false' THEN CAST(0 AS BIT) END is_global,
 j.types holiday_type
 INTO #holidays
 FROM dbo.bronze_landing_holidays b CROSS APPLY OPENJSON(b.raw_json)
 WITH(dt NVARCHAR(20) '$.date',localName NVARCHAR(255) '$.localName',name NVARCHAR(255) '$.name',countryCode NVARCHAR(10) '$.countryCode',fixed NVARCHAR(10) '$.fixed',glob NVARCHAR(10) '$.global',types NVARCHAR(MAX) '$.types' AS JSON) j;
 IF NOT EXISTS(SELECT 1 FROM #holidays) OR EXISTS(SELECT 1 FROM #holidays WHERE holiday_date IS NULL OR country_code<>'BR' OR holiday_type IS NULL OR LEN(holiday_type)>100)
 THROW 51000,'Invalid or empty holiday snapshot',1;
 DELETE FROM dbo.silver_holidays WITH (TABLOCKX);
 INSERT dbo.silver_holidays SELECT * FROM #holidays;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
