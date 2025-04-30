USE final_project_ecommerce;



WITH CTE AS(
SELECT Q.Quantity,P. ProductID,P.ProductName,P.Price,Q.OrderID
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
)

-- What is the total revenue generated over the entire period
SELECT CEILING(SUM(Quantity*price)) AS TOTAL_REVENUE
FROM CTE;

-- Revenue Excluding Returned Orders
SELECT  CEILING(SUM(C.Quantity*C.price)) AS TOTAL_REVENUE
FROM orders AS O
LEFT JOIN CTE AS C
ON O.OrderID=C.OrderID
WHERE O.IsReturned="FALSE";

-- Total Revenue per Year / Month
WITH CTE AS(
SELECT Q.Quantity,P. ProductID,P.ProductName,P.Price,Q.OrderID
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
)

SELECT YEAR(O.OrderDate) as YEARLY, CEILING(SUM(C.Quantity*C.price)) AS TOTAL_REVENUE
FROM orders AS O
LEFT JOIN CTE AS C
ON O.OrderID=C.OrderID
GROUP BY YEARLY;


-- Revenue by Product / Category
SELECT ProductName,CEILING(SUM(Quantity*price)) AS REVENUE
FROM CTE
GROUP BY ProductName;




WITH CTE AS(
SELECT Q.Quantity,P. ProductID,P.ProductName,P.Price,Q.OrderID
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
)

 -- AOV per Year / Month
SELECT YEAR(O.OrderDate) as YEARLY, (CEILING(SUM(C.Quantity*C.price))/SUM(Quantity)) AS AOV
FROM orders AS O
LEFT JOIN CTE AS C
ON O.OrderID=C.OrderID
GROUP BY YEARLY;


-- What is the average order value (AOV) across all orders?
SELECT (ceiling(SUM(Quantity*price))/SUM(Quantity)) AS AOV
FROM CTE;

WITH CTE AS(
SELECT Q.Quantity,P. ProductID,P.ProductName,P.Price,Q.OrderID
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
), CTE1 AS(
SELECT C.CustomerID,C.CustomerName,C.RegionID,R.RegionName,R.Country
FROM customers AS C
LEFT JOIN regions AS R
ON C.RegionID= R.RegionID
)

-- Who are the top 10 customers by total revenue spent?
SELECT T1.CustomerName,CEILING(SUM(T.Quantity*T.price)) AS REVENUE_SPENT
FROM CTE1 AS T1
JOIN orders AS O
ON O.CustomerID=T1.CustomerID
JOIN CTE AS T
ON O.OrderID=T.OrderID
GROUP BY T1.CustomerID
ORDER BY REVENUE_SPENT DESC
LIMIT 10;



-- What is the average order size by region
SELECT T.RegionName, (SUM(D.Quantity)/ SUM(O.OrderID)) AS AOS_BY_REGION
FROM CTE1 AS T
LEFT JOIN  orders AS O
ON O.CustomerID=T.CustomerID
LEFT JOIN orderdetails AS D
ON O.OrderID=D.OrderID
GROUP BY T.RegionName;




WITH CO AS(
SELECT C.CustomerID, COUNT(O.OrderID) AS COUNT_OF_ORDERS
FROM customers AS C
JOIN orders AS O
ON C.CustomerID=O.CustomerID
GROUP BY C.CustomerID
),CO1 AS(

SELECT COUNT(CustomerID) AS TOTAL_COUNT FROM CO
WHERE COUNT_OF_ORDERS>1
)

-- What is the repeat customer rate?
SELECT ROUND(((SELECT TOTAL_COUNT FROM CO1)/COUNT(CustomerID))*100,2) AS Customer_Rate
FROM CO;


-- What is the average time between two consecutive orders for the same customer Region-wise?
WITH Customer_region AS(
SELECT C.CustomerID,C.CustomerName,C.RegionID,R.RegionName,R.Country
FROM customers AS C
LEFT JOIN regions AS R
ON C.RegionID= R.RegionID
),
ORDER_GAP AS(
SELECT CustomerID,OrderDATE,
LAG(OrderDATE) OVER(PARTITION BY CustomerID ORDER BY OrderDATE) AS ORDER_PREVIOUS_DATE
FROM orders),

