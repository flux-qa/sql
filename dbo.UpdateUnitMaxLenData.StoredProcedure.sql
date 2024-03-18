USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateUnitMaxLenData]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateUnitMaxLenData]
@unitID integer

as

declare @maxLen     integer
declare @location   varchar(5)
declare @itemID     integer
declare @unitUM     integer
declare @ID         integer



select @maxlen = max(length) , 
    @location = max(location), 
    @itemID = max(ob_Items_RID),      
    @unitUM = max(U.UMStock) 
    from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    where U.ID = @unitID



update UnitMaxLenData set preferredBay = left(@location,3) where ob_Item_RID = @itemID and maxLength = @maxLen

IF @@ROWCOUNT=0
    INSERT INTO [dbo].[UnitMaxLenData]([ID], [BASVERSION], [BASTIMESTAMP], 
        [maxLength], [preferredBay], [ob_Item_REN], [ob_Item_RID], [ob_Item_RMA], 
        [stdReceivedUnitSize], [monthlyUsage]) 

    select next Value For BAS_IDGEN_SEQ, 1, getdate(),
        @maxLen, left(@location,3) , 'Items', @itemID, null, 
        @unitUM, 0

/*
MERGE dbo.UnitMaxLenData WITH (SERIALIZABLE) AS U
USING (VALUES (@itemID, @maxLen, @location)) AS Z (ob_Item_RID, maxLength, preferredBay)
    ON Z.ob_Item_RID = U.ob_Item_RID AND Z.maxLength = Z.maxLength
WHEN MATCHED THEN 
    UPDATE SET U.preferredBay = Z.preferredBay
WHEN NOT MATCHED THEN
    INSERT ([ID], [BASVERSION], [BASTIMESTAMP], 
        [maxLength], [preferredBay], [ob_Item_REN], [ob_Item_RID], [ob_Item_RMA], 
        [stdReceivedUnitSize], [monthlyUsage])
    values (@ID , 1, getdate(),
        @maxLen, @location, 'Items', @itemID, null, 
        0, 0)
        ;
*/
GO
