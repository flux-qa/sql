USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ImportALLFromALC]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ImportALLFromALC]     
as


INSERT INTO [dbo].[InventoryDailyTotals]( [inventoryID], [oldCode], [LFStock], [UMStock], [LFOpenPO], [UMOpenPO], [avgCost]) 
select ID, oldCode, LFStock, UMStock, LFOpenPO, UMOpenPO, avgCost from ITEMS

delete from CADDRILLS
delete from CADSOURCELENGTHS
delete from CADSOURCEUNITS
delete from CADTRANSACTIONS

exec ClearCADNotProcessed

exec [Import Items]
exec [Import Names]
exec [Import Vendors]
exec [Import Order Header and Lines]
exec [Import Purchase Order Header and Lines]
exec [Import Units and Unit Lengths]

exec computeItemSourceUnitDifficultyFactor

exec CombinePocketWooditems


update ITEMS
set idxAgressiveness = '5',  
leadTime = 93, daysToOrder = 93, safetyStockInDays = 33
where
oldcode ='1P4C' or oldcode = '1T4V' or oldcode = '1T4D' 


update UNITS
set vendorID = z.VID
from UNITS U inner join (select V.ID as VID, P.ID as PID
from VENDORS V inner join PURCHASEORDERS P
on V.ID = P.ob_Vendors_RID) as Z on Z.PID = U.ps_PurchaseOrders_RID


delete from ORDERUNITS

INSERT INTO [dbo].[ORDERUNITS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ob_OrderLines_REN], [ob_OrderLines_RID], [ob_OrderLines_RMA], 
[dateAdded], [LF], 
[ps_Units_REN], [ps_Units_RID], [ps_Units_RMA], 
[dateWorkPapersProcessed], [ps_CADDrills_REN], [ps_CADDrills_RID], [ps_CADDrills_RMA], 
[sortOrderForDigging]) 

select row_Number() over (order by L.ID), 1, getDate(),
'OrderLines', L.ID, 'ps_OrderUnits',
getDate(), U.LFStock,
'Units', U.ID, 'ps_OrderUnits',
null, 'CADDrills', null, null,0

from ORDERLINES L inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join UNITS U on U.salesOrder = O.ID and U.salesLine = L.lineNumber
where L.UMShipped > 0



--delete from CUSTOMERS where left(name,1)='['
--delete from CUSTOMERS where name like '%**SAME**%'

Update SYSTEMSETTINGS set lastChange =  Convert(varchar(20), getDate())

--exec CreateItemConversionsForTesting
--exec CreateTemplateAndOrderTally
--exec CreateOrderTallyForTesting
exec computeOrderTallyTotalPiecesAndAvailable


-- UNSHIP LAST 7 DAYS WORTH OF ORDERS
/*
update ORDERLINES set UMShipped = 0, LFShipped = 0, dateShipped = null
where ob_Orders_RID in (
select ID
from ORDERS where dateEntered > dateAdd(dd, -7, getDate())
)


update ORDERS 
set dateShipped = null
where dateEntered > dateAdd(dd, -7, getDate())
*/

update ITEMS set idxAgressiveness = new_idx
 from  ITEMS I  inner join newidxforitems N on N.oldCode = I.oldcode
where I.idxAgressiveness <> new_Idx

-- UPDATE THE ITEM DESCRIPTIONS
update ITEMS
    set internalDescription = Z.internalDescription,
    customerDescription = Z.customerDescription,
    idxAgressiveness = Z.idxAgressiveness,
    leadTime = Z.leadTime,
    daysTransit = Z.daysTransit,
    safetyStockInDays = Z.safetyStockInDays,
    daysToOrder = Z.daysToOrder
from

ITEMS I inner join (

select L.OldCode, internalDescription, customerDescription, idxAgressiveness, 
leadTime, daysTransit, safetyStockInDays, daysToOrder 
from ITEMAUDITLOG L inner join (

select OldCode, max(ID) as ID

from ITEMAUDITLOG
group by OldCode) as Z on L.ID = Z.ID) as Z on I.oldCode = Z.oldCode


update Items
    set mktPrice = case
        when listprice1 > 0 and listprice1 >= listPrice2 and listprice1 >= listprice3 then listprice1
        when listprice2 > 0 and listprice2 >= listprice3 then listprice2
        when listprice3 > 0 then listprice3 end
        
    from Items I inner join ALC.dbo.items O on I.oldCode = O.oldCode
    where I.mktPrice > 0

exec FixInventory

exec createPurchaseAdvisory

Update Items set UMAvailable = UMStock - (UMPocketWood + UMUnShipped)

-- Create the POReceiveHistory records
declare @maxDate datetime
 
select @maxDate = max(dateReceived) from POReceiveHistory

insert into POReceiveHistory (PONumber, dateReceived, itemID, length, totPieces, noUnits)

select P.PONumber, L.dateReceived, I.ID, UL.length, sum(UL.qtyOnHand) as totPieces, count(*) as noUnits
from PurchaseOrders P inner join PurchaseLines L on P.ID = L.ob_PurchaseOrders_RID
inner join Items I on I.ID = L.ob_Items_RID
inner join Units U on U.ob_Items_RID = I.ID
inner join UnitLengths UL on U.ID = UL.ob_Units_RID
where  L.dateReceived > @maxDate
group by P.PONumber, L.dateReceived, I.ID, UL.length

exec RecomputeTemplateSuggestedPctBasedOnLast2Years
GO
