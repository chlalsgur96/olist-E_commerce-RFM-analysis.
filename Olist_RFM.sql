-- RFM base data
SELECT customer_unique_id, 
		MAX(order_purchase_timestamp) AS R,
		COUNT(DISTINCT o.order_id) AS F,
		ROUND(SUM(payment_value),2) AS M
FROM   orders o
LEFT JOIN   order_payments op
ON    o.order_id = op.order_id
LEFT JOIN   customers c
ON     o.customer_id = c.customer_id
WHERE  order_status not in('canceled', 'unavailable') 
AND payment_type is not null
GROUP BY     customer_unique_id
ORDER BY     M ;

-- 가장 최근 구매 시점
SELECT customer_unique_id,
       order_status,
       order_purchase_timestamp,
       order_approved_at,
       order_delivered_carrier_date,
       order_delivered_customer_date,
       order_estimated_delivery_date
FROM orders o
LEFT JOIN customers c 
ON c.customer_id = o.customer_id
WHERE (o.customer_id, order_purchase_timestamp) IN (
    SELECT customer_id, MAX(order_purchase_timestamp)
    FROM orders
    WHERE order_status NOT IN ('canceled', 'unavailable')
    GROUP BY customer_id
)
order by  order_purchase_timestamp desc;

-- 최근 구매 일자를 기준으로 customer_unique_id 별 Recency 산출
  SELECT customer_unique_id, 
			DATEDIFF('2018-09-05',MAX(order_purchase_timestamp)) AS R,
            MAX(order_purchase_timestamp) AS R_sub,
			COUNT(DISTINCT o.order_id) AS F,
			ROUND(SUM(payment_value),2) AS M
	FROM   orders o
	LEFT JOIN   order_payments op
	ON    o.order_id = op.order_id
	LEFT JOIN   customers c
	ON     o.customer_id = c.customer_id
	WHERE  order_status not in('canceled', 'unavailable') 
	AND payment_type is not null
	GROUP BY     customer_unique_id
	ORDER BY     R ;

-- RFM별 사분위수 산출
SELECT customer_unique_id,
	   R , R_sub , F , M,
       ROUND(PERCENT_RANK() OVER(ORDER BY R DESC),2) AS R_rk,
       ROUND(PERCENT_RANK() OVER(ORDER BY F),2) AS F_rk,
       ROUND(PERCENT_RANK() OVER(ORDER BY M),2) AS M_rk
FROM (
	 SELECT customer_unique_id, 
			DATEDIFF('2018-09-05',MAX(order_purchase_timestamp)) AS R,
            MAX(order_purchase_timestamp) AS R_sub,
			COUNT(DISTINCT o.order_id) AS F,
			ROUND(SUM(payment_value),2) AS M
	FROM   orders o
	LEFT JOIN   order_payments op
	ON    o.order_id = op.order_id
	LEFT JOIN   customers c
	ON     o.customer_id = c.customer_id
	WHERE  order_status not in('canceled', 'unavailable') 
	AND payment_type is not null
	GROUP BY     customer_unique_id
    ) T1
	ORDER BY     F
;

 R: 고객 별 최근 구매 활동
SELECT
    c.customer_unique_id,
    MAX(o.order_purchase_timestamp) AS last_purchase_date,
    DATEDIFF('2018-09-03', MAX(o.order_purchase_timestamp)) AS recency,
    RANK() OVER(ORDER BY DATEDIFF('2018-09-03', MAX(o.order_purchase_timestamp))) AS recency_rank
FROM
    customers c
JOIN
    orders o ON c.customer_id = o.customer_id
WHERE
    o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY
    c.customer_unique_id
ORDER BY
    recency_rank;

-- R 분포
SELECT
    recency_rank AS R_group,
    COUNT(*) AS count,
    COUNT(*) / SUM(COUNT(*)) OVER() AS portion
