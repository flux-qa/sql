USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateWholeUnitsToAddToDiggingList]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateWholeUnitsToAddToDiggingList]

@CADID integer = 11154742

as

declare @itemID         integer,
        @maxLen         integer,
        @unit           integer,
        @newHandle      varchar(5),
        @designDate     date,
        @drillNumber    integer

delete from WholeUnitsToAddToDiggingList

select @designDate = designDate, @drillNumber = drillNumber
    from CADDrills where ID = @CADID

DECLARE myCursor CURSOR FOR 
      
    select distinct Z.itemID, Z.maxLen, Z.newHandle
    from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
    inner join
    (select  U.ob_Items_RID as itemID, U.ID as unitID, max(Z.maxLen) as maxLen, 
        min(N.handleLocationAlpha) as newHandle
        from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        inner join (select ob_Units_RID, max(length) as maxLen from UnitLengths 
        where originalQty > 0 group by ob_Units_RID) as Z on Z.ob_Units_RID = U.ID
        left outer join NewHandleOrders N on N.ps_OrderLines_RID = T.ps_OrderLines_RID
        where T.ps_CADDrills_RID = @CADID and U.UMstock = 0
        group by U.ob_Items_RID, U.ID) as Z on L.ob_Units_RID = Z.unitID
    
    -- THIS IS USED TO SEE IF ANY UNUSED UP UNITS FOR THIS LENGTH ARE IN THE DRILL    
    left outer join (select  U.ob_Items_RID as itemID, U.ID as unitID, max(Z.maxLen) as maxLen
        from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        inner join (select ob_Units_RID, max(length) as maxLen from UnitLengths 
        where originalQty > 0 group by ob_Units_RID) as Z on Z.ob_Units_RID = U.ID
        where T.ps_CADDrills_RID = @CADID and U.UMstock > 0
        group by U.ob_Items_RID, U.ID) as Y on U.ob_Items_RID = Y.itemID and Z.maxLen = Y.maxLen   
     
    where Y.maxLen is null -- SKIPS ITEMS / MAXLEN WHERE THERE IS A DEAD UNIT AND ALSO A NON-DEAD IN SAME DRILL           

OPEN myCursor 
FETCH NEXT FROM mycursor INTO  @itemID, @maxLen, @newHandle
WHILE @@FETCH_STATUS = 0  
BEGIN
    set @unit = null
    select top 1 @unit = unit
        from Units U         
        where U.ob_Items_RID = @itemID and U.longLength = @maxLen and U.unitType = 'I' 
        and U.UMStock > 0 AND U.lostFlag = 0 and U.ps_OrderLines_RID is null
        order by dateEntered, pocketWoodFlag
        
    -- FOUND MATCH TO DIG
    IF @unit is NOT NULL
        insert into WholeUnitsToAddToDiggingList(itemID, unit, newHandle)
            select @itemID, @unit, @newHandle

    FETCH NEXT FROM mycursor INTO  @itemID, @maxLen, @newHandle
END 

CLOSE mycursor  
DEALLOCATE mycursor
GO
