USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeItemSourceUnitDifficultyFactor]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeItemSourceUnitDifficultyFactor]

as

update items set sourceUnitDifficultyFactor = 1 + 
    cast (noLengths / 3 as integer) * 0.2,
    noLensPerSourceUnit = round(1.0 * totalLengths / noUnits + .4,0)
    from items I inner join (select U.ob_Items_RID as itemID, 
		count(distinct L.length) as noLengths, count(L.length) as totalLengths,
		count(distinct U.ID) as noUnits
        from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
        -- EITHER RECEIVED IN LAST 9 MONTHS OR IT IS INTACT AND HAS QTY ON HAND
        where (dateAdd(dd, -270, getDate()) < U.dateReceived or
         (L.qtyOnHand > 0 and U.unitType = 'I'))  AND U.ps_OrderLines_RID is null
        and (L.originalQty > 0 or L.qtyOnHand > 0)
        group by U.ob_Items_RID) as Z on I.id = Z.itemID


-- IF FRAGILE, THEN ADD 0.2
update items set sourceUnitDifficultyFactor = sourceUnitDifficultyFactor + 0.2 
where fragile = 1

-- IF SINGLE LENGTH ITEM, SET NOLENSPERSOURCEUNIT TO 1
Update Items set noLensPerSourceUnit = 1 where noLensPerSourceUnit = 0 and dim3 > 0

select sourceUnitDifficultyFactor , count(*) from items where UMStock > 0 
group by sourceUnitDifficultyFactor 
order by sourceUnitDifficultyFactor

update items set targetUnitCost = 
case when shoppingBasket = 1 then 2.00
when squareUnit = 1 then S.squareUnitCost
else S.nonSquareUnitCost end 

from Items I inner join SystemSettings S on 1 = 1

--  IF A SHOPPING BASKET ITEM, THEN THE SUDF IS 0.1
update items set sourceUnitDifficultyFactor = 0.1 where shoppingBasket = 1
GO
