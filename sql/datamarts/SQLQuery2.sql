-- Legacy API-table setup entry point. Prefer sql/bronze/initialize.sql.
USE olist_dw;
GO
IF OBJECT_ID('dbo.bronze_landing_holidays','U') IS NULL
CREATE TABLE dbo.bronze_landing_holidays(raw_json NVARCHAR(MAX) NOT NULL CHECK(ISJSON(raw_json)=1));
IF OBJECT_ID('dbo.bronze_landing_usd_brl_rates','U') IS NULL
CREATE TABLE dbo.bronze_landing_usd_brl_rates(raw_json NVARCHAR(MAX) NOT NULL CHECK(ISJSON(raw_json)=1));
