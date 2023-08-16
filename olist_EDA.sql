-- custmors_EDA
-- 고객별 주문횟수, 결제횟수, 총 주문금액, 평균 주문금액
SELECT 
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT( op.payment_sequential) AS payment_count,
    ROUND(SUM(op.payment_value), 2) AS total_payment,
    ROUND(AVG(op.payment_value), 2) AS avg_payment_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN order_payments op ON o.order_id = op.order_id
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_unique_id
ORDER BY order_count DESC
LIMIT 10;

-- orders_EDA
-- order_status가'canceled','unavailable' 인 상태에서 수령한 경우
select c.customer_unique_id,o.order_purchase_timestamp,o.order_delivered_customer_date
from orders o
join customers c on o.customer_id = c.customer_id
where order_status in ('canceled','unavailable')
group by order_purchase_timestamp,order_delivered_customer_date,customer_unique_id
order by order_delivered_customer_date desc
limit 10;

-- 구매 승인이 지난 후 주문 취소
SELECT 
    c.customer_unique_id,
    o.order_approved_at,
    o.order_status,
    COUNT(*) AS canceled_order_count
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'canceled' AND o.order_approved_at is not null
GROUP BY c.customer_unique_id, o.order_approved_at, o.order_status
ORDER BY canceled_order_count DESC;

-- 연도별 / 월별 주문수를 추출(단. order_status 가 canceled , unavailable 인 상태는 제외.)
select date_format(order_purchase_timestamp,'%m') as month,
	count(if(year(order_purchase_timestamp) = '2016' , order_id,null)) as '2016',
    count(if(year(order_purchase_timestamp) = '2017' , order_id,null)) as '2017',
    count(if(year(order_purchase_timestamp) = '2018' , order_id,null)) as '2018'
from orders
where order_status not in('canceled','unavailable')
group by month
order by month;

-- products_EDA
-- 제품 카테고리별 매출액 
SELECT p.product_category_name, 
	round(SUM(payment_value),2)as revenue
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
JOIN order_payments op ON oi.order_id = op.order_id
WHERE order_status not in ('canceled','unavailable')
AND order_delivered_customer_date IS NOT NULL
GROUP BY p.product_category_name
ORDER BY revenue DESC
limit 10;

-- 제품 카테고리별 판매 개수 계산
SELECT product_category_name, sales_count,
       ROUND(sales_count / total_sales * 100, 3) AS sales_ratio
FROM (
    SELECT p.product_category_name, COUNT(*) AS sales_count,
           SUM(COUNT(*)) OVER () AS total_sales 
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status not in ('cancled','unavailable')
    GROUP BY p.product_category_name
) AS category_sales
order by sales_count desc
limit 10;

-- 매출에 따른 카테고리 제품 상위 10 / 하위 10
-- 2016~2018 까지의 상위 10
SELECT t1.product_category_name,
       COUNT(DISTINCT t1.order_id) as Order_cnt,
       ROUND(SUM(t1.payment_value),2) as Revenue
FROM (
    SELECT p.product_category_name, oi.order_id, op.payment_value, o.order_status, o.order_delivered_customer_date
    FROM products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_payments op ON oi.order_id = op.order_id
) t1
WHERE t1.product_category_name IS NOT NULL
      AND t1.order_status not in ('canceled', 'unavailable')
      AND t1.order_delivered_customer_date IS NOT NULL
GROUP BY t1.product_category_name
ORDER BY Revenue DESC
LIMIT 10;

-- 2016~2018 까지의 하위 10
SELECT t1.product_category_name,
       COUNT(DISTINCT t1.order_id) as Order_cnt,
       ROUND(SUM(t1.payment_value),2) as Revenue
FROM (
    SELECT p.product_category_name, oi.order_id, op.payment_value, o.order_status, o.order_delivered_customer_date
    FROM products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_payments op ON oi.order_id = op.order_id
) t1
WHERE t1.product_category_name IS NOT NULL
      AND t1.order_status not in ('canceled', 'unavailable')
      AND t1.order_delivered_customer_date IS NOT NULL
GROUP BY t1.product_category_name
ORDER BY Revenue ASC
LIMIT 10;

-- order_reviews_EDA
-- review_score 기 5인 주문건수와 비율
SELECT yearmonth, r_score, all_cnt,
       ROUND(r_score * 100.0 / all_cnt, 2) AS percentage
 FROM (
     SELECT DATE_FORMAT(order_reviews.review_answer_timestamp, '%Y-%m') AS yearmonth,
            SUM(CASE WHEN order_reviews.review_score = 5 THEN 1 ELSE 0 END) AS r_score,
            COUNT(DISTINCT order_reviews.order_id) AS all_cnt
     FROM order_reviews
     LEFT JOIN orders ON order_reviews.order_id = orders.order_id
     WHERE orders.order_status = 'delivered'
       AND YEAR(order_reviews.review_answer_timestamp) BETWEEN 2016 AND 2018
     GROUP BY yearmonth
 ) AS subquery
 ORDER BY yearmonth DESC
 limit 10;

-- 카테고리 제품 성장률
WITH Category_revenue AS (
    SELECT
        p.product_category_name AS cat_name,
        op.payment_value,
        CASE
            WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y') = '2017' THEN '2017'
            WHEN DATE_FORMAT(o.order_purchase_timestamp, '%Y') = '2018' THEN '2018'
        END AS purchase_fiscal
    FROM order_payments op
    LEFT JOIN orders o ON op.order_id = o.order_id
    LEFT JOIN order_items oi ON op.order_id = oi.order_id
    LEFT JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
        AND (DATE_FORMAT(o.order_purchase_timestamp, '%Y') = '2017'
               OR DATE_FORMAT(o.order_purchase_timestamp, '%Y') = '2018')
    GROUP BY p.product_category_name, op.payment_value, purchase_fiscal
)
SELECT cat_name,
       SUM(CASE WHEN purchase_fiscal = '2017' THEN payment_value END) AS '2017',
       SUM(CASE WHEN purchase_fiscal = '2018' THEN payment_value END) AS '2018',
       ROUND((SUM(CASE WHEN purchase_fiscal = '2018' THEN payment_value END) 
             / SUM(CASE WHEN purchase_fiscal = '2017' THEN payment_value END) - 1) * 100, 2) AS "growth_rate(%)"
FROM Category_revenue
GROUP BY cat_name
ORDER BY
    CASE
        WHEN cat_name = 'product_category_name_for_2017' THEN 1
        WHEN cat_name = 'product_category_name_for_2018' THEN 2
        ELSE 3
        END,
    "growth_rate(%)" desc;
