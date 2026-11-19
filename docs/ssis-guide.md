# SSIS audit and exact implementation checklist

The preserved `ssis/Olist_ETL/Bronze_Orders.dtsx` is well-formed XML with one executable: `SQL_Load_Bronze_Landing_Rates`. It truncates `bronze_landing_usd_brl_rates` and reads `C:\OlistDW\landing\api\usd_brl_rates.json` using server-side `OPENROWSET(..., SINGLE_CLOB)`. There are no saved item/customer/order/payment/review data flows in this package. OLTP and landing connection managers alone do not load data. `obj/Development/Package.dtsx` and the ISPAC are historical outputs, retained, not authoritative source.

**Do not run SSIS and Python against the same Bronze target concurrently.** The complete supported route is Python. To demonstrate the preserved SSIS rates task instead:

1. Open `Olist_ETL.dtproj` with Visual Studio Integration Services Projects matching the package's SQL Server 2025 target. Keep the original package as a reference and edit a copied package in the project.
2. Add project parameters `SqlServer` (String, default `.`), `WarehouseDatabase` (String, `olist_dw`), `LandingRoot` (String, `C:\OlistDW\landing`), and `RatesFileServerPath` (String, full path visible to SQL Server service).
3. Set the `LocalHost.olist_dw` connection-manager ConnectionString expression to construct the MSOLEDBSQL connection from server/database parameters, retaining integrated authentication. Parameterize `LocalHost.olist_oltp` separately if its flows are later implemented. Do not store credentials in project XML.
4. Set flat-file ConnectionString expressions to `@[$Project::LandingRoot] + "\\payments\\payments.csv"` and corresponding sellers/reviews/geolocation/API paths; set Excel file path through its connection-string expression. Inspect evaluated expressions in Visual Studio before executing.
5. Add an expression-backed String variable `RatesLoadSql` from `RatesFileServerPath`, escaping SQL single quotes with `REPLACE(parameter,"'","''")`. Set Execute SQL Task `SQLSourceType=Variable`, source `User::RatesLoadSql`. Use the transactional SQL below; do not substitute a client path for a server path.

```sql
SET XACT_ABORT ON;
BEGIN TRY
 BEGIN TRAN;
 DECLARE @json NVARCHAR(MAX);
 SELECT @json=BulkColumn
 FROM OPENROWSET(BULK 'SERVER_VISIBLE_PATH',SINGLE_CLOB,CODEPAGE='65001') AS j;
 IF ISJSON(@json)<>1 OR @json IS NULL THROW 51000,'Invalid rate JSON',1;
 IF NOT EXISTS(SELECT 1 FROM OPENJSON(@json)) THROW 51000,'Empty rate JSON',1;
 IF EXISTS(SELECT 1 FROM OPENJSON(@json) WITH(dt NVARCHAR(20) '$.data',val NVARCHAR(50) '$.valor')
 WHERE TRY_CONVERT(DATE,dt,103) IS NULL OR TRY_CONVERT(DECIMAL(18,4),val) IS NULL)
 THROW 51000,'Invalid SGS fields',1;
 DELETE FROM dbo.bronze_landing_usd_brl_rates WITH(TABLOCKX);
 INSERT dbo.bronze_landing_usd_brl_rates(raw_json) VALUES(@json);
 COMMIT;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
```

6. Confirm SQL Server service file read permissions and required bulk-read permissions under the package execution identity. Add pre-execution missing-file handling; remember the server reads the file, not the Visual Studio process.
7. Enable SSISDB basic logging; retain execution ID, source snapshot SHA-256, record count, status, and error details. Use environment references for deployed parameters. Configure failure precedence and stop downstream tasks on failure.
8. If demonstrating other sources, use the documented Python ingestion ownership unless you intentionally implement their missing SSIS flows. Do not parse NDJSON reviews or IBGE JSON using comma-delimited flat-file metadata. Use a JSON-capable Script Component or load whole JSON then `OPENJSON`. Set UTF-8/code page 65001 and CSV text qualifier `"` for actual CSVs; refresh external metadata and destination mappings. Redirect conversion errors to a quarantine destination and fail if required keys/amounts are rejected.
9. Validate using `dtexec /File ssis/Olist_ETL/Bronze_Orders.dtsx /Validate /Reporting E`. Then execute the edited copy against a test database; compare JSON contents/count, induce a missing-file failure, and prove old rows remain. Finally rerun the same snapshot and prove one Bronze JSON document remains.

Validation-only execution does not run the SQL task or prove file accessibility. See verification for the actual result. The original package remains byte-for-byte unchanged because the full edited workflow has not been executed and certified in Visual Studio.
