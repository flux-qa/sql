USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateCustomerTallyDeltaTables]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateCustomerTallyDeltaTables]

@fromDate date = '01/01/2020',
@thruDate date = '12/31/2020'

as

delete from CustomerTallyDeltaSummary

;


-- Get Item Tally Totals by Customer ID
with w as (select O.ob_Customers_RID as custno, 
L.ob_Items_RID as itemno, ot.length,
round(sum(OT.length * OT.pieces) / max(I.LFperUM),0) as UMLengthOrdered, 
round(100.0 * sum(OT.length * OT.pieces / I.LFperUM / L.UMShipped),1) as tallyPct,
max(T.suggestedPct) as suggestedPct,
max(T.aboveTallyPct) as costDelta, 
max(case when I.avgCost > 1 then I.avgCost else I.lastCost end) as avgCost, 
round(sum(OT.length * OT.pieces / I.LFperUM * L.actualPrice / L.per),0) as lineTotal,
sum(L.UMShipped) as UMShipped

from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
inner join Orders O on L.ob_Orders_RID = O.ID

inner join OrderTally OT on OT.ob_OrderLines_RID = L.ID

inner join Templates T on T.ob_Items_RID = I.ID and T.length = OT.length
where L.dateShipped between @fromDate and @thruDate
and T.aboveTallyPct > 0

group by O.ob_Customers_RID, L.ob_Items_RID, OT.length)

INSERT INTO [dbo].[CUSTOMERTALLYDELTASUMMARY]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_Customers_REN], [ps_Customers_RID], [ps_Customers_RMA], 
[annualSales], [avgTallyDelta]) 

select row_number() over (order by C.ID), 1, getdate(), 
'Customers', C.ID, null, Y.annualSales, avgTallyDelta

from Customers C inner join (
    select custno,
    round(sum((tallyPct - suggestedPct) * costDelta * UMShipped * avgCost)  /
        sum(costDelta * UMShipped * avgCost),1) as avgTallyDelta
    from w
    group by custno) as Z on C.ID = Z.custno
    inner join (select ob_Customers_RID, sum(L.UMShipped * L.actualPrice / L.per) as annualSales
        from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
        where L.dateShipped between @fromDate and @thruDate and L.ID in 
            (select L.ID from OrderLines L inner join OrderTally OT on OT.ob_OrderLines_RID = L.ID
            inner join Templates T on T.ob_Items_RID = L.ob_Items_RID and T.length = OT.length
            where L.dateShipped between @fromDate and @thruDate and T.aboveTallyPct > 0 group by L.ID )
        group by ob_Customers_RID) as Y on Y.ob_Customers_RID = C.ID
GO
