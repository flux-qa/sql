USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FindOldPocketWoodItems]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FindOldPocketWoodItems]

as

DECLARE 
    @cursor_db CURSOR

DECLARE
    @unitID                         integer, 
    @itemID                         integer,
    @dateReceived                   date, 
    @UMStock                        integer,
    @computedTallyCostDeltaPct      float,
    @avgLen                         float, 
    @shortLongEorOString            varchar(20),
    @newUnitID                      integer

SET @cursor_db = CURSOR FOR
    select distinct u.ID as unitID, U.ob_Items_RID as itemID, U.dateReceived, U.UMStock,
    U.computedTallyCostDeltaPct, Round(U.LFStock / U.piecesStock,1) as avgLen, shortLongEorOString
    from Units U inner join 
    (select U.unit, U.ob_items_RID, U.dateReceived from Units U where U.pocketWoodFlag = 0 and
    U.unitType = 'I' and U.UMStock > 0 ) as Z on U.ob_Items_RID = Z.ob_Items_RID
    
    where U.pocketWoodFlag = 1 and U.lostFlag = 0 and U.unitType = 'I' 
        and U.UMStock > 0 and dateAdd(dd, -30, getdate()) > U.dateReceived
    and dateadd(dd, 30, U.dateReceived) < Z.dateReceived

OPEN @cursor_db;

FETCH NEXT FROM @cursor_db INTO @unitID, @itemID, @dateReceived, @UMStock, 
@computedTallyCostDeltaPct, @avgLen, @shortLongEorOString
    

WHILE @@FETCH_STATUS = 0
BEGIN
    exec FindAndTogglePocketWoodOnNewUnit  @unitID, @itemID, @dateReceived, 
    @computedTallyCostDeltaPct, @avgLen, @shortLongEorOString, @UMStock
    
    FETCH NEXT FROM @cursor_db INTO @unitID, @itemID, @dateReceived, @UMStock, 
    @computedTallyCostDeltaPct, @avgLen, @shortLongEorOString
END;

CLOSE @cursor_db;

DEALLOCATE @cursor_db;

    Update Items set UMAvailable = UMStock - (isNull(totalUnShipped,0) + ROUND(ISNULL(totalPocketWood,0) ,0)), 
    UMPocketWood = ROUND(isNull(totalPocketWood,0) ,0)
    from Items I left outer join (select ob_items_RID, sum(UMOrdered) as totalUnShipped from OrderLines
        where UMShipped = 0 and dateShipped is null and WRD = 'W' 
        group by ob_Items_RID) as Z on I.ID = Z.ob_Items_RID
    left outer join (SELECT ob_Items_RID AS Item, SUM(UMStock) as totalPocketWood FROM Units
    where pocketWoodFlag = 1 and lostFlag = 0 GROUP BY ob_Items_RID) as U on U.item = I.ID
GO
