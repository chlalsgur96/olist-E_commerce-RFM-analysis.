-- 고객별 주문횟수, 결제횟수, 총 주문금액, 평균 객단가
SELECT 
    c.customer_unique_id,
    COUNT(distinct o.order_id) AS order_count,
    COUNT(op.payment_value) AS payment_count,
    ROUND(SUM(op.payment_value), 2) AS total_payment,
    ROUND(AVG(op.payment_value),2) AS avg_payment_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments op ON o.order_id = op.order_id
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_unique_id
ORDER BY order_count DESC
limit 10;


-- order_status가'canceled','unavailable' 인 상태에서 수령한 경우
select c.customer_unique_id,o.order_purchase_timestamp,o.order_delivered_customer_date
from orders o
join customers c on o.customer_id = c.customer_id
where order_status in ('canceled','unavailable')
group by order_purchase_timestamp,order_delivered_customer_date,customer_unique_id
order by order_delivered_customer_date desc
limit 10;



