# Technical audit and delivery change register

## Audit baseline

The supplied root is an outer download folder containing the actual project directory. No Git history was supplied. `baseline/manifest.json` records every original file hash/size; `baseline/sources.json` records parsed counts/headers. Editable original source is recoverable from `baseline/original-source.zip`. An exact original PBIX is also retained in `baseline/original-report.pbix`; the in-place original report hash was restored after Desktop saved its current-format representation while opening/exporting. The original source datasets and SSIS package/binaries retain their hashes.

The original PBIX layout was read without altering the archive; Desktop subsequently opened it and exported the separate CommerceLens PBIP. The semantic model's original SQL host, table columns, absent explicit measures, four relationships (including a bidirectional many-to-many mart relationship) and date variations were inspected with Microsoft TOM and its Desktop export. The `Min(...)` projection names were verified to be stale labels rather than conclusive MIN operators. AOV and review-trend aggregation defects were confirmed in actual semantic queries.

Original transformed database outputs could not be sampled: neither olist_oltp nor olist_dw existed on the accessible local SQL Server. Both were initialized for this task. Therefore the source oracle and original SQL/query definitions are the baseline; no historical warehouse counts or report refresh success are invented.

## Component summary

| File or component | Original issue | Change made | Validation status |
|---|---|---|---|
| fact_orders.sql | Item/payment/review row multiplication | Source item grain; independent payments/reviews | Passed: real SQL and exact-cent source checks |
| Silver / dimensions / date | Destructive reruns, silent conversion loss, fixed calendar | Validated transactions; unique business keys; nullable date FK | Passed: SQL and rollback test |
| Python ingestion and APIs | Hardcoded paths, unconditional replace, unsafe partial fetches | Configurable snapshots, explicit refresh, retries and digest validation | Passed: live loads, APIs, tests |
| run_sql.py | New multi-statement runner initially hid deferred SQL errors | Drain raw ODBC result sets and propagate late THROW | Passed: injected bad price rejected; prior warehouse unchanged |
| CommerceLens Power BI project | Many-to-many marts; implicit measures; AOV/review/currency errors | Preserve 31 visuals; 16 measures; one-to-many orders; common calendar; BRL labels | Passed: TMDL parse and contract checks; Desktop refresh/DAX/render not run |
| Original SSIS package | Only rates task exists; fixed server path; nontransactional truncation | Preserve executable; exact parameter/transaction checklist | Passed: dtexec validation only; execution not run |
| Documentation | Empty README placeholder | CommerceLens README, diagrams, dictionary, setup, migration and reports | Reviewed against implemented files |

## Original files: classification and dependencies

All raw CSVs are KEEP and remain under docs. Geolocation retains multiple observations per ZIP. All SSIS source/project/connection definitions are KEEP because only validation, not a complete runtime workflow, was established. Build outputs are OPTIONAL historical artifacts retained in place, excluded from future Git additions. No original source file was deleted.

