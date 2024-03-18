USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateUnitsFromUnitLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateUnitsFromUnitLengths]  

-- last change 12/11/22
    
@ITEM integer = 0

as

set nocount on


-- ANY SALES ORDER THAT IS ATTACHED TO RECEIVED VPO CHANGE TO W
/*
update OrderLines set wrd = 'W'
from OrderLines L inner join PurchaseLines P on L.ps_PurchaseLines_RID = P.ID
where P.dateReceived is not null and L.wrd = 'R'
*/

update units set UMStock = 0, LFStock = 0, piecesStock = 0
where id in (select ob_units_RID from unitLengths group by ob_units_RID
 having sum(qtyOnHand) = 0)
and UMStock > 0 

update orderLines set SRO = 'S' where dateShipped is null and wrd = 'W' and SRO <> 'S'

-- Make sure right item on order
IF EXISTS (select L.orderNumber, L.BASTIMESTAMP, L.ob_Items_RID, Q.ob_Items_RID
    from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
    where L.ob_Items_RID <> Q.ob_Items_RID) BEGIN
    
        Update OrderLines set ob_Items_RID = Q.ob_Items_RID, 
        itemOrSeagullDescription = ISNULL(Q.replaceDescription, I.internalDescription)   
        from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
        inner join Items I on Q.ob_Items_RID = I.ID
        where L.ob_Items_RID <> Q.ob_Items_RID
         
        END

-- MAKE SURE CONTRACTOR ORDERS ARE LINKED TO CORRECT ITEM         
/*
update OrderLines set ps_LinkToContractorOrderLine_RID = Q.ps_LinkToContractorOrderLine_RID
from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
where L.ps_LinkToContractorOrderLine_RID is not null and
Q.ps_LinkToContractorOrderLine_RID <> L.ps_LinkToContractorOrderLine_RID
*/



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
    WHERE U.lostFLag = 0
--    where U.ob_Items_RID = @ITEM or @Item = 0
  
exec ComputeUnitTallyCostDelta 
 
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
    
    UPDATE  Items SET LFStock = isnull(LFUnits,0), UMStock = UMUnits, UMAvailable = UMUnits,
        avgCost = case when LFStockDivisor = 0 then avgCost else ROUND((totalCost / LFStockDivisor),2) end
    FROM Items I inner join (SELECT ob_Items_RID AS Item, SUM(LFStock) as LFUnits, SUM(UMStock) as UMUnits, 
    sum(LFStock * ActualCost) as totalCost, sum(LFStock) as LFStockDivisor 
    FROM Units where UMStock > 0 and lostFlag = 0 and missingFlag <> 1 
    GROUP BY ob_Items_RID)  as U ON U.Item = I.ID
    

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
    where pocketWoodFlag = 1 and lostFlag = 0 and missingFlag <> 1 GROUP BY ob_Items_RID) as U on U.item = I.ID
 
    update items set UMAvailable = 0 where UMAvailable < 0
    
    Update Items set UMAvailableString = case when UMAvailable = 0 then '' else
    format (UMAvailable, '###,##0') end + ' ' + UM from Items
    
/*
update Items set UMAvailableString = case when UMAvailable = 0 then '' else
    format (UMAvailable, '###,##0') end + ' ' + UM
*/

update Items set UMStock = 9999, UMAvailable = 9999, UMAvailableString = '9,999'
where ID between 10000 and 10010


Update PurchaseOrders set directMessage = 
    case when OL.ID is null or C.ID is null then ''
    when OL.ID is null and C.ID is not null then C.name
    when OL.ID is not null and C.ID is not null 
        then RTRIM(C.name) + ' SO #: ' + rtrim(ltrim(cast(O.orderNumber as char(7))))
    end
    from PurchaseOrders P inner join PurchaseLines L on L.ob_PurchaseOrders_RID = P.ID
    inner join Customers C on P.ps_Customers_RID = C.ID
    left outer join OrderLines  OL on OL.ps_PurchaseLines_RID = L.ID
    left outer join Orders O on OL.ob_Orders_RID = O.ID
      
    
-- FIX THE QuantityAvailable in PurchaseLines
Update PurchaseLines set quantityAvailable = 
    --case when L.status = 'Rolling' then ISNULL(U.UMRolling,0) else 
    (L.quantityOrdered - L.quantityReceived)  --END
     - (L.quantityPocketWood + ISNULL(OL.UMOrdered,0))
    from PurchaseLines L 
    left outer join (select ps_PurchaseLines_RID, sum(UMOrdered) as UMOrdered
        from OrderLines group by ps_PurchaseLines_RID)  as OL ON OL.ps_PurchaseLines_RID = L.ID
    left outer join (select ps_PurchaseLines_RID, sum(UMRolling) as UMRolling 
        from Units where Units.pocketWoodFlag = 0 group by ps_PurchaseLines_RID) as U on U.ps_PurchaseLines_RID = L.ID
    where L.status <> 'Complete'

-- RECREATE THE SHIPPABLE, UNSHIPPABLE
exec createshippableunshippable

exec UpdateItemsOpenPOs

exec ComputeItemLastCostandApproxValue

delete from orderUnits where ob_OrderLines_RID is null
--exec CreateUndigByMaxLen

-- CLEAR PROFIT ON TRIP STOP DETAILS FOR CONTRACTORS
UPDATE TripStopDetails set profit = 0
    from TripStopDetails TSD inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.originalShipTo_RID = C.ID
    where C.contractorFlag = 1 and TSD.profit <> 0

-- MAKE SURE TRIP STOPS HAVE CORRECT PROFIT
update TripStops set profit = Z.profit

from TripStops TS inner join (select TS.ID as TSID, sum(TSD.profit) as profit
from TripStopDetails TSD inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
group by TS.ID
having sum(TSD.profit)<>  max(TS.profit) 
) as Z on TS.ID = Z.TSID


-- RECOMPUTE THE NO ORDERLINES W
update Orders set noOrderLinesW = Z 

from Orders O inner join (select ob_Orders_RID, sum(case when WRD = 'W'  and I.UMStock >= L.UMOrdered * 0.90  then 1 else 0 end) as Z 
from orderLines L inner join Items I on L.ob_Items_RID = I.ID group by ob_Orders_RID) as OL 
on O.ID = OL.ob_orders_RID
where O.dateShipped is null
GO
