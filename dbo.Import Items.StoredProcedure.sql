USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Import Items]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Import Items]  
as


INSERT INTO [dbo].[ITEMS]([ID], [BASVERSION], [BASTIMESTAMP], 
[approxValue], [LFOpenPO], [buyer], [pcsBundle], [UMUnShipped], [UMAvailable], 
[leadTime], [LFDamaged], [daysTransit], [UMPocketWood], [LFperUM], [daysToOrder], 
[daysNegotiation], [overshipPct], [CADWHoleUnitsOnly], [customerDescription], 
[LFPocketWood],  
[UM], [LFPer], daysToSunsetQuote,  [item], [UMStock], 
[LFTemplatable], [safetyStockInDays], [oldCode], [LFperBME], [idxAgressiveness], 
[mktCost], [UMTemplatable], [CADHandle], [LFUnShipped], [internalDescription], 
[UMOpenPO], [dim3], [dim2], [dim1], [CADLargest], [avgCost], 
[CADUnDigTo], [compl2Move], [UMPer], [LFStock], [CADSingleVendor], oldProduct, 
oldPatternCode, whichCostToUse, grossMargin, sourceUnitDifficultyFactor,
targetUnitDifficultyFactor, wholeUnitDifficultyFactor, squareUnit , fragile, 
 WUSell, defaultNoSourcesForQuote) 


    select item, 1, getDate(),
avgCost * 1.20, 0, buyer, pcsBundle, 0, round(qtyStock / LFtoUM,0), 
leadTime, 0, transitDays, 0, LFtoUM, orderDays, 
negotiatingDays, overshipPct, CADWholeUnitsOnly, customerDescription,
0, 
UM, LFPer, 1, item, round(qtyStock / LFtoUM,0),
0, safetyStock, oldCode, LFtoBME, idxAggressiveness,
mktCost, 0, CADHandle, 0, internalDescription,
0, dim3, dim2, dim1, CADLargest, avgCost,
'', compl2Move, UMper, qtyStock, CADSingleVendor, left(OldProductCode,1), left(pattern,1), 'Average',0,
1, 1, 1, 1, 0, 1, 1

from ALC.dbo.items I where I.item not in (select id from Items)

update Items
set dimString = rtrim(cast(dim1 as char(5))) + ' X ' + rtrim(cast(dim2 as char(5))),
originalLFPerUM = LFPerUM

update Items
set dimString = '' where dim1 = 0

update Items set
internalDescription = replace(replace(replace(internalDescription,' ','<>'),'><',''),'<>',' '),
customerDescription = replace(replace(replace(customerDescription,' ','<>'),'><',''),'<>',' ')

update ITEMS set CADWidthPieces = FLOOR(48 / dim2)
where dim2 > 0


-- CREATE THE ITEM CONVERSION
delete from ITEMCONVERSIONS


INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
 [LFperUM], [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select a.ID, 1, getDate(),
    'UMCodes', U.ID, null, 
     I.LFtoUM, 'Items', a.ID, 'om_ItemConversions', '/ M', 1000
    from ALC.dbo.Items I inner join UMCODES U on I.UM = U.UM
    inner join ITEMS A on I.oldCode = A.oldCode

/*
INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
 [LFperUM],  [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select A.ID+7000, 1, getDate(),
    'UMCodes', U.ID, null,  
    I.LFtoUE, 'Items', A.ID, 'om_ItemConversions', '/ M', 1000
    from ALC.dbo.Items I inner join UMCODES U on I.UE = U.UM
    inner join ITEMS A on I.oldCode = A.oldCode
    where I.UM <> I.UE 


INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
 [LFperUM],  [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select A.ID+14000, 1, getDate(),
    'UMCodes', U.ID, null, 
    I.LFtoUP, 'Items', A.ID, 'om_ItemConversions', '/ M', 1000
    from ALC.dbo.Items I inner join UMCODES U on I.UP = U.UM 
    inner join ITEMS A on I.oldCode = A.oldCode
    Where I.UM <> I.UE and I.UM <> I.UP and I.UE <> I.UP



declare @UID integer
select @UID = ID from UMCODES where UM = 'LF'

-- NOW CREATE A LF CONVERSION FOR ALL FBM
INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
 [LFperUM], [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select A.ID+21000, 1, getDate(),
    'UMCodes', @UID, null,
    1, 'Items', A.ID, 'om_ItemConversions', '/ E', 1
    from ALC.dbo.Items I inner join ITEMS A on I.oldCode = A.oldCode

where I.UM = 'FBM'
and A.ID not in (select ob_Items_RID from ITEMCONVERSIONS where ps_UMCode_RID = @UID)
*/

update ITEMS
set CADUnDigTo = S.UNDIG, CADUndigToLong = S.LONG, CADUnDigToShort = S.short,
CADHandle = Handle
from ITEMS I inner join Sheet1 S on S.ITEM = I.oldCode

update Items
set oldPocketWoodCode = P.oldCode
from Items I inner join OldPocketWoodCodes P on I.oldCode = P.newCode

update items set oldPatternCode = '' where oldPatternCode < '0' or oldPatternCode > '4'

update Items set ps_Patterns_RID = P.ID, ps_Patterns_REN = 'Patterns'
from Items I inner join PATTERNS P on cast(Left(oldPatternCode,1) as int) = P.code
where oldPatternCode between '0' and '4'

update Items set UM = 'PCS' where UM in ('BAG', 'BDL', 'BKT', 'BOX', 'CAN', 
'CTN', 'GAL', 'KIT', 'PAK', 'PAL', 'PC', 'PKS', 'QRT')

update items set UM = 'SVC' where UM = 'FEE'
update Items set UM = 'LF' where UM = 'FSC' or UM = 'FLM'
update items set UM = 'LOT' where UM = 'LBS'

update ItemConversions set ps_UMCode_RID = 5 where ps_UMCode_RID in (4, 15, 18, 7, 6, 1, 8, 16, 21, 3, 17, 19)
update ItemConversions set ps_UMCode_RID = 9 where ps_UMCode_RID = 2
update ItemConversions set ps_UMCode_RID = 14 where ps_UMCode_RID = 11 or PS_UMCode_RID = 20
update ItemConversions set ps_UMCode_RID = 12 where ps_UMCode_RID = 23

-- Create the Item Conversion Display String
update itemConversions set displayString = '<b>' + ltrim(rtrim(cast (LFperUM as char(8)))) + '</b> LF / ' + U.UM
from ItemConversions C inner join UMCodes U on C.ps_UMCode_RID = U.ID

-- FIX the Single Length Items and the Shopping Cart Items

update items set shoppingBasket = 1
from items I inner join singleLengthItems S on I.oldCode = S.oldCode
where cart = 1

Update UnitLengths set length = S.NewLength 
from items I inner join singleLengthItems S on I.oldCode = S.oldCode
inner join Units U on I.ID = U.ob_Items_RID
inner join UnitLengths L on L.ob_Units_RID = U.ID
where L.length = 1 and S.newLength > 0

update ItemConversions
set costPerString = 'E', costPer = 1
where ps_UMCode_RID in (1, 4, 5, 6, 7, 8, 9, 12, 16, 17, 18, 19, 21, 22, 23)

update Items set avgCost = O.avgCost 
from Items I inner join ALC.dbo.Items O on I.oldCode = O.oldCode

update Items set avgCost = Y.cost
from Items I inner join (select L.ob_Items_RID, cost
    from PurchaseLines L inner join (select L.ob_Items_RID as item, max(ob_PurchaseOrders_RID) as maxPONumber
        from PurchaseLines L 
        group by L.ob_Items_RID) as Z on L.ob_Items_RID = Z.item and L.ob_PurchaseOrders_RID = Z.maxPONumber
    ) as Y on I.ID = Y.ob_Items_RID
where I.avgCost = 0

update items set overshipPct = 10 where overshipPct = 11

-- RECOMPUTE THE LFPerUM
--
Update Items set LFperUM = 12.0 / (dim1 * dim2)
where UM = 'FBM' and dim1 > 0 and dim2 > 0

update Items set LFperUM = dim3
where UM = 'PCS' and dim3 > 0

update Items set LFperUM = 1
where UM = 'LF' 

Update Items set LFperUM = 0.25, CADWidthPieces = 1
where dim1 = 4 and dim2 > 4
and UM = 'FSM'

Update Items set LFperUM = dim2, CADWidthPieces = 1
where dim1 = 4 and dim2 > 4
and UM = 'PCS'

Update Items set LFperUM = 12.0 / (dim2)
where dim1 <= 1 and dim1 > 0 and dim2 > 0
and UM = 'FSM'


update itemConversions set LFperUM = I.LFperUM
    from ItemConversions C inner join Items I on C.ob_Items_RID = I.ID
    inner join UMCodes U on U.UM = I.UM and U.ID = C.ps_UMCode_RID
    
-- NOW Do the stuff from Josh's ItemSpreadsheet of Doom

Update Items set grossMargin = 22

Update Items set class = N.class
from Items I inner join NewItemSpreadSheet N on I.oldCode = N.code

Update Items set grossMargin = 20
from Items I inner join NewItemSpreadSheet N on I.oldCode = N.code
where species in ('WRC', 'DF', 'PP/LP', 'SP', 'Rad', 'SYP', 'SPF', 'WF', 'Mah')

Update Items set grossMargin = 24
from Items I inner join NewItemSpreadSheet N on I.oldCode = N.code
where species in ('EWP', 'IWP', 'Pin')

Update Items set grossMargin = 16
from Items I inner join NewItemSpreadSheet N on I.oldCode = N.code
where N.item like '%armorcoat%'

Update Items set grossMargin = 16
from Items I inner join NewItemSpreadSheet N on I.oldCode = N.code
where species ='Ipe'

Update Items set grossMargin = 21
from Items I inner join NewItemSpreadSheet N on I.oldCode = N.code
where species ='Paul'

Update Items set grossMargin = 16
from Items I inner join NewItemSpreadSheet N on I.oldCode = N.code
where N.class ='PANEL'

update Items set mktPrice = oldsysunitprice
from Items I inner join NewItemSpreadSheet N on I.oldCode = N.code
inner join (select ob_items_RID, max(dateShipped) as lastShipment 
    from OrderLines group by ob_Items_RID) as Z on I.ID = Z.ob_Items_RID

where lastShipment > '01/01/2017' and oldsysunitprice > 0


update Items set mktPrice = minListPrice 
from Items I inner join (select oldCode, 
    case when listprice1 > 0 and (listprice2 = 0 or listprice1 <= listprice2) and (listprice3 = 0 or listprice1 <= listprice3) then listprice1
    when listprice2 > 0 and (listprice3 = 0 or listprice2 <= listprice3) then listprice2
    else listprice3 end as minListPrice
    from ALC.dbo.Items
    where (left(oldProductCode,1) = '0' or left(oldProductCode,1) = '1' or  left(oldProductCode,1) = 'H' or product = 3 )
    ) as Z on I.oldCode = Z.oldCode
    
where Z.minListPrice > 0    


-- NOW CREATE A LF CONVERSION FOR LF
declare @UID integer
select @UID = ID from UMCODES where UM = 'LF'

INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
 [LFperUM], [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select A.ID+10000, 1, getDate(),
    'UMCodes', @UID, null,
    1, 'Items', A.ID, 'om_ItemConversions', '/ E', 1
    from ALC.dbo.Items I inner join ITEMS A on I.oldCode = A.oldCode
    left outer join (select ob_Items_RID as item, max(length) as longLength
        from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
        group by ob_Items_RID) as Z on A.ID = Z.item

where I.UM = 'FBM' or 
(I.UM = 'FSM' and A.dim1 < 1 and longlength >= 6) or
(I.UM = 'PCS' and A.dim1 < 4 and longlength >= 6)
 
and A.ID not in (select ob_Items_RID from ITEMCONVERSIONS where ps_UMCode_RID = @UID)


-- CREATE A LF CONVERSION FOR PCS

select @UID = ID from UMCODES where UM = 'PCS'

INSERT INTO [dbo].[ITEMCONVERSIONS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ps_UMCode_REN], [ps_UMCode_RID], [ps_UMCode_RMA], 
 [LFperUM], [ob_Items_REN], 
[ob_Items_RID], [ob_Items_RMA], [costPerString], [costPer]) 
select A.ID+20000, 1, getDate(),
    'UMCodes', @UID, null,
    A.dim2, 'Items', A.ID, 'om_ItemConversions', '/ E', 1
    from ALC.dbo.Items I inner join ITEMS A on I.oldCode = A.oldCode


where I.UM = 'FSM' and A.dim1 = 4 and A.dim2 > 4

 
and A.ID not in (select ob_Items_RID from ITEMCONVERSIONS where ps_UMCode_RID = @UID)


update items set idxAgressiveness = '0' 
where buyer = 'SK'
and (left(oldCode,1) = '5' or left(oldcode,1) = 'G')

update items set CADWidthPieces = 18 where dim2 = 3

/*

insert into Items (ID, BASVERSION, BASTIMESTAMP,  UM, serviceItem, internalDescription, customerDescription, oldcode, UMper, UMperString, LFperUM, pcsBundle )
    values(10001, 1, getdate(), 'PCS', 1, 'Freight', 'Freight', 'FRGT', 1, 'E', 1, 1)
    
insert into Items (ID, BASVERSION, BASTIMESTAMP,  UM, serviceItem, internalDescription, customerDescription, oldcode, UMper, UMperString, LFperUM, pcsBundle )
    values(10002, 1, getdate(), 'PCS', 1, 'Handling Charge', 'Handling Charge', 'HDLG', 1, 'E', 1, 1)    

*/
GO
