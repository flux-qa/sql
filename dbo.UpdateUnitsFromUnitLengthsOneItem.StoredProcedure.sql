USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateUnitsFromUnitLengthsOneItem]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateUnitsFromUnitLengthsOneItem]

@ITEM integer = 2156

AS

Update Units
set  PiecesStock = coalesce(pieces,0),
     computedPieces = coalesce(pieces,0) - FLOOR(isNull(nested2,0) / 2 + isNull(nested3,0) / 3 + isNull(nested4,0) / 4 + isNull(nested5,0) / 5 + isNull(nested6,0) / 6),
     LFStock = coalesce(Z.LFStock,0),
     UMStock = round(coalesce(Z.LFStock,0) / I.LFperUM,0),
     piecesRolling = coalesce(transitPieces,0),
	 LFRolling = coalesce(transitLF,0),
	 piecesShipped = coalesce(Z.piecesShipped,0),
     LFShipped = coalesce(Z.LFShipped,0),
     UMShipped = ROUND(coalesce(Z.LFShipped,0) / I.LFperUM,0),
     ShortLength =  isNull(minLen,0),
     LongLength = isNull(maxLen,0),
     EvenOddRandom =
    CASE
     WHEN TotLength = 0 then ''
     WHEN TotLength > 0 and TotLength = EvenLength then 'E'
     WHEN TotLength > 0 and EvenLength = 0 then 'O'
     ELSE 'R'
     END,
    shortLongEorOString = case when minLen is null then '' WHEN
    minlen = maxLen then rtrim(cast(maxLen as char(3))) + ' ' + EvenOddRandom 
        else rtrim(cast(minLen as char(3))) + '-' + rtrim(cast(maxLen as char(3))) + ' ' + EvenOddRandom end
    
from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join (select ob_Units_RID as unitID, 
    sum(qtyOnHand) as Pieces, sum(length * qtyOnHand) as LFStock,
    sum(qtyInTransit) as transitPieces, sum(isnull(LFinTransit,0)) as transitLF,
    sum(qtyShipped) as piecesShipped, sum(length * qtyShipped) as LFShipped,
    min(length) as minLen, max(length) as maxLen, count(*) as totLength, 
    sum(case when Length  = floor(Length / 2) * 2 then 1 else 0 end) as evenLength
    from unitLengths WHERE qtyOnHand > 0  
    group by ob_Units_RID) as Z on U.ID = Z.unitID
    where U.ob_Items_RID = @ITEM 
 
 
-- RECOMPUTE UMDESIGNED IN ORDERLINES
/*
update OrderLines set UMDesigned = totUM
from OrderLines L inner join 
    (select ps_OrderLines_RID, sum(UMStock) as totUM from Units group by ps_OrderLines_RID) as Z
        on L.ID = Z.ps_OrderLines_RID
where L.UMdesigned <> totUM   
*/  
    -- Ditto for Item Master
    update Items set LFStock = 0, UMStock = 0, UMAvailable = 0, UMDirectPO = 0, UMUnShipped = 0
    where ID = @Item
    
    UPDATE  Items SET LFStock = isnull(LFUnits,0), UMStock = UMUnits, UMAvailable = UMUnits,
        avgCost = case when LFStockDivisor = 0 then avgCost else ROUND((totalCost / LFStockDivisor),2) end
    FROM Items I inner join (SELECT ob_Items_RID AS Item, SUM(LFStock) as LFUnits, SUM(UMStock) as UMUnits, 
    sum(LFStock * ActualCost) as totalCost, sum(LFStock) as LFStockDivisor 
    FROM Units where ob_Items_RID = @Item AND UMStock > 0 and lostFlag = 0 and missingFlag <> 1 
    GROUP BY ob_Items_RID)  as U ON U.Item = I.ID
    WHERE ID = @Item
    

    Update Items set UMAvailable = UMStock - (isNull(totalUnShipped,0) + ROUND(ISNULL(totalPocketWood,0) ,0)),
    UMUnShipped = isNull(TotalUnShipped,0),
    UMPocketWood = ROUND(isNull(totalPocketWood,0) ,0),
    approxValue = CASE
        when mktprice > 0 then mktPrice
        when cellarPrice > Round(avgCost / (1.0 - grossMargin * 0.01),0) then cellarPrice
        else Round( avgCost / (1- grossMargin * 0.01),0)
        end
    from Items I left outer join (select ob_items_RID, 
        sum(UMOrdered) as totalUnShipped from OrderLines
        where UMShipped = 0 and dateShipped is null and WRD = 'W'  
        group by ob_Items_RID) as Z on I.ID = Z.ob_Items_RID
    left outer join (SELECT ob_Items_RID AS Item, SUM(UMStock) as totalPocketWood FROM Units
    where ob_Items_RID = @Item AND pocketWoodFlag = 1 and lostFlag = 0 and missingFlag <> 1 GROUP BY ob_Items_RID) as U on U.item = I.ID
    WHERE ID = @Item
 
    update items set UMAvailable = 0 where id = @Item AND UMAvailable < 0  
    
    Update Items set UMAvailableString = case when UMAvailable = 0 then '' else
    format (UMAvailable, '###,##0') end + ' ' + UM from Items WHERE id = @Item
GO
