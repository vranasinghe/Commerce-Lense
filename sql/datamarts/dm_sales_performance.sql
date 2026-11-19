USE olist_dw;
GO
-- Compatibility shape at ITEM grain; legacy payment_value/review_score deliberately NULL.
CREATE OR ALTER VIEW dbo.dm_sales_performance AS
SELECT f.order_id,d.full_date order_date,d.year_number,d.month_name,d.quarter_number,
c.customer_state,c.customer_city,p.product_category_name,s.seller_state,
f.price,f.freight_value,f.price+f.freight_value total_order_value,f.payment_value,f.review_score,
f.order_item_id,d.month_number,o.order_status,s.seller_id
FROM dbo.fact_orders f
LEFT JOIN dbo.dim_date d ON f.order_purchase_date_key=d.date_key
JOIN dbo.dim_customers c ON f.customer_key=c.customer_key
JOIN dbo.dim_products p ON f.product_key=p.product_key
JOIN dbo.dim_sellers s ON f.seller_key=s.seller_key
JOIN dbo.silver_orders o ON f.order_id=o.order_id;
GO
