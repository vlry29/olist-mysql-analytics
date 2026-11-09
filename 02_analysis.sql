-- Olist | MySQL 8.0+ | Выполняйте запросы по отдельности или весь файл.
USE olist_analytics;

-- Задание 1. Количество заказов. COUNT(*) считает строки.
SELECT COUNT(*) AS orders_count FROM orders;

-- Задание 2. DISTINCT не гарантирует сортировку: нужен ORDER BY.
SELECT DISTINCT order_status FROM orders ORDER BY order_status;

-- Задание 3. Количество заказов по статусам.
SELECT order_status, COUNT(*) AS orders_count FROM orders
GROUP BY order_status ORDER BY orders_count DESC, order_status;

-- Задание 4. Последние 20 доставленных заказов по дате создания.
SELECT order_id, order_status, order_purchase_timestamp FROM orders
WHERE order_status = 'delivered'
ORDER BY order_purchase_timestamp DESC, order_id DESC LIMIT 20;

-- Задание 5. Период данных.
SELECT MIN(order_purchase_timestamp) AS first_purchase,
       MAX(order_purchase_timestamp) AS last_purchase FROM orders;

-- Задание 6. customer_id — запись клиента для заказа;
-- customer_unique_id — идентификатор человека между заказами.
SELECT COUNT(*) AS customer_rows,
       COUNT(DISTINCT customer_id) AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS unique_buyers FROM customers;

-- Задание 7. Товары без категории.
SELECT COUNT(*) AS products_without_category FROM products
WHERE product_category_name IS NULL;

-- Задание 8. Доставленные заказы по месяцу СОЗДАНИЯ, не доставки.
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
       COUNT(*) AS delivered_orders FROM orders
WHERE order_status = 'delivered'
GROUP BY purchase_month ORDER BY purchase_month;

-- Задание 9. Одна строка на заказ с позициями. Доставка отдельно.
SELECT order_id, COUNT(*) AS item_count, SUM(price) AS goods_value,
       SUM(freight_value) AS freight_value FROM order_items
GROUP BY order_id ORDER BY order_id;

-- Задание 10. Товарооборот доставленных заказов. Это НЕ выручка Olist.
-- Предварительная агрегация не позволяет размножить заказы при JOIN.
WITH totals AS (
 SELECT order_id, SUM(price) AS goods_value, SUM(freight_value) AS freight_value
 FROM order_items GROUP BY order_id
)
SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS purchase_month,
       COUNT(*) AS delivered_orders, ROUND(SUM(t.goods_value), 2) AS goods_value,
       ROUND(SUM(t.freight_value), 2) AS freight_value
FROM orders o JOIN totals t ON t.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY purchase_month ORDER BY purchase_month;

-- Задание 11. Средний чек = среднее суммы товаров НА ЗАКАЗ.
-- AVG(price) — средняя стоимость позиции, другая метрика.
WITH totals AS (
 SELECT order_id, SUM(price) AS goods_value FROM order_items GROUP BY order_id
)
SELECT COUNT(*) AS delivered_orders, ROUND(SUM(t.goods_value), 2) AS goods_value,
       ROUND(AVG(t.goods_value), 2) AS avg_order_value
FROM orders o JOIN totals t ON t.order_id = o.order_id
WHERE o.order_status = 'delivered';

-- Задание 12. Топ-10 категорий. LEFT JOIN сохраняет отсутствующие переводы.
SELECT COALESCE(p.product_category_name, '[missing category]') AS category_original,
       COALESCE(ct.product_category_name_english, p.product_category_name,
                '[missing category]') AS category_name,
       ROUND(SUM(i.price), 2) AS goods_value,
       COUNT(DISTINCT i.order_id) AS delivered_orders
FROM order_items i JOIN orders o ON o.order_id = i.order_id
JOIN products p ON p.product_id = i.product_id
LEFT JOIN category_translation ct ON ct.product_category_name = p.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category_original, category_name
ORDER BY goods_value DESC, category_original LIMIT 10;

-- Задание 13. Покупатели доставленных заказов по штатам.
-- Один человек может попасть в несколько штатов: суммы не обязаны совпадать с общим числом.
SELECT c.customer_state, COUNT(DISTINCT c.customer_unique_id) AS buyers
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state ORDER BY buyers DESC, c.customer_state;

-- Задание 14. Покупатели с >= 2 доставленными заказами за весь период.
SELECT c.customer_unique_id, COUNT(*) AS delivered_orders
FROM customers c JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id HAVING COUNT(*) >= 2
ORDER BY delivered_orders DESC, c.customer_unique_id;

