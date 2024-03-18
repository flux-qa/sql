USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateLargestIntactUnitByLength]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateLargestIntactUnitByLength]

as

-- 1st CREATE ANY LargestIntactUnitByLength IF THERE IS NO RECORD
INSERT INTO LargestIntactUnitByLength (ID, BASVERSION, BASTIMESTAMP,
    ob_Items_REN, ob_Items_RID, length, high, wide, LF, pieces,dateUpdated)
    

select NEXT VALUE FOR mySeq, 1, getdate(), 
'Items', itemID, maxLen, Y.high, Y.wide, totLF, totPcs, dateReceived
from (select itemID, maxLen, Z.high, Z.wide, totLF, totPcs, dateReceived,
    row_number() over (partition by itemID, maxLen 
        order by itemID, maxLen, totLF desc) as rowno
    from (select U.ob_Items_RID as itemID, U.unit, max(length) as maxLen,
        sum(L.qtyOnHand * L.length) as totLF, sum(L.qtyOnHand) as totPcs,
        max(high) as high, max(wide) as wide, max(dateReceived) as dateReceived
        from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
        where U.unitType = 'I' and U.lostFlag = 0
        and L.qtyOnHand > 0
        group by U.ob_Items_RID, U.unit) as Z
        ) as Y
 
left outer join LargestIntactUnitByLength LI on LI.ob_Items_RID = itemID
    and LI.length = maxLen
    where rowNo = 1 and LI.ID is null
    
-- 2nd UPDATE DATA FOR UNITS RECEIVED TODAY
UPDATE LargestIntactUnitByLength
    set high = Y.high,
    wide = Y.wide,
    LF = Y.totLF,
    pieces = Y.totPcs,
    dateUpdated = getDate()
    
from (select itemID, maxLen, Z.high, Z.wide, totLF, totPcs, dateReceived,
    row_number() over (partition by itemID, maxLen 
        order by itemID, maxLen, totLF desc) as rowno
    from (select U.ob_Items_RID as itemID, U.unit, max(length) as maxLen,
        sum(L.qtyOnHand * L.length) as totLF, sum(L.qtyOnHand) as totPcs,
        max(high) as high, max(wide) as wide, max(dateReceived) as dateReceived
        from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
        where U.unitType = 'I' and U.lostFlag = 0
        and L.qtyOnHand > 0
        group by U.ob_Items_RID, U.unit) as Z
        ) as Y
 
    inner join LargestIntactUnitByLength LI on LI.ob_Items_RID = itemID
    and LI.length = maxLen
    where rowNo = 1 and totLF > LF
GO
