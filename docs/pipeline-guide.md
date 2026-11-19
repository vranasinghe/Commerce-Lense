# Pipeline execution and recovery

Use the exact command sequence in README. Working directory is the repository root containing `python/`, `sql/` and `powerbi/`, not the outer download folder. Paths in Python resolve relative to the project. Environment variables are exported, not loaded from `.env`.

1. Profile and reconcile untouched CSVs. `docs/baseline/sources.json` is the delivered source contract; alternate datasets require reviewed baseline changes.
2. Prepare legacy files if demonstrating SSIS. Sellers are pipe-delimited UTF-8; reviews are newline-delimited JSON; category reference is XLSX. Payment/geolocation files are byte-preserving copies. The original review flat-file manager is not a JSON parser.
3. Initialize databases with `sqlcmd -b`. Existing objects are retained. Confirm `dbo.bronze_*` schemas match `python/sources.py` before loading an existing installation.
4. Load OLTP if needed, then mapped Bronze. Default populated-target behavior is failure. `--refresh` replaces the entire selected snapshot in one transaction. All files are schema/key validated before a DB connection is opened.
5. Run optional API fetch and API JSON loader. Every feed must have a successful current fetch status; partial holiday-year results are not published. Status JSON records failures, while the previous complete file stays available for inspection.
6. On an old warehouse, back up and explicitly archive the legacy fact. Compare its count/totals with `python/reconcile_sources.py`. The archive remains queryable. If existing dimension business keys are duplicated, the scripts reject them; investigate and resolve references manually rather than choosing an arbitrary survivor.
7. Run `python python/run_sql.py` (or `--include-api`). This orders scripts and rolls back warehouse changes on error. Individual scripts are transactional but do not provide pipeline-wide atomicity if manually executed separately.
8. Review validation output and Power BI measures before refreshing reports. Reconcile again after a second identical run.

Failure recovery: read the last logged script, correct source/schema/conversion issues, then rerun. The Python loader exits nonzero on error and rolls back its batch. Do not use `to_sql(replace)` or rerun the original archived DROP scripts against the upgraded database. The original rate SSIS task uses TRUNCATE followed by BULK read without an explicit transaction; implement the SSIS checklist before using it for reruns.

Rollback: original editable source is in `docs/baseline/original-source.zip`; datasets, PBIX and package binaries are retained in place with hashes in `manifest.json`. The ZIP is not a database backup and excludes large CSV/PBIX/ISPAC assets. Use SQL Server backup/restore for populated database rollback. An explicit legacy-fact archive is not enough to roll back dimension changes or views.

Logging is console-based; retain output with PowerShell `Tee-Object` when needed. Generated profiles/reconciliation live under `data/processed` and are ignored by Git. Verification snapshots under `docs/verification` are intentional evidence artifacts.
