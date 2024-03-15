----------- Ad-hoc request -------------------

-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT market 
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC'
GROUP BY market;

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? 
-- method 1
WITH product_count_20 AS(
	SELECT COUNT(DISTINCT product_code) AS unique_product_2020
	FROM fact_sales_monthly
	WHERE fiscal_year = '2020'
),
product_count_21 AS(
	SELECT COUNT(DISTINCT product_code) AS unique_product_2021
	FROM fact_sales_monthly
	WHERE fiscal_year = '2021'
)
SELECT 
	unique_product_2020, unique_product_2021,
	ROUND(((unique_product_2021-unique_product_2020)/unique_product_2020)*100, 2) AS percentage_chg
FROM product_count_20
CROSS JOIN product_count_21 ;

-- method-2
WITH unique_product_count as (
	SELECT fiscal_year, COUNT(DISTINCT product_code) AS unique_product
    FROM fact_sales_monthly
    GROUP BY fiscal_year
)
SELECT 
	p1.unique_product AS unique_product_2020,
	p2.unique_product AS unique_product_2021,
	ROUND((p2.unique_product - p1.unique_product)/p1.unique_product*100, 2) AS percentage_chg
FROM unique_product_count p1
CROSS JOIN unique_product_count p2
WHERE p1.fiscal_year = '2020' AND p2.fiscal_year = '2021';

-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 

SELECT segment, COUNT(DISTINCT(product_code)) AS unique_product_count
FROM dim_product
GROUP BY segment
ORDER BY unique_product_count DESC;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 

WITH product_count AS(
	SELECT dp.segment, ms.fiscal_year, COUNT(DISTINCT(ms.product_code)) AS unique_product
    FROM dim_product dp
    JOIN fact_sales_monthly ms ON dp.product_code = ms.product_code
    GROUP BY dp.segment, ms.fiscal_year
)
SELECT 
		pc1.segment, 
		pc1.unique_product AS product_count_2020,
		pc2.unique_product AS product_count_2021,
        (pc2.unique_product - pc1.unique_product) AS difference
FROM product_count pc1
JOIN product_count pc2 
ON pc1.segment = pc2.segment
AND pc1.fiscal_year = '2020'
AND pc2.fiscal_year = '2021'
ORDER BY difference DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs.

SELECT dp.product_code, dp.product, mc.manufacturing_cost
FROM dim_product dp
JOIN fact_manufacturing_cost mc
ON dp.product_code = mc.product_code
WHERE 
	mc.manufacturing_cost = ( SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
	OR mc.manufacturing_cost = ( SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
ORDER BY mc.manufacturing_cost DESC;

-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.

SELECT dis.customer_code, dc.customer, ROUND(AVG(dis.pre_invoice_discount_pct), 4) AS average_discount_percentage
FROM dim_customer dc
JOIN fact_pre_invoice_deductions dis
ON dc.customer_code = dis.customer_code
WHERE dis.fiscal_year = '2021' AND dc.market = 'India'
GROUP BY dis.customer_code, dc.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 

SELECT 
	MONTHNAME(ms.date) AS Month,
	YEAR(ms.date) AS Year,
	ROUND(SUM(gp.gross_price*ms.sold_quantity),2) AS Gross_sales_Amount
FROM fact_gross_price gp
JOIN fact_sales_monthly ms ON gp.product_code = ms.product_code
JOIN dim_customer c on ms.customer_code = c.customer_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY  MONTHNAME(ms.date), YEAR(ms.date)
ORDER BY Year;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? 

SELECT 
	CASE 
		WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
		WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2'
		WHEN MONTH(date) IN (3, 4, 5) THEN 'Q3'
		ELSE 'Q4'
    END AS Quarter,
	SUM(sold_quantity) AS Total_sold_quantity
FROM fact_sales_monthly ms
WHERE fiscal_year = '2020'
GROUP BY Quarter
ORDER BY Quarter;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 

WITH gross_sales AS(
	SELECT 
		dc.channel, 
		ROUND(sum(gp.gross_price * ms.sold_quantity)/1000000,2) AS gross_sales_mln
	FROM dim_customer dc
	JOIN fact_sales_monthly ms ON dc.customer_code = ms.customer_code
	JOIN fact_gross_price gp on ms.product_code = gp.product_code
	AND ms.fiscal_year = gp.fiscal_year
	WHERE ms.fiscal_year = '2021'
	GROUP BY dc.channel
	ORDER BY gross_sales_mln DESC
)
SELECT * , 
	CONCAT(ROUND(gross_sales_mln/(SUM(gross_sales_mln) OVER())*100, 2), '%')  AS Percentage
FROM gross_sales;

-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 

WITH division_total_sold_quantity AS(
	SELECT 
		dp.division, dp.product_code, dp.product, SUM(ms.sold_quantity) AS total_sold_quantity,
		RANK() OVER(PARTITION BY dp.division ORDER BY SUM(ms.sold_quantity) DESC ) AS rn
	FROM dim_product dp
	JOIN fact_sales_monthly ms ON dp.product_code=ms.product_code
	WHERE ms.fiscal_year = '2021'
	GROUP BY dp.division, dp.product_code, dp.product
)
SELECT *
FROM division_total_sold_quantity
WHERE rn <= 3;