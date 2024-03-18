USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateUnitsToCombine]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateUnitsToCombine]

@CADDrillID integer = 1232225
as

delete from UnitsToCombine
;

with w as (
    select I.ID as itemID, U.ID as sourceUnit_RID, I.CADHandle as handlingArea,
    max(U.piecesStock) as maxStock
    from CADTransactions C inner join Units U on C.unitNumber = U.unit
    inner join Items I on U.ob_Items_RID = I.ID
    inner join OrderLines L on C.ps_OrderLines_RID = L.ID
    where C.ps_CADDrills_RID = @CADDrillID
    and U.piecesStock > 0
    group by I.ID, U.ID, I.CADHandle)
    

INSERT INTO dbo.UnitsToCombine(ID, BASVERSION, BASTIMESTAMP,
   item_REN, item_RID, item_RMA,
   sourceUnit_REN, sourceUnit_RID, sourceUnit_RMA,
   targetUnit_REN, targetUnit_RID, targetUnit_RMA, 
   CADDrill_REN, CADDrill_RID, CADDrill_RMA, printed, handlingArea
   ) 


select row_number() over (order by W.sourceUnit_RID) as ID, 
    1 as BASVERSION, getDate() as BASTIMESTAMP,
    'Items', W.itemID, null, 
    'Units', W.sourceUnit_RID, null,
    'Units', Y.targetID, null,
    'CADDrills', @CADDrillID, null, 0, handlingArea
    

from Units UT inner join (
    -- FIND UNIT WITH LARGEST QTY
    select w.itemID, max(sourceUnit_RID) as targetID from W inner join (
        -- FIND LARGEST QTY FOR EACH ITEM
        select itemID, max(maxStock) as maxItemStock from w group by itemID
        ) as Z on W.itemid = Z.itemID and W.maxStock = Z.maxItemStock
    group by w.itemID) as Y on UT.ID = Y.targetID
        
inner join W on Y.itemID = W.ItemID and Y.targetID <> W.sourceUnit_RID
inner join Units US on US.ID = W.sourceUnit_RID
where UT.shortLength <> UT.longLength OR (UT.shortLength = US.shortLength AND UT.longLength = US.longLength)
GO
