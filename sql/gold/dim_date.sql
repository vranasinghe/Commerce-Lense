USE olist_dw;
GO
SET XACT_ABORT ON;
SET LANGUAGE us_english;
SET DATEFIRST 1;
BEGIN TRY
 BEGIN TRAN;
 IF OBJECT_ID('dbo.dim_date','U') IS NULL
 CREATE TABLE dbo.dim_date(date_key INT PRIMARY KEY,full_date DATE UNIQUE,day_of_week INT,day_name VARCHAR(15),day_of_month INT,month_number INT,month_name VARCHAR(15),quarter_number INT,year_number INT);
 -- Unknown timestamps use a NULL FK; there is no fabricated 1900 date.
 DECLARE @start DATE,@end DATE;
 SELECT @start=MIN(dt),@end=MAX(dt) FROM dbo.silver_orders
 CROSS APPLY(VALUES(CONVERT(DATE,order_purchase_timestamp)),(CONVERT(DATE,order_approved_at)),(CONVERT(DATE,order_delivered_carrier_date)),(CONVERT(DATE,order_delivered_customer_date)),(CONVERT(DATE,order_estimated_delivery_date))) v(dt);
 IF @start IS NULL THROW 51000,'No source dates; load Silver first',1;
 -- Extend to full calendar years for continuous Power BI time intelligence.
 SET @start=DATEFROMPARTS(YEAR(@start),1,1); SET @end=DATEFROMPARTS(YEAR(@end),12,31);
 ;WITH dates AS(SELECT @start dt UNION ALL SELECT DATEADD(DAY,1,dt) FROM dates WHERE dt<@end)
 INSERT dbo.dim_date
 SELECT CONVERT(INT,CONVERT(CHAR(8),dt,112)),dt,DATEPART(WEEKDAY,dt),DATENAME(WEEKDAY,dt),DAY(dt),MONTH(dt),DATENAME(MONTH,dt),DATEPART(QUARTER,dt),YEAR(dt)
 FROM dates WHERE NOT EXISTS(SELECT 1 FROM dbo.dim_date d WHERE d.full_date=dt)
 OPTION(MAXRECURSION 0);
 -- Normalize retained members as well as new rows (original calendar depended on DATEFIRST).
 UPDATE dbo.dim_date SET day_of_week=DATEPART(WEEKDAY,full_date),day_name=DATENAME(WEEKDAY,full_date),
 day_of_month=DAY(full_date),month_number=MONTH(full_date),month_name=DATENAME(MONTH,full_date),
 quarter_number=DATEPART(QUARTER,full_date),year_number=YEAR(full_date)
 WHERE full_date IS NOT NULL;
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
GO
