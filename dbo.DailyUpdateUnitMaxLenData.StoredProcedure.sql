USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DailyUpdateUnitMaxLenData]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DailyUpdateUnitMaxLenData]

as
-- Get the largest ID in the Target File
declare @nextID integer
select @nextID = max(ID) from UnitMaxLenData

Update UnitMaxLenData set inchesHigh = P.inchesHigh
from UnitMaxLenData U inner join PurchaseLengthAnalysisView P on U.ob_Item_RID = P.inventoryID and U.maxLength = P.length
where P.inchesHigh IS NOT NULL

update unitMaxLenData set monthlyUsage = 0

Update UnitMaxLenData set monthlyUsage = round((totalShipped * UMReceived / TotalReceived) / 12.0,0)	
from UnitMaxLenData U inner join 
-- READ THE RECEIVED BY LENGTH AND GET THE TOTAL RECEIVED BY ITEMCODE 
(select inventoryID, length, UMReceived, totalShipped, sum(UMReceived) 
	over (partition by code order by code) as totalReceived from PurchaseLengthAnalysisView P
 inner join (
		-- GET TOTAL SHIPMENTS FOR AN ITEM FOR THE PAST 12 MONTHS
		select ob_Items_RID, sum(UMShipped) as totalShipped from OrderLines L
		where  dateAdd(mm, -12, getDate()) <= dateShipped and WRD = 'W' group by ob_Items_RID) as Z 
			on Z.ob_Items_RID = P.inventoryID
	) as x on X.inventoryID = U.ob_Item_RID and X.length = U.maxLength


/*

select @nextID + row_Number() over (order by inventoryID) as nextID, inventoryID, length, largestUnit, cast(inchesHigh as integer) as inchesHigh, monthlyUsage from 
    (select  P.inventoryID,  length,  max(largestUnit) as largestUnit,  
    max(InchesHigh + 3) as inchesHigh,
    max(round(ISNULL(totalShipped,0) * 0.08333 * UMReceived / case when ISNULL(totalReceived,0) = 0 then 1 else totalReceived end,0)) as monthlyUsage
    from 
    (select distinct inventoryID, length, largestUnit, inchesHigh, UMReceived from PurchaseLengthAnalysisView) as P left outer join 
    (select inventoryID, sum(UMReceived) as totalReceived from PurchaseLengthAnalysisView group by inventoryID)
        as P2 on P.inventoryID = P2.inventoryID       
        left outer join (select ob_Items_RID, sum(UMShipped) as totalShipped from OrderLines 
            where  dateAdd(mm, -12, getDate()) <= dateShipped and WRD = 'W' group by ob_Items_RID) as Z on P.inventoryID = Z.ob_Items_RID    
        group by P.inventoryID, length ) as Y




--Synchronize the target table with refreshed data from source table
MERGE dbo.UnitMaxLenData WITH (SERIALIZABLE) AS TARGET

USING (select @nextID + row_Number() over (order by inventoryID) as nextID, inventoryID, length, largestUnit, cast(inchesHigh as integer) as inchesHigh, monthlyUsage from 
    (select  P.inventoryID,  length,  max(largestUnit) as largestUnit,  
    max(InchesHigh + 3) as inchesHigh,
    max(round(ISNULL(totalShipped,0) * 0.08333 * UMReceived / case when ISNULL(totalReceived,0) = 0 then 1 else totalReceived end,0)) as monthlyUsage
    from 
    (select distinct inventoryID, length, largestUnit, inchesHigh, UMReceived from PurchaseLengthAnalysisView) as P left outer join 
    (select inventoryID, sum(UMReceived) as totalReceived from PurchaseLengthAnalysisView group by inventoryID)
        as P2 on P.inventoryID = P2.inventoryID       
        left outer join (select ob_Items_RID, sum(UMShipped) as totalShipped from OrderLines 
            where  dateAdd(mm, -12, getDate()) <= dateShipped and WRD = 'W' group by ob_Items_RID) as Z on P.inventoryID = Z.ob_Items_RID    
        group by P.inventoryID, length ) as Y) AS SOURCE 
    
ON (TARGET.ob_Item_RID = SOURCE.inventoryID AND TARGET.maxLength = SOURCE.length) 

--When records are matched, update the records if there is any change
WHEN MATCHED 
AND (TARGET.monthlyUsage <> SOURCE.monthlyUsage 
    OR TARGET.stdReceivedUnitSize <> SOURCE.largestUnit 
    OR TARGET.inchesHigh <> SOURCE.inchesHigh
    )
THEN UPDATE SET TARGET.monthlyUsage = SOURCE.monthlyUsage, TARGET.stdReceivedUnitSize = SOURCE.largestUnit, TARGET.inchesHigh = SOURCE.inchesHigh

--When no records are matched, insert the incoming records from source table to target table
WHEN NOT MATCHED BY TARGET 
THEN INSERT ([ID], [BASVERSION], [BASTIMESTAMP], 
        [maxLength],  [ob_Item_REN], [ob_Item_RID], [ob_Item_RMA], 
        [stdReceivedUnitSize], [monthlyUsage], inchesHigh)
         VALUES (SOURCE.nextID, 1, getdate(),
        SOURCE.length, 'Items', SOURCE.inventoryID, null, 
        SOURCE.largestUnit, 0, SOURCE.inchesHigh)
*/
/*
--$action specifies a column of type nvarchar(10) in the OUTPUT clause that returns 
--one of three values for each row: 'INSERT', 'UPDATE', or 'DELETE' according to the action that was performed on that row
OUTPUT $action, 
DELETED.ob_Item_RID AS TInventoryID, 
DELETED.maxLength AS TMaxLength, 
DELETED.monthlyUsage AS TMonthlyUsage,
DELETED.stdReceivedUnitSize as TStdUnitSize,
DELETED.inchesHigh AS TInchesHigh,
INSERTED.ob_Item_RID AS SInventoryID, 
INSERTED.maxLength AS SmaxLength, 
INSERTED.monthlyUsage AS SMonthlyUsage,
INSERTED.stdReceivedUnitSize AS SstdUnitSie,
INSERTED.inchesHigh AS SInchesHigh; 

SELECT @@ROWCOUNT
*/
;

