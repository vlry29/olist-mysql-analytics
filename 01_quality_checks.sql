USE olist_analytics;

SELECT 'customers' AS table_name, COUNT(*) AS actual_rows, 99441 AS expected_rows FROM `customers`
UNION ALL
SELECT 'products' AS table_name, COUNT(*) AS actual_rows, 32951 AS expected_rows FROM `products`
UNION ALL
SELECT 'category_translation' AS table_name, COUNT(*) AS actual_rows, 71 AS expected_rows FROM `category_translation`
UNION ALL
SELECT 'orders' AS table_name, COUNT(*) AS actual_rows, 99441 AS expected_rows FROM `orders`
UNION ALL
SELECT 'order_items' AS table_name, COUNT(*) AS actual_rows, 112650 AS expected_rows FROM `order_items`;

-- negative_prices
SELECT COUNT(*) FROM order_items WHERE price<0 OR freight_value<0;

-- orders_without_items
SELECT COUNT(*) FROM orders o WHERE NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id=o.order_id);

-- delivered_without_items
SELECT COUNT(*) FROM orders o WHERE order_status='delivered' AND NOT EXISTS (SELECT 1 FROM order_items i WHERE i.order_id=o.order_id);

-- delivered_without_delivery_date
SELECT COUNT(*) FROM orders WHERE order_status='delivered' AND order_delivered_customer_date IS NULL;

-- delivery_before_purchase
SELECT COUNT(*) FROM orders WHERE order_delivered_customer_date < order_purchase_timestamp;

-- approval_before_purchase
SELECT COUNT(*) FROM orders WHERE order_approved_at < order_purchase_timestamp;

-- carrier_before_purchase
SELECT COUNT(*) FROM orders WHERE order_delivered_carrier_date < order_purchase_timestamp;

-- delivery_before_carrier
SELECT COUNT(*) FROM orders WHERE order_delivered_customer_date < order_delivered_carrier_date;

-- products_with_untranslated_category
SELECT COUNT(*) FROM products p WHERE p.product_category_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM category_translation t WHERE p.product_category_name=t.product_category_name);