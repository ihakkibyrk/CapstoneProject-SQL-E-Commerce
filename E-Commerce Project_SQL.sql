
--- E-Commerce Data and Customer Retention Analysis with SQL ---

select *
from cust_dimen;

ALTER TABLE
  cust_dimen
ALTER COLUMN
  Cust_id
    INT NOT NULL;

ALTER TABLE cust_dimen
ADD CONSTRAINT PK_custdimen PRIMARY KEY (Cust_id);



select *
from orders_dimen

ALTER TABLE orders_dimen
ALTER COLUMN Ord_id INT NOT NULL;

ALTER TABLE orders_dimen
ALTER COLUMN Order_date DATE NULL;

ALTER TABLE orders_dimen
DROP COLUMN Order_date2;

ALTER TABLE orders_dimen
ADD CONSTRAINT PK_ordersdimen PRIMARY KEY (Ord_id);


select *
from prod_dimen;


ALTER TABLE prod_dimen
ALTER COLUMN Prod_id INT NOT NULL;

ALTER TABLE prod_dimen
ADD CONSTRAINT PK_proddimen PRIMARY KEY (Prod_id);


SELECT *
FROM shipping_dimen;

ALTER TABLE shipping_dimen
ALTER COLUMN Ship_id INT NOT NULL;


ALTER TABLE shipping_dimen
ALTER COLUMN Ship_Date DATE NULL;

ALTER TABLE shipping_dimen
ALTER COLUMN Order_ID INT NULL;

ALTER TABLE shipping_dimen
ADD CONSTRAINT PK_shippingdimen PRIMARY KEY (Ship_id);


ALTER TABLE shipping_dimen  WITH CHECK ADD FOREIGN KEY([Ord_id])
REFERENCES orders_dimen(Ord_id);


select *
from market_fact
order by Cust_id, Ord_id, Ship_id, Prod_id, Sales;

ALTER TABLE market_fact
ADD CONSTRAINT PK_market PRIMARY KEY (Cust_id, Ord_id, Ship_id, Prod_id, Sales);

ALTER TABLE market_fact  WITH CHECK ADD FOREIGN KEY([Cust_id])
REFERENCES cust_dimen(Cust_id);

ALTER TABLE market_fact  WITH CHECK ADD FOREIGN KEY([Ord_id])
REFERENCES orders_dimen(Ord_id);

ALTER TABLE market_fact  WITH CHECK ADD FOREIGN KEY([Ship_id])
REFERENCES shipping_dimen(Ship_id);

ALTER TABLE market_fact  WITH CHECK ADD FOREIGN KEY([Prod_id])
REFERENCES prod_dimen(Prod_id);


---Using the columns of “market_fact”, “cust_dimen”, “orders_dimen”, “prod_dimen”, “shipping_dimen”, Create a new table, named as “combined_table”.

SELECT A.*,B.Customer_Name, B.Customer_Segment, B.Province, B.Region, C.Order_date, C.Order_Priority,
D.Product_Category, D.Product_Sub_Category, E.Ship_Date, E.Order_ID, E.Ship_Mode
INTO combined_table
FROM market_fact A
FULL OUTER JOIN cust_dimen B
ON A.Cust_id = B.Cust_id
FULL OUTER JOIN orders_dimen C
ON A.Ord_id = C.Ord_id
FULL OUTER JOIN prod_dimen D
ON A.Prod_id = D.Prod_id
FULL OUTER JOIN shipping_dimen E
ON A.Ship_id = E.Ship_id


Select *
from combined_table


---Find the top 3 customers who have the maximum count of orders.


SELECT TOP 3 c.Customer_Name, COUNT(Ord_id) num_orders
FROM market_fact m
INNER JOIN cust_dimen c
ON m.Cust_id = c.Cust_id
GROUP BY c.Customer_Name
ORDER BY num_orders DESC;


---Create a new column at combined_table as DaysTakenForDelivery that contains the date difference of Order_Date and Ship_Date.

ALTER TABLE combined_table
ADD DaysTakenForDelivery INT NULL;


UPDATE combined_table
SET DaysTakenForDelivery = DATEDIFF(DAY, Order_date, Ship_Date)


SELECT Order_date, Ship_Date, DaysTakenForDelivery
FROM combined_table


----Find the customer whose order took the maximum time to get delivered.

SELECT TOP 1  Customer_Name , MAX(DaysTakenForDelivery) max_time_delivery
FROM combined_table
GROUP BY Customer_Name
ORDER BY max_time_delivery DESC


SELECT Customer_Name
FROM combined_table
WHERE DaysTakenForDelivery = (
SELECT MAX(DaysTakenForDelivery)
FROM combined_table);

--- Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

SELECT COUNT(DISTINCT Customer_Name) total_customer_Jan
FROM combined_table
WHERE MONTH(order_date) = 1


SELECT MONTH(Order_date) [Month], Customer_name,  COUNT(Customer_Name) OVER (PARTITION BY Customer_Name, MONTH( Order_date)) total_customer_evrymonth
FROM combined_table
WHERE YEAR(order_date) = 2011 AND Customer_Name IN (
SELECT DISTINCT Customer_Name
FROM combined_table
WHERE MONTH(order_date) = 1 )
ORDER BY [Month]

