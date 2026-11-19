USE olist_dw;
GO
-- Order grain includes orders with no items/payment/review; no amounts are allocated.
CREATE OR ALTER VIEW dbo.fact_order_summary AS
WITH items AS(SELECT order_id,SUM(price) merchandise_value,SUM(freight_value) freight_value,COUNT(*) item_count FROM dbo.fact_orders GROUP BY order_id),
payments AS(SELECT order_id,SUM(payment_value) payment_value FROM dbo.fact_payments GROUP BY order_id)
SELECT o.order_id,c.customer_key,c.customer_unique_id,c.customer_city,c.customer_state,o.order_status,
 CONVERT(DATE,o.order_purchase_timestamp) purchase_date,
 COALESCE(i.merchandise_value,0) merchandise_value,COALESCE(i.freight_value,0) freight_value,
 COALESCE(i.merchandise_value,0)+COALESCE(i.freight_value,0) gross_order_value,
 COALESCE(i.item_count,0) item_count,p.payment_value,r.review_score,r.review_id,
 r.review_creation_date,r.review_answer_timestamp
FROM dbo.silver_orders o
LEFT JOIN dbo.dim_customers c ON o.customer_id=c.customer_id
LEFT JOIN items i ON i.order_id=CONVERT(VARCHAR(50),o.order_id)
LEFT JOIN payments p ON p.order_id=CONVERT(VARCHAR(50),o.order_id)
OUTER APPLY(SELECT TOP(1) review_score,review_id,review_creation_date,review_answer_timestamp
 FROM dbo.fact_reviews reviews WHERE reviews.order_id=CONVERT(VARCHAR(50),o.order_id)
 ORDER BY review_answer_timestamp DESC,review_creation_date DESC,review_id DESC) r;
GO
