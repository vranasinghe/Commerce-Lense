# Verification report — 19 November 2026

## Executed environment

Python 3.14.3 on Windows; Pandas 3.0.1; SQLAlchemy 2.0.46; Requests 2.32.5; OpenPyXL 3.1.5; PyODBC 5.5.0. SQL Server 2025 RTM Developer, ODBC Driver 17 for Python and Driver 18 for sqlcmd. Exact Python packages are in `requirements-tested.txt`. SQLAlchemy emitted an unrecognized-server-version warning for SQL Server 17.0; the explicitly listed checks nevertheless executed. Other Python/SQL Server versions were not certified.

Local SQL access required execution outside the filesystem/network sandbox. The original accessible instance had neither olist_oltp nor olist_dw; those two project databases were initialized and loaded for verification. Other databases were not changed.

## Passed

1. All nine raw files read successfully; actual parsed counts/headers match `baseline/sources.json`. All original raw CSV, SSIS package/binary and original PBIX hashes match the preservation manifest.
2. Source profiling and independent reconciliation ran. No source order/item/payment/review/customer/product/seller reference orphans were found. IDs and ZIP prefixes remain strings.
3. The original item/payment/review join was reproduced against the CSVs: **118,310 rows** versus **112,650 items**. Merchandise increases from **BRL 13,591,643.70** to **BRL 14,273,699.65** under that join: **BRL 682,055.95** overstatement. These are raw-data calculations, not claimed refreshed dashboard results.
4. Python Bronze ingestion committed all nine datasets, including 1,000,163 geolocation observations. The preserved seven-table OLTP route committed the expected records. A repeated Bronze load without `--refresh` exited nonzero on populated `bronze_customers`; that was the expected guard behavior.
5. The complete SQL build ran against actual data: typed Silver, stable dimensions, item/payment/review facts, order summary and both marts. SQL assertions passed. Final source totals: merchandise **13,591,643.70**, freight **2,251,909.54**, gross **15,843,553.24**, payments **16,008,872.12**, payment minus gross **165,318.88** (all BRL, all statuses).
6. SQL outputs reconcile to 99,441 orders, 96,096 unique customers, order-based merchandise AOV **136.680480…**, and latest-review average **4.086386…**. Facts contain 112,650 item records, 103,886 payment records, and 99,224 review events. The order mart has one row per order.
7. Public APIs were fetched successfully: 27 IBGE state/region records, 42 Nager.Date Brazilian holiday records across 2016–2018, and 750 BCB SGS observations across 2016–2018. Actual records expose `data`/`valor`; holiday types are arrays. Digest-matched API loading and all three SQL parsers executed. Bid/ask remain NULL. This verifies response shape, not a policy for financial currency conversion.
8. API mock tests rejected bad rates and non-array holiday types, retained previous files on failure, and refused to publish partially fetched holiday years.
9. **13 automated Python/report-contract tests passed**. Sellers TXT, review NDJSON, category XLSX, and copied CSV round trips passed. All three report page names and all 31 original container IDs are retained; every changed measure projection resolves to a defined measure and registered resources exist.
10. The opt-in SQL failure-injection test changed one Bronze price to invalid text. The runner rejected it, the committed warehouse fingerprint stayed unchanged, and the original Bronze price was restored in `finally`. An identical snapshot rerun passed. This test found and drove correction of deferred ODBC errors that SQLAlchemy could hide after a non-row initial result. The final runner explicitly drains every ODBC result set.
11. A second opt-in test set one Bronze purchase timestamp to an empty string inside an outer transaction. Silver produced NULL, the nullable date FK accepted it, and its item remained in the sales mart with a NULL date. All changes were rolled back. Evidence: `verification/unknown-date.json`.
12. `dtexec /File .../Bronze_Orders.dtsx /Validate /Reporting E` returned **DTSER_SUCCESS (0)**. This was validation only.
13. Power BI Desktop opened the original PBIX and exported a separate CommerceLens PBIP. Microsoft TOM inspected the original live semantic model. Microsoft's TMDL deserializer parsed the updated project: 7 tables and 16 measures. All edited PBIR JSON parses successfully. The design detector reported no findings for the report definition.

## Not executed / not certified

- **Updated Power BI Desktop refresh, DAX execution, slicer interactions and rendered visual QA remain pending.** After export, external-change reload was visible, but the native automation helper repeatedly reported minimized windows and detected input, including after a user-assisted restore. The revised project files are supplied with an exact Desktop acceptance checklist; they must not be described as a refreshed, visually certified PBIX. No updated binary report or fabricated screenshots are supplied.
- The original SSIS load task was not executed. Its server-side hardcoded file path, transaction behavior and parameterized deployment require the Visual Studio steps in `ssis-guide.md`. Validation success is not execution success.
- The one-time legacy-fact migration was not rehearsed against an existing populated legacy warehouse because none was available locally. Existing deployment-specific Bronze schemas and dimension duplicate remediation remain controlled migration work.
- A fresh-machine installation and all dependency-range combinations were not tested. A local workspace runtime folder supplied the missing PyODBC dependency; it is ignored and is not a portable environment.
- No USD conversion, incremental ingestion, SCD history, or production concurrency certification was implemented or claimed.

## Evidence and reproducibility

Read `verification/python-tests.txt`, `sql-validation.txt`, `api-sql.txt`, `integration-sql.json`, `unknown-date.json`, `source-reconciliation.json`, `profile.json`, `source-mapping.json`, and `powerbi-visual-changes.json`. Original schemas/counts/hashes are under `baseline/`. Run the normal commands from README; opt-in SQL mutation tests are explicitly marked and should run only against a disposable project test database.

```powershell
python -m unittest discover -s tests -v
python python/reconcile_sources.py
python python/run_sql.py --include-api
sqlcmd -S . -E -C -b -i sql/validation/validate_warehouse.sql
# Test database only: temporary fault injection, restoration and rollback checks
python tests/integration_sql.py --confirm-test-database olist_dw
python tests/check_unknown_date.py --confirm-test-database olist_dw
```

A raw-file financial baseline does not certify an old cached report. Apply and refresh the CommerceLens project before comparing cards with the SQL totals.
