USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateOrderTotalsByOrder]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateOrderTotalsByOrder]
@fromdate date = '03/22/2018',
@thruDate date = '03/22/2018',
@dateType varchar(10) = 'Entered'

as 

delete from OrderTotalsByOrder
;


with w as (select O.orderNumber, max(O.dateEntered) as dateEntered, max(left(O.fieldRep,2)) as fieldRep,
max(Upper(left(C.outsideFieldRep,2))) as outsideRep, max(Upper(R.LoginName)) as keyboarder,
sum(round(l.actualPrice,2)) as actualPrice, 
    sum(round(case when C.contractorFlag = 1 then 0 else L.UMOrdered * L.materialCost / L.per end,2)) as projectedCost,
    sum(round(L.UMOrdered * actualPrice / L.per,0)) as lineTotal,
    sum(round(case when C.contractorFlag = 1 then 0 else L.UMOrdered * (actualPrice - L.materialCost) / L.per end,0)) as profitDollars,
    sum(L.BMEsperFT3) as BMEsperFT3, sum(L.BMEsperLB) as BMEsperLB, max(C.name) as shipTo


from Orders O INNER JOIN OrderLines L ON O.ID = L.ob_Orders_RID
INNER JOIN Customers C on O.originalShipTo_RID = C.ID
inner join RegularUser R on O.ps_userID_RID = R.ID
        where (@dateType = 'Entered' AND cast(O.dateEntered as date) between @fromDate and @thruDate)
           OR (@dateType = 'Shipped' AND cast(L.dateShipped as date) between @fromDate and @thruDate)
group by O.orderNumber)


INSERT INTO OrderTotalsByOrder (ID, BASVERSION, BASTIMESTAMP,
orderNumber, dateEntered, fieldRep, outsideRep, keyboarder, 
actualPrice, projectedCost, lineTotal, profitDollars,
profitPct, BMEsperFT3, BMEsperLB, shipTo)

select row_number() over (order by orderNumber) as ID, 1 as BASVERSION, getDate() as BASTIMESTAMP,
orderNumber, dateEntered, fieldRep, isNull(outsideRep,''), keyboarder,
actualPrice, projectedCost, lineTotal,profitDollars,
case when lineTotal > 0 then round(100.0 * (lineTotal - projectedCost) / lineTotal,0) else 0
end as profitPct, BMEsperFT3, BMEsperLB, shipTo
from W
order by orderNumber
GO
