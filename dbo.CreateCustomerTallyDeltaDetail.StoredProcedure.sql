USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateCustomerTallyDeltaDetail]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateCustomerTallyDeltaDetail]

@fromDate date = '01/01/2020',
@thruDate date = '12/31/2020'

as

delete from CustomerTallyDeltaDetail

;

INSERT INTO [dbo].[CustomerTallyDeltaDetail]
([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_Customers_REN], [ps_Customers_RID], [ps_Customers_RMA], 
 [ps_Item_REN], [ps_Item_RID], [ps_Item_RMA],
 length, suggestedPct, shippedPct, deltaPct, costDelta, UMShipped, avgCost) 

select row_number() over (order by C.ID), 1, getDate(),
'Customers', C.ID, null,
'Items', Z.itemNo, null,
Z.length, Z.suggestedPct, 
    round(100.0 * Z.tallyLF / Z.maxQty,1) as shippedPct,
    round(round(100.0 * Z.tallyLF / Z.maxQty,1) - Z.suggestedPct,1) as deltaPct, 
    costDelta, Z.OrderUMShipped, z.avgCost
    from Customers C inner join (select O.ob_Customers_RID as custno,
            I.ID as itemNo,
            OT.length, sum(OT.length * OT.pieces) as TallyLF, sum(L.LFmaxQty) as maxQty,
            max(T.suggestedPct) as suggestedPct, max(T.aboveTallyPct) as costDelta,
            round(sum(OT.length * OT.pieces) / max(I.LFperUM),0) as UMShipped,
            round(sum(L.LFMaxQty / I.LFperUM),0) as orderUMShipped,
            max(case when I.avgcost = 0 then I.lastcost else I.avgCost end) as avgCost
            from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
            inner join Orders O on L.ob_Orders_RID = O.ID
            
            
            inner join OrderTally OT on OT.ob_OrderLines_RID = L.ID
            
            
            inner join Templates T on T.ob_Items_RID = I.ID and T.length = OT.length
            where L.dateShipped between @fromDate and @thruDate 
            and T.aboveTallyPct > 0
            group by O.ob_Customers_RID, I.ID, OT.length) as Z
            on Z.custno = C.ID
            where C.contractorFlag = 0
GO
