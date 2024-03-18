USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Import Units and Unit Lengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Import Units and Unit Lengths]  
as

Truncate Table .UNITS

INSERT INTO .UNITS ([ID], [BASVERSION], [BASTIMESTAMP], 
[shortLength], [location], [LFShipped], [pocketWoodFlag], [piecesRolling], 
[pcsPerBundle], [handleArea], [LFStock], [nested], [piecesStock], [LFRolling], 
[high], [longLength], [ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], [undigTo], 
[unit], [evenOddRandom], [shippable], [dateEntered], [OKtoShipWhole], 
[unitType], [wide], [damagedFlag], [actualCost], [dateShipped], [condition], 
[plus], [unitStatus], [oldItemNumber], [piecesShipped], [dateReceived],
POLineNumber,
ps_OrderLines_REN, ps_OrderLines_RID, ps_OrderLines_RMA,
ps_PurchaseOrders_REN, ps_PurchaseOrders_RID, ps_PurchaseOrders_RMA,
ps_PurchaseLines_REN, ps_PurchaseLines_RID, ps_PurchaseLines_RMA,
salesOrder, salesLine
) 

select U.unit, 1, getDate(),
U.shortLength, U.location, U.LFShipped, U.pocketWoodFlag, U.piecesRolling,
U.pcsPerBundle, U.handleArea, U.LFStock, case when U.nested = 'Y' then 1 else 0 end,
 U.piecesStock, U.LFRolling,
U.high, U.longLength, 'Items', BI.ID, 'om_Units', U.unDigTo,
U.unit, U.evenOddRandom, U.shippable, 
case when U.dateEntered > '01/01/2020' then '01/01/2017' else U.dateEntered end ,
 U.OKtoShipWhole,
U.unitType, U.wide, U.damagedFlag, U.actualCost, U.dateShipped, U.condition,
U.plus, U.unitStatus, U.item, U.piecesShipped, U.dateReceived,
POLine,
'OrderLines', U.orderNumber * 100 + U.lineNumber, 'pm_Units',
'PurchaseOrders', PONumber, 'pm_Units',
'PurchaseLines', NULL, 'pm_Units',
orderNumber, lineNumber

    from ALC.dbo.Units U inner join ALC.dbo.Items I on U.item = I.item
inner join ITEMS BI on I.oldCode = BI.oldCode


truncate table .UNITLENGTHS

INSERT INTO [UNITLENGTHS]([ID], [BASVERSION], [BASTIMESTAMP], 
[qtyOnHand], [qtyInTransit], [originalQty], [qtyShipped], 
[ob_Units_REN], [ob_Units_RID], [ob_Units_RMA], [length], [unit]) 

select recID, 1, getDate(),
qtyOnHand, qtyInTransit, originalQty, qtyShipped,
'Units', unit, 'om_UnitLengths', length, unit

from alc.dbo.UnitLengths


update UNITS

set ps_PurchaseLines_RID = Z.LineID
from UNITS U INNER JOIN (select P.ID as PONumber, L.ID as LineID
    from PURCHASELINES L 
    inner join PURCHASEORDERS P on L.ob_PurchaseOrders_RID = P.ID) as Z on U.ps_PurchaseOrders_RID = Z.PONumber
 
update units set ps_OrderLines_RID = null
from units 
where ps_OrderLines_RID = 0    


update UnitLengths set length = I.dim2

from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
where dim1 = 4 and dim2 > 4 and (um = 'PCS' or um = 'FSM')    

update UnitLengths set length = I.dim3

from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
inner join Items I on U.ob_Items_RID = I.ID
where dim3 >= 1  and (um = 'PCS')

update unitLengths set lengthString = '<b>' + RTRIM(cast (length as char(2))) + '''</b>'
GO
