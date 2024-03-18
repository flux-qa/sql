USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateOrderTotalsByCustomer]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateOrderTotalsByCustomer]

@fromdate date = '06/05/2019',
@thruDate date = '06/05/2019',
@dateType varchar(10) = 'Entered'


as

delete from OrderTotalsByCustomer
;

with w as (select O.ob_Customers_RID as custno,
    sum(round(l.actualPrice,2)) as actualPrice, sum(round(case when C.contractorFlag = 1 then 0 else L.materialCost end,2)) as projectedCost,
    sum(round(L.UMOrdered * actualPrice / L.per,0)) as lineTotal,
    sum(round(case when C.contractorFlag = 1 then 0 else L.UMOrdered * (actualPrice - L.materialCost) / L.per end,0)) as profitDollars,
    sum(round(case when C.contractorFlag = 1 then 0 else L.UMOrdered * (actualPrice - L.projectedCost) / L.per end,0)) as estProfitDollars,
    count(distinct O.orderNumber) as noOrders, count(*) as noLines, sum(L.numbSource) as estSources,
    
    sum(case when L.wholeUnits = 0 then 0 else W.noWholeUnits end) as noWhole, sum(L.numbTarget) as noTargets, sum(case when L.wholeUnits = 1 then 0 else L.numbSource end) as noSources

        from Orders O INNER JOIN OrderLines L ON O.ID = L.ob_Orders_RID
        INNER JOIN Customers C on O.ob_Customers_RID = C.ID
                     
        left outer join (select ps_OrderLines_RID, count(*) as noWholeUnits from Units group by ps_OrderLines_RID) as W on W.ps_OrderLines_RID = L.ID
        
        where (@dateType = 'Entered' AND cast(O.dateEntered as date) between @fromDate and @thruDate)
           OR (@dateType = 'Shipped' AND cast(L.dateShipped as date) between @fromDate and @thruDate)
        group by O.ob_Customers_RID),

y as (select sum(round(L.UMOrdered * actualPrice / L.per,0)) as salesTotal,
sum(round(case when C.contractorFlag = 1 then 0 else L.UMOrdered * (actualPrice - L.materialCost) / L.per end,0)) as profitTotal,
sum(round(case when C.contractorFlag = 1 then 0 else L.UMOrdered * (actualPrice - L.projectedCost) / L.per end,0)) as estProfitTotal

    from Orders O INNER JOIN OrderLines L ON O.ID = L.ob_Orders_RID
    INNER JOIN Customers C on O.ob_Customers_RID = C.ID    
    where (@dateType = 'Entered' AND cast(O.dateEntered as date) between @fromDate and @thruDate)
       OR (@dateType = 'Shipped' AND cast(L.dateShipped as date) between @fromDate and @thruDate)
),

z as (select C.ID as custno,
    count(distinct T.unitNumber) as noSources, count(distinct T.ps_TargetUnit_RID) as noTargets
    from OrderLines L inner join CADTransactions T on L.ID = T.ps_OrderLines_RID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    where (@dateType = 'Entered' AND cast(O.dateEntered as date) between @fromDate and @thruDate)
       OR (@dateType = 'Shipped' AND cast(L.dateShipped as date) between @fromDate and @thruDate)
    group by C.ID )


insert into OrderTotalsByCustomer (ID, BASVERSION, BASTIMESTAMP,
    ps_Customers_RID, ps_Customers_REN, ps_Customers_RMA, actualPrice, projectedCost, lineTotal, profitDollars,
    profitPct, noOrders, noLines, salesTotal, profitTotal, salesPct, profitPctOfTotal, noSources, noTargets,
    estProfitDollars, estProfitPct, estProfitPctOfTotal)


select row_number() over (order by w.custno) as ID, 1 as BASVERSION, getDate() as BASTIMESTAMP,
w.custno, 'Customers', null, actualPrice, projectedCost, lineTotal, profitDollars,
case when lineTotal = 0 then 0 else round(100.0 * profitDollars / lineTotal,0) end
as profitPct, noOrders, noLines, Y.salesTotal, Y.profitTotal,
case when salesTotal = 0 then 0 else round(100.0 * lineTotal / salesTotal,1) end as salesPct,
case when profitTotal = 0 then 0 else round(100.0 * profitDollars / profitTotal,1) end as profitPctOfTotal,
case when @dateType = 'Entered' then w.noSources else isNull(z.noSources,0) end as noSources, 

case when @dateType = 'Entered' then w.noTargets else isNull(z.noTargets,0) end as noTargets, w.estProfitDollars, 

case when lineTotal = 0 then 0 else round(100.0 * estProfitDollars / lineTotal,0) end as estProfitPct,
case when estProfitTotal = 0 then 0 else round(100.0 * estProfitDollars / estProfitTotal,0) end as estProfitPctOfTotal

from W inner join Y on 1 = 1
left outer join Z on w.custno = Z.custno
GO
