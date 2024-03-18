USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadCustomerMonthlySalesTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadCustomerMonthlySalesTotals]

@custno integer

as

--declare @maxID integer;

--delete from CUSTOMERMONTHLYSALESTOTALS where custno = @custno
--select @maxID = isNull(MAX(ID),0) from CUSTOMERMONTHLYSALESTOTALS;
declare @currentYear integer = Year(getDate())
declare @DayOfYear integer = datePart(dy, getDate())

;

with w as (
select month(L.dateShipped) as monthNumber, CONVERT(varchar(3), L.dateShipped, 100) as monthName,

     round(sum(case when year(L.dateShipped) = @currentYear and datePart(dy, l.dateShipped) <= @DayOfYear
     --dateDiff(dd, L.dateShipped, getDate()) <= 365 
     then 
        L.UMShipped * L.actualPrice / L.per else 0 end),0) as currentSales,
     round(sum(case when dateDiff(dd, L.dateShipped, getDate()) > 365 then 
        L.UMShipped * L.actualPrice / L.per else 0 end),0) as prevSales

from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
where C.ID = @custno and dateAdd(dd, -730, getDate()) < L.dateShipped
group by  month(L.dateShipped), CONVERT(varchar(3), L.dateShipped, 100))

--insert into CUSTOMERMONTHLYSALESTOTALS (id, basversion, bastimestamp,
--custno, monthNumber, monthName, currentSales, prevSales)

select row_number() over (order by monthNumber) as ID, 1 as BASVERSION, getDate() as BASTIMESTAMP,
monthNumber, monthName, currentSales, prevSales
from W
GO
