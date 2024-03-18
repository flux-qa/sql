USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadProductYearlyTotalsForGraph]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadProductYearlyTotalsForGraph]
@custno integer

as




with w as (
select product, 

     round(sum(case when datediff(dd, L.dateShipped, getDate()) <= 365 then 
         L.UMShipped * L.actualPrice / L.per else 0 end ),0) as currentSales,

     round(sum(case when datediff(dd, L.dateShipped, getDate()) > 365 then 
         L.UMShipped * L.actualPrice / L.per else 0 end ),0) as prevSales

from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
where C.ID = @custno and dateAdd(dd, -730, getDate()) < L.dateShipped
group by product)


select row_number() over (order by product) as ID, 1 as BASVERSION, getDate() as BASTIMESTAMP,
 product, currentSales, prevSales
from W
GO