TIME_DIFF AS(SELECT CustomerID, DATEDIFF(OrderDATE,ORDER_PREVIOUS_DATE) AS GAP
FROM ORDER_GAP
WHERE ORDER_PREVIOUS_DATE IS NOT NULL )

SELECT CR.RegionName, AVG(T.GAP) AS TIMEGAP
FROM Customer_region AS CR
JOIN TIME_DIFF AS T
ON CR.CustomerID=T.CustomerID
GROUP BY CR.RegionName;

-- Customer Segment (based on total spend)
WITH  OrederDetails_product AS(
SELECT Q.Quantity,P. ProductID,P.ProductName,P.Price,Q.OrderID
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
),
Customer_order AS(
SELECT C.CustomerID,O.IsReturned,O.OrderID
FROM customers AS C
JOIN orders AS O
ON C.CustomerID=O.CustomerID
), Total_spent_byCustomer AS(
SELECT CEILING(SUM(OP.Quantity*OP.price)) AS TOTAL_REVENUE,CO.CustomerID
FROM Customer_order AS CO
JOIN OrederDetails_product AS OP
ON CO.OrderID=OP.OrderID
WHERE CO.IsReturned ="FALSE"
GROUP BY CO.CustomerID)

SELECT CustomerID,TOTAL_REVENUE,
	(CASE WHEN TOTAL_REVENUE>1500 THEN "PLATINUM"
		WHEN TOTAL_REVENUE BETWEEN 1000 AND 1500 THEN "GOLD"
        WHEN TOTAL_REVENUE BETWEEN 500 AND 999 THEN "SILVER"
        WHEN TOTAL_REVENUE<500 THEN "BRONZE" END) AS Customer_Segment
FROM Total_spent_byCustomer
ORDER BY CustomerID;



-- What is the customer lifetime value (CLV)?
WITH  OrederDetails_product AS(
SELECT Q.Quantity,P. ProductID,P.ProductName,P.Price,Q.OrderID
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
),
Customer_order AS(
SELECT C.CustomerID,O.IsReturned,O.OrderID,O.OrderDate
FROM customers AS C
JOIN orders AS O
ON C.CustomerID=O.CustomerID
),revenue_lifespan AS(
SELECT CO.CustomerID, DATEDIFF(MAX(CO.OrderDate),MIN(CO.OrderDate)) AS LIFESPAN,
SUM(OP.Quantity*OP.price) AS TOTAL_REVENUE
FROM Customer_order AS CO
JOIN OrederDetails_product AS OP
ON CO.OrderID=OP.OrderID
WHERE CO.IsReturned ="FALSE"
GROUP BY CO.CustomerID)

-- CLV = (Total Revenue from Customer) / (Customer Lifespan in days)

SELECT CustomerID,ROUND(TOTAL_REVENUE/NULLIF(LIFESPAN,0),2) AS CLV
FROM revenue_lifespan
ORDER BY CustomerID;

-- What are the top 10 most sold products (by quantity)

SELECT P.ProductName,SUM(Q.Quantity) AS SoldProducts
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
GROUP BY P.ProductName
ORDER BY SoldProducts DESC
LIMIT 10;

-- What are the top 10 most sold products (by revenue)?
SELECT P.ProductName,CEILING(SUM(Q.Quantity*P.Price)) AS SoldProductsRevenue
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
GROUP BY P.ProductName
ORDER BY SoldProductsRevenue DESC
LIMIT 10;

-- Which products have the highest return rate
WITH ORDER_DETAILS AS(
SELECT O.IsReturned,D.Quantity,P.ProductName
FROM orders as O
LEFT JOIN orderdetails AS D
ON O.OrderID=D.OrderID
LEFT JOIN products AS P
ON P.ProductID=D.ProductID
),
TotalSales AS(
SELECT ProductName,SUM(Quantity) AS TotalSold
FROM ORDER_DETAILS
GROUP BY ProductName
), ReturnedSales AS(
SELECT ProductName,SUM(Quantity) AS TotalSold
FROM ORDER_DETAILS
WHERE IsReturned="True"
GROUP BY ProductName
)
SELECT T.ProductName, ROUND((T.TotalSold*100)/(R.TotalSold),2) AS ReturnRate
FROM TotalSales AS T
JOIN ReturnedSales AS R
ON T.ProductName=R.ProductName
ORDER BY ReturnRate DESC
LIMIT 5 ;