-- Задание 15. Доля повторных покупателей среди покупателей доставленных заказов.
WITH per_buyer AS (
 SELECT c.customer_unique_id, COUNT(*) AS orders_count
 FROM customers c JOIN orders o ON o.customer_id = c.customer_id
 WHERE o.order_status = 'delivered' GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS delivered_buyers,
       SUM(CASE WHEN orders_count >= 2 THEN 1 ELSE 0 END) AS repeat_buyers,
       ROUND(100.0 * SUM(CASE WHEN orders_count >= 2 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0), 2) AS repeat_buyer_pct FROM per_buyer;

-- Задание 16. Первые два доставленных заказа каждого человека.
WITH ranked AS (
 SELECT c.customer_unique_id, o.order_id, o.order_purchase_timestamp,
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
         ORDER BY o.order_purchase_timestamp, o.order_id) AS order_number
 FROM customers c JOIN orders o ON o.customer_id = c.customer_id
 WHERE o.order_status = 'delivered'
)
SELECT * FROM ranked WHERE order_number <= 2
ORDER BY customer_unique_id, order_number;

-- Задание 17. Интервал между первым и вторым заказом: только повторные покупатели.
WITH ranked AS (
 SELECT c.customer_unique_id, o.order_purchase_timestamp,
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
         ORDER BY o.order_purchase_timestamp, o.order_id) AS rn
 FROM customers c JOIN orders o ON o.customer_id = c.customer_id
 WHERE o.order_status = 'delivered'
), pairs AS (
 SELECT customer_unique_id,
 MAX(CASE WHEN rn = 1 THEN order_purchase_timestamp END) AS first_purchase,
 MAX(CASE WHEN rn = 2 THEN order_purchase_timestamp END) AS second_purchase
 FROM ranked WHERE rn <= 2 GROUP BY customer_unique_id
)
SELECT customer_unique_id, first_purchase, second_purchase,
       ROUND(TIMESTAMPDIFF(SECOND, first_purchase, second_purchase) / 86400.0, 2) AS days_to_second
FROM pairs WHERE second_purchase IS NOT NULL
ORDER BY days_to_second, customer_unique_id;

-- Задание 18. Месячная повторная покупка по когортам, LONG-формат.
-- Когорта = месяц первого наблюдаемого заказа со статусом delivered.
-- Аналитическая граница 2018-08-01: август и более поздние месяцы исключены.
-- Это заданное окно анализа, а не утверждение о полноте истории каждого клиента.
-- Сетка содержит нули внутри наблюдаемого окна; будущих месяцев в ней нет.
WITH RECURSIVE
params AS (SELECT CAST('2018-08-01' AS DATE) AS cutoff),
months AS (
 SELECT CAST(DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m-01') AS DATE) AS month_start
 FROM orders WHERE order_status = 'delivered'
 UNION ALL
 SELECT DATE_ADD(month_start, INTERVAL 1 MONTH) FROM months CROSS JOIN params
 WHERE DATE_ADD(month_start, INTERVAL 1 MONTH) < cutoff
), purchases AS (
 SELECT c.customer_unique_id,
 CAST(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS DATE) AS purchase_month
 FROM orders o JOIN customers c ON c.customer_id = o.customer_id CROSS JOIN params
 WHERE o.order_status = 'delivered' AND o.order_purchase_timestamp < cutoff
), first_month AS (
 SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
 FROM purchases GROUP BY customer_unique_id
), sizes AS (
 SELECT cohort_month, COUNT(*) AS cohort_size FROM first_month GROUP BY cohort_month
), activity AS (
 SELECT f.cohort_month, p.purchase_month,
 COUNT(DISTINCT p.customer_unique_id) AS active_buyers
 FROM purchases p JOIN first_month f ON f.customer_unique_id = p.customer_unique_id
 GROUP BY f.cohort_month, p.purchase_month
)
SELECT s.cohort_month, m.month_start AS activity_month,
       TIMESTAMPDIFF(MONTH, s.cohort_month, m.month_start) AS month_number,
       s.cohort_size, COALESCE(a.active_buyers, 0) AS active_buyers,
       ROUND(100.0 * COALESCE(a.active_buyers, 0) / s.cohort_size, 2) AS repurchase_pct
FROM sizes s JOIN months m ON m.month_start >= s.cohort_month
LEFT JOIN activity a ON a.cohort_month = s.cohort_month AND a.purchase_month = m.month_start
ORDER BY s.cohort_month, m.month_start;

-- Задание 19. Доля отмен среди ВСЕХ заказов месяца; unavailable не canceled.
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS purchase_month,
       COUNT(*) AS all_orders,
       SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
       ROUND(100.0 * SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END)
             / COUNT(*), 2) AS canceled_pct
FROM orders GROUP BY purchase_month ORDER BY purchase_month;

-- Задание 20. Выводы и ограничения: docs/findings.md.