| Actual file | Classification | Confirmed issue / purpose | Implemented change | Validation status |
|---|---|---|---|---|
| `.gitignore` | IMPROVE | Ignored only .vs | Ignore local secrets, caches, runtime, landing/generated reports and SSIS builds | Reviewed |
| `README.md.txt` | DEPRECATED (retained) | Empty placeholder | Retained for preservation; README.md is the documentation entry point | Passed: original retained |
| `docs/olist_customers_dataset.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `docs/olist_geolocation_dataset.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `docs/olist_orders_dataset.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `docs/olist_order_items_dataset.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `docs/olist_order_payments_dataset.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `docs/olist_order_reviews_dataset.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `docs/olist_products_dataset.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `docs/olist_sellers_dataset.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `docs/product_category_name_translation.csv` | KEEP | Historical raw source | Unchanged; parsed profile and manifest | Passed: hash and count checks |
| `powerbi/Olist_Ecommerce_Analytics.pbix` | KEEP | Original report reference with cached old results | Preserved exact hash; separate Desktop-exported PBIP improved | Passed: original hash; original opened/exported |
| `python/fetch_apis.py` | FIX / IMPROVE | Top-level requests without timeout/retry; partial holiday output; hardcoded directory | Validated atomic snapshots, retries/timeouts, per-feed status and digest; keep single SGS value | Passed: live API fetch and mock failures |
| `python/load_olist.py` | FIX / IMPROVE | Unconditional replace; duplicate assignment; missing files could still report success | Configurable transactional loads, schema/key checks, explicit --refresh, row counts | Passed: OLTP/Bronze loads; duplicate-load refusal |
| `python/prepare_local_files.py` | IMPROVE | Hardcoded paths and missing directory creation | Configurable directories; preserve pipe TXT, NDJSON, XLSX and byte-copy formats | Passed: round-trip tests |
| `python/profile_data.py` | IMPROVE | Hardcoded path and console-only profiling | Reusable JSON profiles with nulls, ranges, categories and keys | Passed: all nine source files |
| `ssis/Olist_ETL/Bronze_Orders.dtsx` | KEEP | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Package validation passed; full execution not run |
| `ssis/Olist_ETL/Olist_ETL.database` | KEEP | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/Olist_ETL.dtproj` | KEEP | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/Olist_ETL.dtproj.user` | KEEP | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/Olist_ETL.slnx` | KEEP | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/Project.params` | KEEP | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/obj/Development/Bronze_Orders.dtsx` | OPTIONAL (retained) | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/obj/Development/BuildLog.xml` | OPTIONAL (retained) | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/obj/Development/Olist_ETL.dtproj` | OPTIONAL (retained) | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/obj/Development/Package.dtsx` | OPTIONAL (retained) | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/obj/Development/Project.params` | OPTIONAL (retained) | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `ssis/Olist_ETL/bin/Development/Olist_ETL.ispac` | OPTIONAL (retained) | SSIS source/connection managers or historical build output | Unchanged; source package inspected; manual implementation checklist | Unchanged hash |
| `sql/datamarts/dm_customer_insights.sql` | FIX | Item-weighted scores and duplicated order/customer rows | Order-grain view with deterministic latest review and separate payment aggregate | Passed: SQL order-grain count/score reconciliation |
| `sql/datamarts/dm_sales_performance.sql` | FIX | Multiplied source facts and repeated payments/reviews | Item-grain compatibility view; payment/review fields intentionally NULL; extra grain/status fields | Passed: SQL cardinality and finance assertions |
| `sql/datamarts/SQLQuery2.sql` | FIX | Ad-hoc API setup dropped landing tables | Guarded initialization retained as legacy entry point | Not run separately; equivalent primary initializer passed |
| `sql/datamarts/SQLQuery21.sql` | KEEP | Read-only diagnostic or existing project artifact | Unchanged | Reviewed / retained |
| `sql/gold/dim_customers.sql` | IMPROVE | Unconditional drop/reinsert changed surrogate keys and allowed business-key duplicates | Type 1 upsert, stable identities, unique business-key index | Passed: SQL build/rerun |
| `sql/gold/dim_date.sql` | FIX / IMPROVE | Fixed calendar range; DATEFIRST-dependent attributes; destructive rebuild | Full source-year coverage, nullable unknown-date FK, stable English Monday calendar | Passed: SQL execution |
| `sql/gold/dim_products.sql` | IMPROVE | Unconditional drop/reinsert changed surrogate keys and allowed business-key duplicates | Type 1 upsert, stable identities, unique business-key index | Passed: SQL build/rerun |
| `sql/gold/dim_sellers.sql` | IMPROVE | Unconditional drop/reinsert changed surrogate keys and allowed business-key duplicates | Type 1 upsert, stable identities, unique business-key index | Passed: SQL build/rerun |
| `sql/gold/fact_orders.sql` | FIX | Direct item × payment × review joins; generated item ID; invalid fallback date | Source item grain, separate facts, FK checks, independent financial reconciliation | Passed: SQL build and source reconciliation |
| `sql/silver/transform_customers_bronze_to_silver.sql` | FIX / IMPROVE | Mapped Bronze cleansing; destructive drop; conversions could silently null invalid inputs | Keep original aliases; validated staging and full-refresh transaction; typed checks and grain indexes | Passed: executed SQL |
| `sql/silver/transform_geolocation_bronze_to_silver.sql` | FIX / IMPROVE | Mapped Bronze cleansing; destructive drop; conversions could silently null invalid inputs | Keep original aliases; validated staging and full-refresh transaction; typed checks and grain indexes | Passed: executed SQL |
| `sql/silver/transform_holidays_bronze_to_silver.sql` | FIX / IMPROVE | JSON array types parsed as scalar | AS JSON array preservation and explicit boolean conversion | Passed: executed SQL |
| `sql/silver/transform_orders_bronze_to_silver.sql` | FIX / IMPROVE | Mapped Bronze cleansing; destructive drop; conversions could silently null invalid inputs | Keep original aliases; validated staging and full-refresh transaction; typed checks and grain indexes | Passed: executed SQL |
| `sql/silver/transform_order_items_bronze_to_silver.sql` | FIX / IMPROVE | Mapped Bronze cleansing; destructive drop; conversions could silently null invalid inputs | Keep original aliases; validated staging and full-refresh transaction; typed checks and grain indexes | Passed: executed SQL |
| `sql/silver/transform_order_payments_bronze_to_silver.sql` | FIX / IMPROVE | Mapped Bronze cleansing; destructive drop; conversions could silently null invalid inputs | Keep original aliases; validated staging and full-refresh transaction; typed checks and grain indexes | Passed: executed SQL |
| `sql/silver/transform_order_reviews_bronze_to_silver.sql` | FIX / IMPROVE | Mapped Bronze cleansing; destructive drop; conversions could silently null invalid inputs | Keep original aliases; validated staging and full-refresh transaction; typed checks and grain indexes | Passed: executed SQL |
| `sql/silver/transform_products_bronze_to_silver.sql` | FIX / IMPROVE | Mapped Bronze cleansing; destructive drop; conversions could silently null invalid inputs | Keep original aliases; validated staging and full-refresh transaction; typed checks and grain indexes | Passed: executed SQL |
| `sql/silver/transform_sellers_bronze_to_silver.sql` | FIX / IMPROVE | Mapped Bronze cleansing; destructive drop; conversions could silently null invalid inputs | Keep original aliases; validated staging and full-refresh transaction; typed checks and grain indexes | Passed: executed SQL |
| `sql/silver/transform_usd_brl_rates_bronze_to_silver.sql` | FIX / IMPROVE | Invented ask field absent from SGS response | rate_value stores valor; legacy bid/ask remain NULL | Passed: executed SQL |

## Added implementation

- `python/config.py`, `sources.py`: shared project-relative configuration and explicit source/Bronze alias contract.
- `python/load_api.py`: digest-matched successful reference snapshots loaded transactionally as whole JSON documents.
- `python/run_sql.py`: explicit script order, cooperative application lock, outer transaction, full ODBC result draining.
- `python/reconcile_sources.py`: independent integer-cent oracle, original join reproduction, review/unique-customer metrics, payment-difference decomposition.
- `sql/bronze/initialize.sql`: initialize missing databases, mapped raw tables and validated JSON landing tables.
- `sql/gold/fact_order_summary.sql`: preaggregate items/payments independently; indexed deterministic latest-review lookup; retain no-item orders.
- `sql/silver/transform_states_regions_bronze_to_silver.sql`: validate and parse 27 state/region records.
- `sql/migrations/001_archive_legacy_fact.sql`: explicit archive-first migration guard; never silently replace a legacy fact.
- `sql/validation/validate_warehouse.sql`: Bronze/Silver counts, facts, source-grain financial comparison, dimensions, references, mart cardinality, KPI outputs.
- `tests/test_pipeline.py`, `test_powerbi_project.py`: raw/landing/API tests and report preservation/contracts. `integration_sql.py` and `check_unknown_date.py` are opt-in project-test-database checks.
- `powerbi/CommerceLens.pbip` and Desktop-generated report/model folders: supported editable project with preserved pages/containers. `CommerceLens.dax`, `measures.json`, `CommerceLens.theme.json`: explicit definitions and optional reusable theme.
- `requirements.txt`, `requirements-tested.txt`, `config/.env.example`, `.gitignore`: reproducible setup and local artifact hygiene.
- `README.md`, architecture/dictionary/quality/pipeline/SSIS/Power BI guides and verification artifacts: implemented workflow and honest limits.

## Compatibility and remaining migration work

The original database and report names remain available. Mart column names are preserved, but old item-level payment/review measures must be migrated: their compatibility columns intentionally return NULL, not misleading allocated/repeated amounts. The customer mart now has one row per order and therefore requires the order side of the report relationship to be unique. Apply the supplied PBIP and refresh before using the new warehouse with the report.

Existing live SSIS external metadata and populated legacy database schemas are not overwritten. Compare the generated Bronze contract with actual deployment metadata and perform a backed-up migration where they differ. Legacy fact archive migration and existing duplicate-dimension remediation require rehearsal against a restored copy of that deployment. There was no legacy local warehouse to test those paths against.
