-- Explicit one-time migration after a verified SQL Server backup.
-- Keeps original rows, keys and columns for comparison. No table is dropped.
-- Apply the new fact and mart scripts immediately afterwards before refreshing Power BI.
USE olist_dw;
GO
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.fact_orders','U') IS NOT NULL AND COL_LENGTH('dbo.fact_orders','order_item_key') IS NULL
 BEGIN
  IF OBJECT_ID('dbo.fact_orders_legacy','U') IS NOT NULL THROW 51000,'Legacy archive already exists; inspect manually',1;
  EXEC sys.sp_rename 'dbo.fact_orders','fact_orders_legacy';
 END;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