SELECT COUNT(DISTINCT Customer_name) total_customer_evrymonth
FROM combined_table
WHERE YEAR(order_date) = 2011 AND Customer_Name IN (
SELECT DISTINCT Customer_Name
FROM combined_table
WHERE MONTH(order_date) = 1 )


--- Write a query to return for each user the time elapsed between the first purchasing and the third purchasing, in ascending order by Customer ID.

;WITH tbl AS (
SELECT DISTINCT Cust_id, Ord_id, Order_date first_purchasing
FROM combined_table
)
SELECT Cust_id, Ord_id, first_purchasing, 
	LEAD(first_purchasing, 2) OVER (PARTITION BY Cust_id ORDER BY first_purchasing) third_purchasing, 
	DATEDIFF(DAY, first_purchasing, LEAD(first_purchasing,2) OVER (PARTITION BY Cust_id ORDER BY first_purchasing)) Time_Lapse 
FROM tbl
ORDER BY Cust_id, first_purchasing


---- Write a query that returns customers who purchased both product 11 and product 14, as well as the ratio of these products to the total number of
--- products purchased by the customer.



;WITH tbl AS(	
SELECT Customer_Name, prod_id, 
	LEAD(prod_id) OVER (PARTITION BY Customer_Name ORDER BY Prod_id) prod_id2 
FROM combined_table
WHERE prod_id = 11 OR prod_id = 14), tbl2 AS(
SELECT DISTINCT tbl.Customer_Name, tbl.Prod_id demanded, a.Prod_id total
FROM tbl
	LEFT JOIN combined_table a
	ON tbl.Customer_Name = a.Customer_Name
WHERE prod_id2 IS NOT NULL AND NULLIF(tbl.Prod_id,prod_id2) IS NOT NULL)
SELECT DISTINCT Customer_Name, ROUND(COUNT(DISTINCT demanded) *1.0 / COUNT(DISTINCT total),4) * 100 ratio
FROM tbl2
GROUP BY Customer_Name 



-------CUSTOMER SEGMENTATION-----

---- Create a “view” that keeps visit logs of customers on a monthly basis. 
--- (For each log, three field is kept: Cust_id, Year, Month)



CREATE VIEW visit_log AS
SELECT Cust_id, YEAR(Order_date) [Year], MONTH(Order_date) [Month], COUNT(Ord_id) num_ord
FROM combined_table
GROUP BY Cust_id, YEAR(Order_date) , MONTH(Order_date)


---- Create a “view” that keeps the number of monthly visits by users. 
----(Show separately all months from the beginning business)

SELECT *
FROM visit_log


---- For each visit of customers, create the next month of the visit as a separate column.

SELECT Cust_id, [Month], LEAD([Month]) OVER (Partition by Cust_id, [Year] ORDER BY Cust_id, [Year], [Month]) next_month
FROM visit_log
ORDER BY Cust_id, Year, Month

---- Calculate the monthly time gap between two consecutive visits by each customer.


SELECT Cust_id, [Year], LEAD([Month]) OVER (Partition by Cust_id, [Year] ORDER BY Cust_id, [Year], [Month]) - [Month] Time_gap
FROM visit_log
ORDER BY Cust_id, [Year]


---- Categorise customers using average time gaps. Choose the most fitted labeling model for you.

;WITH tbl AS(
SELECT DISTINCT Cust_id, [Year], 
		LEAD([Month]) OVER (Partition by Cust_id, [Year] ORDER BY Cust_id, [Year], [Month]) - [Month] Time_gap
FROM visit_log

), tbl2 AS(
SELECT DISTINCT Cust_id, AVG(Time_gap) Time_gap_avg

FROM tbl
GROUP BY Cust_id

)
SELECT Cust_id,	CASE
					WHEN Time_gap_avg <= 3 THEN 'Loyal Customer'
					WHEN Time_gap_avg <= 7 THEN 'Regular Customer'
					ELSE 'Churn' 
				END Cust_Category
FROM tbl2
ORDER BY cust_id


----- Month-Wise Retention Rate ----


----Find the number of customers retained month-wise. (You can use time gaps)

CREATE VIEW visit_log2 AS
SELECT DISTINCT Cust_id, [Year], [Month],
		LEAD([Month]) OVER (Partition by Cust_id, [Year] ORDER BY Cust_id, [Year], [Month]) - [Month] Time_gap
FROM visit_log

CREATE VIEW retained AS
SELECT DISTINCT [Year],[Month], COUNT(Cust_id) OVER (PARTITION BY [Year], [Month]) num_retained_cust
FROM visit_log2
WHERE Time_gap IS NOT NULL;



---- Calculate the month-wise retention rate.

CREATE VIEW total_cust AS
SELECT DISTINCT [Year],[Month], COUNT(Cust_id) OVER (PARTITION BY [Year], [Month]) num_total_cust
FROM visit_log2


SELECT *, 1.0 * num_retained_cust / num_total_cust retention_rate
FROM retained,total_cust
WHERE retained.Year = total_cust.Year AND retained.Month = total_cust.Month
ORDER BY retained.Year, retained.Month
