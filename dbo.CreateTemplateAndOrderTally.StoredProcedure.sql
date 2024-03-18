USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTemplateAndOrderTally]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateTemplateAndOrderTally]  
as



INSERT INTO [TEMPLATES]([ID], [BASVERSION], [BASTIMESTAMP], 
    [length], [ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], 
    [aboveTallyPct], [pcsPerUM], [pcs], [UMpocketWood], [suggestedPct], [burden], 
    [UMStock], [pctStock], [pctShort], [UMShort], [costDelta], [UMTemplatable],  [noUnits],               
    UMShortWithGrowth)           --

select row_Number() over(order by I.ID, L.Length) , 1, getDate(),
L.length, 'Items', I.ID, 'om_Templates',
0, 0, sum(case when U.pocketWoodFlag = 0 then qtyOnHand else 0 end), 
sum(case when U.pocketWoodFlag = 1 then qtyOnHand else 0 end), 0, 0,
max(I.UMStock), 0, 0, 0, 0, 0, count(distinct U.ID), 0

from UnitLengths L 
inner join Units U on L.ob_units_RID = U.ID
inner join Items I on U.ob_items_RID = I.Item
inner join (select U.ob_Items_RID as item, sum( L.length * L.qtyOnHand) as totLFStock
    from UnitLengths L inner join Units U on L.ob_units_RID = U.ID
    where L.qtyOnHand > 0 and U.pocketWoodFlag <> 1 group by U.ob_Items_RID) as Z on Z.item = I.ID
where  L.qtyOnHand > 0 and totLFStock > 0
and I.ID not in (select ob_Items_RID from Templates)
group by I.ID, L.Length

Update TEMPLATES
    set pctStock = ROUND(length * pcs / I.LFperUM / T.UMStock,3),
    suggestedPct = ROUND(100.0 * length * pcs / I.LFperUM / T.UMStock,0)
from TEMPLATES T inner join Items I on T.ob_items_RID = I.Item


delete from ORDERTALLY

INSERT INTO [dbo].[ORDERTALLY]([ID], [BASVERSION], [BASTIMESTAMP],
 [length], [pieces], [qtyUM], 
 [ob_OrderLines_REN], [ob_OrderLines_RID], [ob_OrderLines_RMA],  [pct]) 

select row_Number() over (order by L.ID ) as recno, 1, getDate(),
T.length, ROUND(T.pctStock * L.UMOrdered * I.LFperUM / T.length + 0.5 ,0) as pcs,
ROUND(T.pctStock * L.UMOrdered   ,0) as qtyUM, 'OrderLines', L.ID, 'om_OrderTally', T.pctStock

from ORDERLINES L inner join ITEMS I on L.ob_Items_RID = I.ID
inner join TEMPLATES T on T.ob_Items_RID = I.ID

where L.UMShipped = 0 and T.length > 0 and I.lFperUM > 0
GO
