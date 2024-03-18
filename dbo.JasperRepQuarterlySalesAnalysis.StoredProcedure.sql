USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperRepQuarterlySalesAnalysis]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperRepQuarterlySalesAnalysis]
    @fromdate       date = '04/01/2022',
    @thruDate       date = '06/30/2022',
    @rep            varchar(3) = ''
    
as
    
declare
    @lastYearFrom   date,
    @lastyearThru   date,
    @nextQtrFrom    date,
    @nextQtrThru    date
    

set @lastYearFrom   = DateAdd(yy, -1, @fromDate)
set @lastYearThru   = DateAdd(yy, -1, @thruDate)
set @nextQtrFrom    = DateAdd(q, -3, @fromDate)
set @nextQtrThru    = DateAdd(q, -3, @thruDate)

--select @lastYearFrom, @lastYearThru, @nextQtrFrom, @nextQtrThru


select left(C.fieldRep,2) as rep, C.name, RTRIM(C.city) + ' ' + C.state as city,
    ROUND(SUM(case when cast(I.dateShipped as date) between @fromDate and @ThruDate then
    I.subTotal - (I.subTotal * T.discountPct * 0.01) - (I.subTotal * 
        (ISNULL(Z.rebatePct,0) + ISNULL(Y.rebatePct,0) + ISNULL(X.rebatePct,0)) * 0.01) else 0 end),0) as lastQtr,
    
    ROUND(SUM(case when cast(I.dateShipped as date) between @lastYearFrom and @lastYearThru then
    I.subTotal - (I.subTotal * T.discountPct * 0.01) - (I.subTotal * 
        (ISNULL(Z.rebatePct,0) + ISNULL(Y.rebatePct,0) + ISNULL(X.rebatePct,0)) * 0.01) else 0 end),0) as lastYear,
    
    ROUND(SUM(case when cast(I.dateShipped as date) between @nextQtrFrom and @nextQtrThru then
    I.subTotal - (I.subTotal * T.discountPct * 0.01) - (I.subTotal * 
        (ISNULL(Z.rebatePct,0) + ISNULL(Y.rebatePct,0) + ISNULL(X.rebatePct,0)) * 0.01) else 0 end),0) as nextQtr
        

    from Invoices I inner join CustomerRelations R on I.ob_BillTo_RID = R.ID
    inner join Orders O on I.ps_OrderNumber_RID = O.ID
    inner join Customers C on O.originalShipTo_RID = C.ID
    inner join Terms T on I.ps_TermsCode_RID = T.ID
    
    left outer join (select CBL.ps_BillTo_RID as billTo,  R.pctOverLevel2
        as rebatePct from RebateStructure R 
        inner join CustomerBillToRebateLink CBL on CBL.ob_RebateStructure_RID = R.ID) as Z
        on Z.billTo = I.ob_BillTo_RID
        
        left outer join (select CBL.ps_Customers_RID as shipTo, R.pctOverLevel2 
        as rebatePct from RebateStructure R 
        inner join CustomerBillToRebateLink CBL on CBL.ob_RebateStructure_RID = R.ID) as Y
        on Y.shipTo = C.ID    
        
        left outer join (select CIA.customerID as shipTo,  R.pctOverLevel2 
        as rebatePct from RebateStructure R 
        inner join CustomerBillToRebateLink CBL on CBL.ob_RebateStructure_RID = R.ID
        inner join CustomersInAssociations CIA on CIA.associationID = CBL.ps_BillTo_RID) as X
        on X.shipTo = C.ID       
        
        
    where I.dateShipped >= @lastyearFrom AND (@rep = '' OR @rep = LEFT(C.fieldRep,2))
    group by left(C.fieldRep,2), C.name, RTRIM(C.city) + ' ' + C.state
    order by left(C.fieldRep,2), C.name, 3
GO
