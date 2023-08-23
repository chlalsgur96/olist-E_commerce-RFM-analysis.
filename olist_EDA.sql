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
SELECT c.customer_unique_id,o.order_purchase_timestamp,o.order_delivered_customer_date
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
WHERE order_status IN ('canceled','unavailable')
ORDER BY order_delivered_customer_date DESC
LIMIT 10;

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
SELECT p.product_category_name_english,
	round(SUM(payment_value),2)as revenue
FROM products_new p
JOIN order_items oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
JOIN order_payments op ON oi.order_id = op.order_id
WHERE order_status not in ('canceled','unavailable')
AND order_delivered_customer_date IS NOT NULL
GROUP BY p.product_category_name_english
ORDER BY revenue DESC
limit 10;

-- 제품 카테고리별 판매 개수 계산
SELECT product_category_name_english, sales_count,
       ROUND(sales_count / total_sales * 100, 3) AS sales_ratio
FROM (
    SELECT p.product_category_name_english, COUNT(*) AS sales_count,
           SUM(COUNT(*)) OVER () AS total_sales 
    FROM order_items oi
    JOIN products_new p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status not in ('cancled','unavailable')
    GROUP BY p.product_category_name_english
) AS category_sales
order by sales_count desc
limit 10;

-- 판매량에 따른 카테고리 제품 상위 10 / 하위 10
--  상위 10
SELECT t1.product_category_name_english,
       COUNT(DISTINCT t1.order_id) as Order_cnt,
       ROUND(SUM(t1.payment_value),2) as Revenue
FROM (
    SELECT p.product_category_name_english, oi.order_id, op.payment_value, o.order_status, o.order_delivered_customer_date
    FROM products_new p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id
    LEFT JOIN order_payments op ON oi.order_id = op.order_id
) t1
WHERE t1.product_category_name_english IS NOT NULL
      AND t1.order_status not in ('canceled', 'unavailable')
      AND t1.order_delivered_customer_date IS NOT NULL
GROUP BY t1.product_category_name_english
ORDER BY Revenue DESC
LIMIT 10;

--  하위 10
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
ORDER BY Revenue 
LIMIT 10;



-- order_reviews_EDA
-- review_score가 5인 주문건수와 비율
-- 2018년 기준
ELECT 
  YearMonth, 
  SUM(CASE WHEN r.review_score >= 5 THEN 1 ELSE 0 END) AS review_scores5,
  COUNT(DISTINCT r.order_id) AS order_cnt,
  ROUND(SUM(CASE WHEN r.review_score >= 5 THEN 1 ELSE 0 END) / COUNT(DISTINCT r.order_id) * 100, 2) AS percentage
FROM (
  SELECT 
    DATE_FORMAT(r.review_answer_timestamp, '%y-%m') AS YearMonth,
    r.review_score,
    r.order_id
  FROM order_reviews AS r
    INNER JOIN orders o ON r.order_id = o.order_id
  WHERE o.order_status NOT IN ('canceled', 'unavailable')
    AND YEAR(r.review_answer_timestamp) = '2018'
) AS r
GROUP BY YearMonth
ORDER BY 1
LIMIT 12;

-- 카테고리 제품 성장률
 WITH Category_growth AS (
    SELECT
        p.product_category_name AS cat_name,
        op.payment_value,
        o.order_id,
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
    GROUP BY p.product_category_name, op.payment_value, purchase_fiscal, o.order_id
) 
SELECT cat_name,
       COUNT(CASE WHEN purchase_fiscal = '2017' THEN order_id END) AS '2017_cnt',
       COUNT(CASE WHEN purchase_fiscal = '2018' THEN order_id END) AS '2018_cnt',
       COUNT(order_id) AS All_cnt,
       SUM(CASE WHEN purchase_fiscal = '2017' THEN payment_value END) AS '2017_payment',
       SUM(CASE WHEN purchase_fiscal = '2018' THEN payment_value END) AS '2018_payment',
       ROUND((SUM(CASE WHEN purchase_fiscal = '2018' THEN payment_value END) 
             / SUM(CASE WHEN purchase_fiscal = '2017' THEN payment_value END) - 1) * 100, 2) AS "payment_growth_rate(%)",
       ROUND((COUNT(CASE WHEN purchase_fiscal = '2018' THEN order_id END) 
             / COUNT(CASE WHEN purchase_fiscal = '2017' THEN order_id END) - 1) * 100, 2) AS "order_count_growth_rate(%)"
FROM Category_growth
GROUP BY cat_name
ORDER BY 
    All_cnt 
LIMIT 10;
