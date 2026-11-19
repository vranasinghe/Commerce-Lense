USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.silver_usd_brl_rates','U') IS NULL
 CREATE TABLE dbo.silver_usd_brl_rates(rate_date DATE, bid_rate DECIMAL(18,4), ask_rate DECIMAL(18,4));
 IF COL_LENGTH('dbo.silver_usd_brl_rates','rate_value') IS NULL
 EXEC('ALTER TABLE dbo.silver_usd_brl_rates ADD rate_value DECIMAL(18,4) NULL');
 -- Dynamic SQL compiles after the additive migration on existing installations.
 EXEC(N'
 SELECT TRY_CONVERT(DATE,j.dt,103) rate_date,
        TRY_CONVERT(DECIMAL(18,4),REPLACE(j.val,'','', ''.'')) rate_value
 INTO #rates
 FROM dbo.bronze_landing_usd_brl_rates b
 CROSS APPLY OPENJSON(b.raw_json) WITH(dt NVARCHAR(20) ''$.data'',val NVARCHAR(50) ''$.valor'') j;
 IF NOT EXISTS(SELECT 1 FROM #rates) OR EXISTS(SELECT 1 FROM #rates WHERE rate_date IS NULL OR rate_value IS NULL OR rate_value<=0)
 THROW 51000,''Invalid or empty SGS snapshot'',1;
 IF EXISTS(SELECT 1 FROM #rates GROUP BY rate_date HAVING COUNT(*)>1) THROW 51000,''Duplicate SGS date'',1;
 DELETE FROM dbo.silver_usd_brl_rates WITH (TABLOCKX);
 INSERT dbo.silver_usd_brl_rates(rate_date,rate_value,bid_rate,ask_rate)
 SELECT rate_date,rate_value,NULL,NULL FROM #rates;
 ');
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