FROM (
    SELECT
        RANK() OVER(ORDER BY DATEDIFF('2018-09-03', MAX(o.order_purchase_timestamp))) AS recency_rank
    FROM
        customers c
    JOIN
        orders o ON c.customer_id = o.customer_id
    WHERE
        o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY
        c.customer_unique_id
) AS R_data
GROUP BY recency_rank
ORDER BY recency_rank;

-- F : 고객 구매 빈도
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS F,
    ROUND(CUME_DIST() OVER(ORDER BY COUNT(DISTINCT o.order_id)), 2) AS F_ratio
FROM
    customers c
JOIN
    orders o ON c.customer_id = o.customer_id
LEFT JOIN
    order_payments op ON o.order_id = op.order_id
WHERE
    o.order_status NOT IN ('canceled', 'unavailable')
    AND op.payment_type IS NOT NULL
GROUP BY
    c.customer_unique_id
ORDER BY
    F_ratio DESC;

--  F 고객 구매 빈도를 그룹화
SELECT
	CASE WHEN F = 1 THEN 'F1'
		 WHEN F = 2 THEN 'F2'
         WHEN F = 3 THEN 'F3'
         ELSE 'F4'
	END AS F_group,
    COUNT(*) AS cus_cnt,
    COUNT(*) / SUM(COUNT(*)) OVER() AS portion
FROM (
	SELECT customer_unique_id,
		COUNT(DISTINCT order_id) AS F
    FROM
		orders o
        JOIN customers c
        ON o.customer_id = c.customer_id
	WHERE o.order_status NOT IN ('canceled','unavailable')
    GROUP BY customer_unique_id
    ) AS t
    GROUP BY F_group;

-- M :고객 별 구매 금액 사분위수
WITH S AS (
    SELECT
        c.customer_unique_id,
        ROUND(SUM(op.payment_value), 2) AS payment_value,
        PERCENT_RANK() OVER (ORDER BY ROUND(SUM(op.payment_value), 2)) AS M_rk
    FROM
        orders o
        LEFT JOIN customers c ON o.customer_id = c.customer_id
        LEFT JOIN order_payments op ON o.order_id = op.order_id
    WHERE
        o.order_status NOT IN ('canceled', 'unavailable')
        AND op.payment_type IS NOT NULL
    GROUP BY
        c.customer_unique_id
)
SELECT 
    MIN(payment_value) AS min,
    MAX(CASE WHEN M_rk <= 0.25 THEN payment_value END) AS q1,
    MAX(CASE WHEN M_rk <= 0.5 THEN payment_value END) AS q2,
    MAX(CASE WHEN M_rk <= 0.75 THEN payment_value END) AS q3,
    MAX(payment_value) AS max
FROM S;


-- RFM SCORE VW
CREATE VIEW RFM_vw AS
WITH RFM_base AS (
    SELECT 
        customer_unique_id,
        MAX(order_purchase_timestamp) AS R,
        TIMESTAMPDIFF(DAY, MAX(order_purchase_timestamp), '2018-09-03') AS R_days,
        COUNT(DISTINCT o.order_id) AS F,
        SUM(payment_value) AS M
    FROM orders o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable') AND payment_value IS NOT NULL
    GROUP BY customer_unique_id
)
SELECT 
    customer_unique_id,
    R,
    R_days,
    F,
    M,
    CASE 
        WHEN R_days < 120 THEN '5'
        WHEN R_days < 240 THEN '4'
        WHEN R_days < 360 THEN '3'
        WHEN R_days < 480 THEN '2'
        ELSE '1'
    END AS R_score,
    CASE 
        WHEN F = 1 THEN '1'
        WHEN F = 2 THEN '2'
        WHEN F = 3 THEN '3'
        WHEN F = 4 THEN '4'
        ELSE '5'
    END AS F_score,
    CASE 
        WHEN M < 65 THEN '1'
        WHEN M < 65 * 2 THEN '2'
        WHEN M < 65 * 3 THEN '3'
        WHEN M < 65 * 4 THEN '4'
        ELSE '5'
    END AS M_score
FROM RFM_base;

