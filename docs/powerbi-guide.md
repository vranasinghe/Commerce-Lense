# Power BI implementation and validation

The original `Olist_Ecommerce_Analytics.pbix` remains the recoverable reference. `CommerceLens.pbip`, `CommerceLens.Report/`, and `CommerceLens.SemanticModel/` were exported through Power BI Desktop and then edited using the supported PBIR/TMDL project formats. They preserve all 31 visual containers, their IDs, positions, page names and page order. A successful TMDL parse is not a successful report refresh; consult verification for executed checks.

## Confirmed original model findings

The original report imported `dm_sales_performance`, `dm_customer_insights`, and `dim_date` from SQL Server `DESKTOP-HQLO99O`. There were no explicit measures. The two marts had a bidirectional many-to-many order relationship. Three automatic date tables existed; the standalone `dim_date` did not filter the marts. Monetary display used US dollar formatting.

The projection names `Min(...order_id)` and `Min(...customer_unique_id)` are **not proof of a MIN calculation**. The saved card semantic queries use aggregation function 2 and native labels Count; the references are stale identifiers. The implementation replaces these with explicit distinct-count measures anyway. AOV is a confirmed average of item-level `total_order_value`; the review trend sums item-level review scores. Those are correctness defects.

## Implemented project model

- 16 explicit measures in `CommerceLens.dax` and the customer mart TMDL table. Merchandise and freight come from the item mart; payments and latest reviews come from the order mart.
- Customer mart order ID is the unique side of a one-to-many relationship to sales items. The one bidirectional relationship deliberately lets a product selection restrict reviewed orders/customers to those containing the selected products; it does not allocate order payments. Do not add another bidirectional date path.
- `dim_date.full_date` filters customer `purchase_date`, then item rows through order ID. Monthly trends use the same sorted YearMonth field, rather than disconnected automatic date hierarchies. Existing automatic date tables remain for compatibility.
- Year slicers use the common date dimension; state slicers use the order mart. Month/weekday sorting is numeric.
- Imported monetary item columns use fixed decimal and BRL formatting. Scatter Y uses merchandise instead of repeated payments; X remains freight. Map categories include `, Brazil` to disambiguate state abbreviations.
- All default measures include all source statuses. A delivered-only merchandise measure is explicitly named. AOV includes orders with no items at the unfiltered total. Under product selection, AOV represents selected merchandise divided by orders containing those products; document this context in tooltips.
- Latest review score is order-weighted. Customer satisfaction is scores 4–5 divided by reviewed orders, excluding absent reviews. Repeat customers use `customer_unique_id` with more than one order in the current filter context.
- MoM/YoY return blank without positive prior-period merchandise. Historical coverage is incomplete at dataset boundaries; do not interpret partial-month/year comparisons as full-period growth.

## Desktop steps and acceptance checklist

1. Start SQL Server and run the pipeline/validation first. Open `powerbi/CommerceLens.pbip` in Power BI Desktop supporting project/PBIR/TMDL formats. If already open, choose **Apply external changes**. Do not save the old cached model over edited project files.
2. The new project uses local SQL Server `.` and database `olist_dw`. Change all three SQL M partitions together for a different server. Supply Windows database credentials in Desktop if prompted; no credentials are stored in this repository.
3. Refresh all tables. Check customer mart has exactly 99,441 distinct order IDs and sales mart has 112,650 item records. Reject relationship changes if the order side is not unique.
4. Verify the 16 measures compile and have no errors. With no slicers: orders 99,441; customers 96,096; merchandise R$13,591,643.70; freight R$2,251,909.54; gross R$15,843,553.24; payments R$16,008,872.12; merchandise AOV R$136.680480…; latest-review average 4.086386… . The payment/gross difference of R$165,318.88 is diagnostic, not an automatic accounting error.
5. Review all three pages. Explicit measures replace 20 aggregation projections. Executive cards show merchandise, orders, customers, and order-based AOV. Trends use merchandise, distinct orders, and average rating. Interactive matrix, map and category comparisons remain; scatter uses freight versus merchandise.
6. Exercise year, state, product category and satisfaction slicers together, then clear them. Confirm year filters customer and sales visuals, category filters order KPIs through the unique order relationship, and satisfaction filters associated items. State which selection is active in exported screenshots.
7. Confirm title and labels identify CommerceLens and BRL. The optional `CommerceLens.theme.json` provides a reusable palette; import it if desired, then review contrast on existing visual-level overrides. Existing artwork is retained. All containers keep their original layout; page backgrounds are dark navy and decorative shadows are disabled.
8. Check map behavior and country context; the map may require internet access and may be disabled by tenant policy. Do not change security/privacy settings to bypass that policy.
9. Save a separate `CommerceLens.pbix` through Desktop if a single-file deliverable is needed. Close/reopen it and check all pages before treating it as validated. Preserve the original PBIX.
10. Capture actual screenshots only after refresh and measure reconciliation. Never use cached original report values as proof of the new model.

## Measures

`CommerceLens.dax` is a readable measure reference; the actual project definitions and format strings are in TMDL and `measures.json`. Counts use DISTINCTCOUNT, AOV uses DIVIDE, and satisfaction uses order-grain scores. Do not restore sums of item-mart `payment_value` or `review_score`, whose SQL compatibility fields are now intentionally NULL.

## Design specification

Operate mode: analytical clarity, original 1280×720 report geometry, consistent Segoe UI, navy/slate backgrounds, teal/cyan data accents, restrained gold highlights, no new gradients or animation. Keep tooltip wording explicit about BRL, all-status scope, selected-product merchandise AOV, and latest review per order. Native contrast and actual text fit must be reviewed in Desktop after refresh.

The supported project workflow follows [Microsoft PBIP documentation](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-overview) and [external project editing guidance](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-external-editing). Runtime credentials and cached model state are local `.pbi/` artifacts excluded by `.gitignore`.
