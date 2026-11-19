# Data-quality policy

Source baseline: all nine CSV headers/counts are recorded in `baseline/sources.json`. Row counts use CSV parsing, not newline counts (reviews contain embedded line breaks). ZIP prefixes and IDs remain strings. `customer_id` and `customer_unique_id` have different grains.

Python checks every required file/schema, key format, business-key uniqueness, original asset hashes, source relationships, exact-cent financial totals, and landing-format round trips. Mock API failures test retention of previous snapshots and rejection of partial holiday feeds. Profiling reports null percentages, duplicate rows/keys, numeric/date ranges, conversion failures, and observed categories without modifying raw data.

Silver checks failed nonempty numeric/date conversions, required grain fields, duplicate business keys, nonnegative item/payment values, review scores 1–5, and coordinate bounds. Empty optional values remain NULL. Business-key indexes protect future writes. Raw rows are not silently dropped or deduplicated. A failed check rejects the snapshot.

Gold checks item grain, resolved references, valid date keys, independent payment/review facts, order-mart cardinality and financial reconciliation. `sql/validation/validate_warehouse.sql` throws on violations and reports separate financial totals and status scope. Python's independent source oracle prevents validating SQL only against another SQL query with the same defect.

Default monetary metrics are BRL and include all source statuses. Merchandise = item price sum; freight = item freight sum; gross = merchandise + freight. Payments are cash settlement records and are never treated as product revenue or split across categories. The observed payment-minus-gross difference is diagnostic, not automatically a defect; investigate orders, vouchers, rounding, missing-item orders, and status differences without changing source amounts.

Satisfaction uses latest review per order, not one vote per item. Reviewed-order denominator excludes missing reviews; satisfied means score 4 or 5. Overall review-event metrics may instead use `fact_reviews`, clearly labeled as event-weighted. No-review is not a score of zero. Repeat customer means `customer_unique_id` with more than one source order; all-status and delivered-only variants must be named distinctly.

Rerun evidence must compare business keys/amounts, not generated fact identity values: full refresh intentionally regenerates item surrogate identities. Never build report relationships on `order_item_key` across refreshes. Use source grain for reconciliation.

Observed payment/gross difference analysis (all statuses): 775 orders have payments but no items, accounting for BRL 162,591.95 of the BRL 165,318.88 difference. One delivered order has items but no payment (BRL -143.46). Other nonzero differences occur where both records exist, mostly among delivered orders. These observations explain the aggregate composition, not the underlying business cause. Source values remain unchanged. Full status/classification counts are in `verification/source-reconciliation.json`.
