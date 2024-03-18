USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[RepSalesAnalysisDetail]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RepSalesAnalysisDetail] 

@fromDate   date = '08/01/2019',
@thruDate   date = '11/01/2019',
@customer   varchar(100) = '%'

as

declare @newThruDate date = dateAdd(dd, 1, @thruDate)

;
with w as (
    select left(C.fieldRep,2) as rep, C.name, C.city, count(*) as noLines,
    sum(case when R.LoginName is not null AND  R.LoginName <> UPPER(left(C.fieldRep,2)) then 1 else 0 end)
        as byOthers,
    round(sum(1.0 * L.UMShipped * L.actualPrice / L.per),0) as totSales,
    round(sum(1.0 * L.UMShipped * (L.materialCost ) / L.per),0) 
        as totCost,
    ROUND(sum(1.0* L.UMShipped / L.per * (L.actualPrice - 
    (L.materialCost + L.handlingCost + 
    L.freightCost + L.financeCost + L.sellingCost))),0) as Profit$,
    round(max(Z.tallyPct),0) as tallyCost, min(totalCredits) as totalCredits 
    
    from Customers C inner join Orders O on O.originalShipTo_RID = C.ID
    inner join OrderLines L on L.ob_Orders_RID = O.ID
    
    left outer join (select ob_Customer_RID, sum(subTotal) as totalCredits
    from Invoices where dateEntered between @fromDate and @newThruDate and subTotal < 0 
    group by ob_Customer_RID) as Y on Y.ob_Customer_RID = C.ID
    
    left outer join RegularUser R on O.keyboarder_RID = R.ID
    
    left outer join (select C.ID, round(sum(case when tallyPct < 0 then 0 else tallyPct end),0) 
        as tallyPct
        from Customers C inner join Orders O on O.originalShipTo_RID = C.ID
        inner join orderLines L on L.ob_Orders_RID = O.ID
        inner join (select L.ID, 
            round(sum(costDeltaPct),0) as tallyPct 
            from OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
            inner join Orders O on L.ob_Orders_RID = O.ID
            where L.dateShipped between @fromDate and @newThruDate
            group by L.ID) as Y on L.ID = Y.ID
        where C.contractorFlag = 0
        group by c.ID) as Z on C.id  = Z.ID
    
    where L.dateShipped between @fromDate and @newThruDate
    and C.contractorFlag = 0 and (@customer = '%' or C.name like @customer)
    group by left(C.fieldRep,2), name, city
 )
 select rep, name, city, noLines, byOthers, totSales, profit$, 
    round(100.0 * (totSales - totCost) / case when totSales = 0 then 1 
        else totSales end,1) as GM, isNull(tallyCost,0) as tallyCost, isNull(totalCredits,0) as totalCredits
 from w order by rep, name, city
GO