-- WHERE INCHES HIGH IS NULL, COMPUTE IT BY PIECES IN LARGEST UNIT / CAD WIDTH PIECES
Update UnitMaxLenData set inchesHigh = round(dim1 * (totalPcs / CADWidthPieces),0)
    from UnitMaxLenData U inner join (   
 select I.ID, totalPcs, CADWidthPieces, dim1
    from Items I inner join
    (select ob_Items_RID, max(totalPcs) as totalPcs 
    from (select ob_Items_RID, U.ID,  sum(L.originalQty) as totalPcs
        from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
        where U.unitType <> 'T'  and L.originalQty > 0
        group by ob_Items_RID, U.ID
        having sum(L.originalQty) > 0) as Z 
        group by ob_Items_RID) as Y on Y.ob_Items_RID = I.ID) as W on U.ob_Item_RID = W.ID
        where U.inchesHigh is null and dim1 > 0
        
-- ANY ITEM WHERE LESS THAN A YEAR OLD, RECOMPUTE THE MONTHLY USAGE BY PCT OF YEAR        
Update UnitMaxLenData set monthlyUsage = round(U.monthlyUsage * 12.0 / datediff(m, earlyReceived, getdate()),0)
    from UnitMaxLenData U inner join Items I on U.ob_Item_RID = I.ID
    inner join (select ob_Items_RID, min(dateReceived) as earlyReceived from Units group by ob_Items_RID) as Z on Z.ob_items_RID = I.ID
    where  datediff(m, earlyReceived, getdate()) < 12 and datediff(m, earlyReceived, getdate()) > 0
GO
