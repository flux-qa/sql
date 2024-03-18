USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateCustomerShipmentTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[UpdateCustomerShipmentTotals]
as

declare @noOrders integer;

select @noOrders = count(*) from (select O.ob_Customers_RID from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
    where L.dateShipped > dateAdd(dd, -457, getdate()) and L.per > 0
    group by O.ob_Customers_RID ) as X


update CUSTOMERS set
lastShipment = null,
annualSales = null,
currentSales = null,
currentProfit = null,
lastYearSales = null,
noOrderDays = null,
ranking = null,
tier = null

;

with W as (select O.ob_Customers_RID as custID, max(L.dateShipped) as lastShipment,
    round(sum(case when L.dateShipped > dateAdd(dd, -365, getDate()) 
        then L.UMShipped * L.actualPrice / L.per else 0 end),0) as annualSales,
    round(sum(case when L.dateShipped > dateAdd(dd, -91, getDate()) 
        then L.UMShipped * L.actualPrice / L.per else 0 end),0) as currentSales,
    round(sum(case when L.dateShipped > dateAdd(dd, -91, getDate()) 
        then L.UMShipped * (L.actualPrice - L.projectedCost) / L.per else 0 end),0) as currentProfit,
    round(sum(case when L.dateShipped <= dateAdd(dd, -365, getDate()) and L.dateShipped > dateAdd(dd, -456, getDate()) 
        then L.UMShipped * L.actualPrice / L.per else 0 end),0) as lastYearSales,
    count (distinct O.dateEntered) as noOrderDays,
    max(O.dateEntered) as lastOrderDate 
    
    from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
    where L.dateShipped > dateAdd(dd, -457, getdate()) and L.per > 0
    group by O.ob_Customers_RID)


update CUSTOMERS set
lastShipment = CT.lastShipment,
annualSales = CT.annualSales,
currentSales = CT.currentSales,
currentProfit = CT.currentProfit,
lastYearSales = CT.lastYearSales,
noOrderDays = CT.noOrderDays,
ranking = CT.ranking,
tier = case when CT.ranking is null then null
when CT.ranking * 2 > @noOrders then '4th'
when CT.ranking * 10 <= @noOrders then '1st'
when CT.ranking / 2.0 * 10 <= @noOrders then '2nd'
else '3rd' end

from CUSTOMERS C INNER JOIN (
    select custID, lastShipment, annualSales, currentSales, currentProfit, lastYearSales, noOrderDays, lastOrderDate,
        row_number() over (order by annualSales desc) as ranking from W) as CT on C.ID = CT.custID
GO