-- Return Rate by Category

WITH ORDER_DETAILS AS(
SELECT O.IsReturned,D.Quantity,P.ProductName,P.Category
FROM orders as O
LEFT JOIN orderdetails AS D
ON O.OrderID=D.OrderID
LEFT JOIN products AS P
ON P.ProductID=D.ProductID
),
TotalSales AS(
SELECT ProductName, Category,SUM(Quantity) AS TotalSold
FROM ORDER_DETAILS
GROUP BY ProductName, Category
), ReturnedSales AS(
SELECT ProductName,Category,SUM(Quantity) AS TotalSold
FROM ORDER_DETAILS
WHERE IsReturned="True"
GROUP BY ProductName, Category
)
SELECT T.ProductName, T. Category, ROUND((R.TotalSold*100)/(T.TotalSold),2) AS ReturnRate
FROM TotalSales AS T
JOIN ReturnedSales AS R
ON T.ProductName = R.ProductName AND T.Category = R.Category
ORDER BY ReturnRate DESC
LIMIT 5 ;


-- What is the average price of products per region?
WITH  OrederDetails_product AS(
SELECT Q.Quantity,P. ProductID,P.ProductName,P.Price,Q.OrderID
FROM orderdetails AS Q
LEFT JOIN products AS P
ON Q.ProductID= P.ProductID
),
Customer_order AS(
SELECT C.CustomerID,O.IsReturned,O.OrderID,O.OrderDate,R.RegionName
FROM regions AS R
LEFT JOIN customers AS C
ON C.RegionID= R.RegionID
LEFT JOIN orders AS O
ON C.CustomerID=O.CustomerID
)
SELECT CO.RegionName,ROUND(AVG(OP.Price),2) AS AVG_PRICE_PRODUCT
FROM OrederDetails_product AS OP
LEFT JOIN Customer_order AS CO
ON OP.OrderID=CO.OrderID
GROUP BY CO.RegionName;


-- What is the sales trend for each product category?
WITH CTE AS(
SELECT O.OrderDate,Q.Quantity,P.ProductID,P.ProductName,P.Category,P.Price,Q.OrderID
FROM orders AS O
LEFT JOIN orderdetails AS Q
ON O.OrderID=Q.OrderID
INNER JOIN products AS P
ON Q.ProductID= P.ProductID
)
SELECT Category,
YEAR(OrderDate),MONTH(OrderDate) AS MonthWise,SUM(Quantity*Price) AS TOTAL_SALES
FROM CTE
GROUP BY Category, MONTH(OrderDate),YEAR(OrderDate);

-- What are the monthly sales trends over the past year?
WITH CTE AS(
SELECT O.OrderDate,Q.Quantity,P.ProductID,P.ProductName,P.Category,P.Price,Q.OrderID
FROM orders AS O
LEFT JOIN orderdetails AS Q
ON O.OrderID=Q.OrderID
INNER JOIN products AS P
ON Q.ProductID= P.ProductID
)
SELECT Category,
YEAR(OrderDate),MONTH(OrderDate) AS MonthWise,SUM(Quantity*Price) AS TOTAL_SALES
FROM CTE
WHERE YEAR(OrderDate)=YEAR(CURDATE())-1
GROUP BY Category, MONTH(OrderDate),YEAR(OrderDate);

