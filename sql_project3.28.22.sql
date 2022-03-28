--E-Commerce Project Solution


--1. Join all the tables and create a new table called combined_table. (market_fact, cust_dimen, orders_dimen, prod_dimen, shipping_dimen)
--1.a) Join all tables

select 
cd.Cust_id, cd.Customer_Name, cd.Province, cd.Region, cd.Customer_Segment, 
mf.Ord_id, mf.Prod_id, mf.Sales, mf.Discount, mf.Order_Quantity, mf.Product_Base_Margin,
od.Order_Date, od.Order_Priority,
pd.Product_Category, pd.Product_Sub_Category,
sd.Ship_id, sd.Ship_Mode, sd.Ship_Date
from market_fact as mf --market_fact is fact table i joined whole table with market_fact
inner join cust_dimen cd on cd.Cust_id = mf.Cust_id
inner join orders_dimen od on od.Ord_id = mf.Ord_id
inner join prod_dimen pd on pd.Prod_id = mf.Prod_id
inner join shipping_dimen sd on sd.Ship_id = mf.Ship_id

--1.b)Create combined table

select *
into combined_table
from
(
select 
cd.Cust_id, cd.Customer_Name, cd.Province, cd.Region, cd.Customer_Segment, 
mf.Ord_id, mf.Prod_id, mf.Sales, mf.Discount, mf.Order_Quantity, mf.Product_Base_Margin,
od.Order_Date, od.Order_Priority,
pd.Product_Category, pd.Product_Sub_Category,
sd.Ship_id, sd.Ship_Mode, sd.Ship_Date
from market_fact as mf --market_fact is fact table i joined whole table with market_fact
inner join cust_dimen cd on cd.Cust_id = mf.Cust_id
inner join orders_dimen od on od.Ord_id = mf.Ord_id
inner join prod_dimen pd on pd.Prod_id = mf.Prod_id
inner join shipping_dimen sd on sd.Ship_id = mf.Ship_id

)A


--2.a) Find the top 3 customers who have the maximum count of orders(orders must be different)
 
 select top 3 Cust_id, Customer_Name, count(distinct Ord_id) amount_of_orders
 from combined_table
 group by Cust_id,Customer_Name
 order by amount_of_orders desc

--3.Create a new column at combined_table as DaysTakenForDelivery 
--that contains the date difference of Order_Date and Ship_Date.


alter table combined_table add delivery_days smallint --creating a new column which is called delivery_days full of just null values

 update combined_table 
 set delivery_days = datediff(day, Order_Date, Ship_Date) --filling delivery_days column with the difference between order and shipping date
 
 
select ord_id, Order_Date, Ship_Date, delivery_days
from combined_table
order by delivery_days desc

--4. Find the customer whose order took the maximum time to get delivered.

select top 1 Cust_id, Customer_Name, max(delivery_days) max_day
from combined_table
group by Cust_id, Customer_Name
order by 3 desc

--5. Count the total number of unique customers in January and how many of them came back every month over the entire year in 2011

 with T1 as (
select distinct Cust_id
from combined_table
where year(Order_Date) = 2011 and
month(Order_Date) = 1
)   -- whole different customers id who ordered in January 2011

select month(A.Order_Date) order_months, count(distinct A.Cust_id) customer_number 
from combined_table A, T1
where T1.Cust_id = A.Cust_id and
year(A.Order_Date) = 2011
group by month(A.Order_Date) --the numbers of different customers who ordered again followong months in 2011 according to months


--6. write a query to return for each user acording to the time elapsed between the first purchasing and the third purchasing, 
 
 select distinct *, datediff(day, first_order_date, Order_Date) day_diff 
 from
 (
	select Cust_id,Ord_id, Order_Date,
	dense_rank() over (partition by Cust_id order by Order_Date, Ord_id) order_number -- it returns order number  of orders
	from combined_table
 )a, 

 (
	select Cust_id,
	min(Order_Date) over (partition by Cust_id) first_order_date --date of first order
	from combined_table
 )b

 where a.Cust_id = b.Cust_id and
 order_number = 3

 --7. Write a query that returns customers who purchased both product 11 and product 14, 
--as well as the ratio of these products to the total number of products purchased by the customers who purchased product 11 and 14


WITH T1 AS 
(
SELECT Cust_id , 
		SUM (CASE WHEN Prod_id = 'Prod_11' Then Order_Quantity else 0 end) CNT_P11,
		SUM(CASE WHEN Prod_id = 'Prod_14' Then Order_Quantity else 0 end) CNT_P14
FROM combined_table
GROUP BY Cust_id
HAVING
		SUM (CASE WHEN Prod_id = 'Prod_11' Then Order_Quantity else 0 end) > 0
		AND
		SUM(CASE WHEN Prod_id = 'Prod_14' Then Order_Quantity else 0 end) > 0
), 
T2 AS
(
SELECT A.Cust_id, SUM (Order_Quantity) TOTAL_PROD
FROM combined_table A, T1 
WHERE A.Cust_id = T1.Cust_id
GROUP BY A.Cust_id
)
SELECT DISTINCT A.Cust_id, CAST ((1.0*CNT_P11 / TOTAL_PROD) AS NUMERIC(3,2)) P11_RATIO, 
CAST((1.0*CNT_P14 / TOTAL_PROD) AS NUMERIC (3,2)) P14_RATIO
FROM combined_table A, T2 , T1 
WHERE A.Cust_id = T2.Cust_id
AND T1.Cust_id = T2.Cust_id

--CUSTOMER SEGMENTATION


--Müþterileri sýnýflandýracaðýz
--Sipariþ sýklýðýna göre
--Kaç ay arayla alýþveriþ yapýldýðýna göre
--Müþterilerin sipariþleri arasýndaki ay farkýna göre / time_gap
--Grouping customers 

create view cust_month as

with t1 as
(
select distinct Cust_id, year(order_date) ord_year, month(order_date) ord_month,--according to year				 for example 08/2022 -> 8
dense_rank() over (order by year(order_date), month(order_date)) date_month--according to total number of months for example 08/2022 -> 44 because it starts counting from 2009		
from combined_table
)
select distinct cust_id, date_month, lag(date_month) over (partition by cust_id order by date_month) prev_date_month --it returns previous order date
from t1 -- rewtruns the date of last 2 orders according to customer id

select *, date_month - prev_date_month diff_month -- returns time gaps(time gaps -> the difference of dates for last 2 days)
from cust_month


--grouping customers according to time gaps

create view TIME_GAP as
select *, date_month - prev_date_month time_gaps
from cust_month

select cust_id, case when avg(time_gaps) > 2 then 'irregular'
					 when avg(time_gaps) between 1 and 2 then 'retained'
					 when avg(time_gaps) is null then 'churn'
					 else	'unknown'
				end cust_segment
from TIME_GAP
group by cust_id






