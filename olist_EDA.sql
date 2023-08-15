-- 고객 별 주문횟수 및 주문 금액 
SELECT 
    c.customer_unique_id,
    count(distinct o.order_id) as order_cnt,
    ROUND(SUM(op.payment_value), 2) AS total_payment
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments op ON o.order_id = op.order_id
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_unique_id
ORDER BY order_cnt DESC
limit 5;


-- order_status가'canceled','unavailable' 인 상태에서 수령한 경우
select c.customer_unique_id,o.order_purchase_timestamp,o.order_delivered_customer_date
from orders o
join customers c on o.customer_id = c.customer_id
where order_status in ('canceled','unavailable')
group by order_purchase_timestamp,order_delivered_customer_date,customer_unique_id
order by order_delivered_customer_date desc
limit 10;
