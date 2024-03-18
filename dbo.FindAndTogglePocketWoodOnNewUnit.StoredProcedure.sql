USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FindAndTogglePocketWoodOnNewUnit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FindAndTogglePocketWoodOnNewUnit]
    @unitID                         integer, 
    @itemID                         integer,
    @dateReceived                   date, 
    @computedTallyCostDeltaPct      float,
    @avgLen                         float, 
    @shortLongEorOString            varchar(20),
    @UMStock                        integer


AS

declare @newUnitID integer
    select top 1 @newUnitID = U.ID
        from Units U where 
        U.ob_Items_RID = @itemID and U.pocketWoodFlag = 0 and
        U.lostFlag = 0 and U.ps_OrderLines_RID is null and
        U.unitType = 'I' and U.UMStock > 0 and shortLongEorOString = @shortLongEorOString
        and U.UMStock = @UMStock -- ADDED 09/05/2023
        and dateadd(dd, 30, @dateReceived) < dateReceived
        and computedTallyCostDeltaPct >= @computedTallyCostDeltaPct
        and abs(Round(LFStock / piecesStock,1) - @avgLen) < 0.6
        order by computedTallyCostDeltaPct desc, Round(LFStock / piecesStock,1) desc,
            U.unit desc

    IF @newUnitID > 0 BEGIN
        BEGIN TRANSACTION
            print 'Replacing Pocketwood Unit: ' + cast(@unitID as varchar(8)) + ' by ' + cast(@newUnitID as varchar(8))
            Update Units set pocketWoodFlag = 0 WHERE ID = @unitID
            Update Units set pocketWoodFlag = 1 WHERE ID = @newUnitID
            insert into OldPocketWoodToNewPocketWoodLog (itemID, oldUnitID, newUnitID)
                values (@itemID, @unitID, @newUnitID)
        COMMIT TRANSACTION 
    END
GO
