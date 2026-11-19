USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.silver_states_regions','U') IS NULL
 CREATE TABLE dbo.silver_states_regions(state_code NVARCHAR(2) PRIMARY KEY,state_name NVARCHAR(100),region_name NVARCHAR(100));
 SELECT sigla state_code,nome state_name,region_name INTO #states
 FROM dbo.bronze_landing_states_regions b CROSS APPLY OPENJSON(b.raw_json)
 WITH(sigla NVARCHAR(2) '$.sigla',nome NVARCHAR(100) '$.nome',region_name NVARCHAR(100) '$.regiao.nome');
 IF (SELECT COUNT(*) FROM #states)<>27 OR EXISTS(SELECT 1 FROM #states WHERE state_code IS NULL OR region_name IS NULL)
 THROW 51000,'Expected 27 valid Brazilian states',1;
 IF EXISTS(SELECT 1 FROM #states GROUP BY state_code HAVING COUNT(*)>1) THROW 51000,'Duplicate state',1;
 DELETE FROM dbo.silver_states_regions WITH (TABLOCKX);
 INSERT dbo.silver_states_regions SELECT * FROM #states;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
