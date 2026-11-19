USE olist_dw;
GO
-- Exactly one row per order; latest answered review wins, then creation date, then ID.
CREATE OR ALTER VIEW dbo.dm_customer_insights AS
SELECT order_id,customer_unique_id,customer_city,customer_state,purchase_date,payment_value,review_score,
CASE WHEN review_score=5 THEN 'Very Satisfied' WHEN review_score=4 THEN 'Satisfied'
 WHEN review_score=3 THEN 'Neutral' WHEN review_score<=2 THEN 'Dissatisfied' ELSE 'No Review' END satisfaction_category,
order_status,merchandise_value,freight_value,gross_order_value,item_count,review_id,review_creation_date
FROM dbo.fact_order_summary;
GO
