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
        MAX(order_purchase_timestamp) AS R_date,
        TIMESTAMPDIFF(DAY, MAX(order_purchase_timestamp), '2018-09-03') AS R,
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
    F,
    M,
    CASE 
        WHEN R < 120 THEN '4'
        WHEN R < 240 THEN '3'
        WHEN R < 360 THEN '2'
        ELSE '1'
    END AS R_score,
    CASE 
        WHEN F = 1 THEN '1'
        WHEN F = 2 THEN '2'
        WHEN F = 3 THEN '3'
        ELSE '4'
    END AS F_score,
    CASE 
        WHEN M < 65 THEN '1'
        WHEN M < 65 * 2 THEN '2'
        WHEN M < 65 * 3 THEN '3'
        ELSE '4'
    END AS M_score
FROM RFM_base;

-- RFM 지표별 매출 기여 효과
-- R_score
SELECT R_score , COUNT(*) R_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS R_raion,
            ROUND(SUM(M),2) AS R_revenue,
			ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY R_score
ORDER BY R_score;

SELECT SUM(contributing_effect) AS R_contributing_effect
FROM(
SELECT R_score , COUNT(*) R_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS R_raion,
            ROUND(SUM(M),2) AS R_revenue,
			ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY R_score
ORDER BY 1) as r1;

-- F_score
SELECT F_score, count(*) CNT, 
		count(*) / sum(count(*)) over() AS user_ratio,
		ROUND(sum(m), 2) AS revenue,
		ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
        ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
group by F_score;

SELECT SUM(contributing_effect) AS F_contributing_effect
FROM(
SELECT F_score , COUNT(*) F_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS F_raion,
            ROUND(SUM(M),2) AS R_revenue,
            ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY F_score
) F1;

-- M_score
SELECT M_score, count(*) CNT, 
		count(*) / sum(count(*)) over() AS user_ratio,
		ROUND(sum(m), 2) AS revenue,
		ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
        ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY M_score
ORDER BY M_score;

SELECT SUM(contributing_effect) AS M_contributing_effect
FROM(
SELECT M_score, count(*) CNT, 
		count(*) / sum(count(*)) over() AS user_ratio,
		ROUND(sum(m), 2) AS revenue,
		ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
        ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY M_score
ORDER BY M_score
) M1;

-- RFM 모형 탐색
-- 가중치 (1,1,1)
SELECT (R_score + F_score + M_score) AS total_score,
       R_score, F_score, M_score,
       COUNT(*) AS cnt,
       COUNT(*) / (SELECT COUNT(*) FROM rfm_vw) AS ratio
FROM rfm_vw
GROUP BY total_score, R_score, F_score, M_score
ORDER BY total_score DESC, R_score DESC, F_score DESC, M_score DESC;


-- 매출 기여 효과 비중을 가중치로 산정
WITH S AS (
SELECT
	(SELECT SUM(R_contributing_effect) FROM r_vw) AS total_R_contribution,
	(SELECT SUM(F_contributing_effect) FROM f_vw) AS total_F_contribution,
	(SELECT SUM(M_contributing_effect) FROM m_vw) AS total_M_contribution)
SELECT ROUND(total_R_contribution / (total_R_contribution + total_F_contribution + total_M_contribution), 2) AS R_weight,
			 ROUND(total_F_contribution / (total_R_contribution + total_F_contribution + total_M_contribution), 2) AS F_weight,
			 ROUND(total_M_contribution / (total_R_contribution + total_F_contribution + total_M_contribution), 2) AS M_weight
FROM S;

-- total_score
select *,
     round(r_score*0.22 + f_score*0.55 + m_score*0.23, 2) as total_score
from rfm_vw;

-- rfm 고객 등급 분류
--  매출기여 비율로 등급 구간 분류
select distinct total_rnk , max(total_score) over(partition by total_rnk) as total_score
from (
select *, 
		round(r_score*0.22 + f_score*0.55 + m_score*0.23, 2) as total_score,
        round(percent_rank() over(order by round(r_score*0.22 + f_score*0.55 + m_score*0.23, 2)), 2) as total_rnk
from rfm_vw) s;

SELECT
    CASE 
        WHEN total_score <= 1.67 THEN 'WHITE'
        WHEN total_score <= 1.9 THEN 'BLUE'
        WHEN total_score <= 2.13 THEN 'RED'
        ELSE 'BLACK'
    END AS grade,
    COUNT(*) AS count,
    COUNT(*) / SUM(COUNT(*)) OVER() AS portion,
    ROUND(AVG(total_score), 2) AS avg_score
FROM (
    SELECT
        *,
        ROUND(r_score * 0.22 + f_score * 0.55 + m_score * 0.23, 2) AS total_score
    FROM rfm_vw
) AS s
GROUP BY grade
ORDER BY 2;