-- How does the average order value (AOV) change by month or week?
WITH CTE AS(
SELECT O.OrderDate,Q.Quantity,P.ProductID,P.ProductName,P.Category,P.Price,Q.OrderID
FROM orders AS O
LEFT JOIN orderdetails AS Q
ON O.OrderID=Q.OrderID
INNER JOIN products AS P
ON Q.ProductID= P.ProductID
)
SELECT 
MONTHNAME(OrderDate) AS MONTHLY,ROUND((ceiling(SUM(Quantity*price))/SUM(Quantity)),2) AS AOV
FROM CTE
GROUP BY MONTH(OrderDate),MONTHNAME(OrderDate)
ORDER BY MONTH(OrderDate);

-- Which regions have the highest order volume and which have the lowest?
WITH Customer_region AS(
SELECT C.CustomerID,C.CustomerName,C.RegionID,R.RegionName,R.Country,O.OrderID
FROM customers AS C
LEFT JOIN regions AS R
ON C.RegionID= R.RegionID
LEFT JOIN orders AS O
ON C.CustomerID=O.CustomerID
),
MAX_MIN AS(
SELECT RegionName,COUNT(OrderID)  AS OrderVolume
FROM Customer_region 
GROUP BY RegionName)

(SELECT "HIGHEST" AS TYPE,RegionName,OrderVolume 
FROM MAX_MIN
WHERE OrderVolume = (SELECT MAX(OrderVolume) FROM MAX_MIN)
)
UNION
(SELECT "LOWEST" AS TYPE, RegionName,OrderVolume
FROM MAX_MIN
WHERE OrderVolume = (SELECT MIN(OrderVolume) FROM MAX_MIN)
);


-- What is the revenue per region and how does it compare across different regions?
SELECT 
  R.RegionName,
  ROUND(SUM(Q.Quantity * P.Price), 2) AS Total_Revenue
FROM orders O
JOIN orderdetails Q ON O.OrderID = Q.OrderID
JOIN customers C ON O.CustomerID = C.CustomerID
JOIN regions R ON C.RegionID = R.RegionID
JOIN products P ON Q.ProductID = P.ProductID
GROUP BY R.RegionName
ORDER BY Total_Revenue DESC;

-- What is the overall return rate by product category?
WITH ORDER_DETAILS AS(
SELECT O.IsReturned,D.Quantity,P.ProductName,P.Category
FROM orders as O
LEFT JOIN orderdetails AS D
ON O.OrderID=D.OrderID
LEFT JOIN products AS P
ON P.ProductID=D.ProductID
),
TotalSales AS(
SELECT ProductName, Category,SUM(Quantity) AS TotalSold
FROM ORDER_DETAILS
GROUP BY ProductName, Category
), ReturnedSales AS(
SELECT ProductName,Category,SUM(Quantity) AS TotalSold
FROM ORDER_DETAILS
WHERE IsReturned="True"
GROUP BY ProductName, Category
)
SELECT T.ProductName, T. Category, ROUND((R.TotalSold*100)/(T.TotalSold),2) AS ReturnRate
FROM TotalSales AS T
JOIN ReturnedSales AS R
ON T.ProductName = R.ProductName AND T.Category = R.Category
ORDER BY ReturnRate DESC;

-- What is the overall return rate by region?

WITH RETURN_BY_REGION AS (SELECT 
  R.RegionName,O.IsReturned,Q.Quantity,P.ProductName,P.Category
FROM regions R 
JOIN customers C ON R.RegionID = C.RegionID
JOIN orders O ON O.CustomerID = C.CustomerID
JOIN orderdetails Q ON O.OrderID = Q.OrderID
JOIN products P ON Q.ProductID = P.ProductID
),
TotalSales AS(
SELECT RegionName,SUM(Quantity) AS TotalSold
FROM RETURN_BY_REGION
GROUP BY RegionName
), ReturnedSales AS(
SELECT RegionName,SUM(Quantity) AS TotalSold
FROM RETURN_BY_REGION
WHERE IsReturned="True"
GROUP BY RegionName
)
SELECT T.RegionName, ROUND((COALESCE(R.TotalSold, 0) * 100.0)/(T.TotalSold),2) AS ReturnRate
FROM TotalSales AS T
LEFT JOIN ReturnedSales AS R
ON T.RegionName= R.RegionName 
ORDER BY ReturnRate DESC;

-- Which customers are making frequent returns
