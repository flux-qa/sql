USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[GenerateNewHandlingInstructionsCreateOutput]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GenerateNewHandlingInstructionsCreateOutput]

-- last change 05/19/2023 -- CHANGED DUP LOGIC
-- 01/30/24 == changed = to >= in Dup Logic


@designDate         date,
@drillNumber        integer,
@orderLineID        integer,
@handleLocation     integer,
@sortOrder          integer,
@comments           varchar(100),
@eastFlag           integer

as

declare @nextID      integer
declare @dupFlag     integer
declare @noSourcesInOriginal    integer

set @nextID = next value for mySeq
select @dupFlag = sourceUsedInDupTargets from TempNewHandle where orderLineID = @orderLineID
select @noSourcesInOriginal = noOpen + noIntact from TempNewHandle where orderLineID = @orderLineID  

INSERT INTO [dbo].[NewHandleOrders]([ID], [BASVERSION], [BASTIMESTAMP], 
    rowNumber, orderNo, firstID, noSource, nonIntactSource, threeSourceFlag, longLength, takeAll, 
    [ps_OrderLines_REN], [ps_OrderLines_RID], 
    [ps_Items_REN], [ps_Items_RID],
    designDate, drillNumber, sourceUnitString, handleLocation, handleLocationAlpha, hardHandle, west4East0) 

select TOP 1 @nextID, 1, getdate(),
    @sortOrder, orderNo, firstID, noOpen + noIntact, noOpen, 1, maxLen, takeAll,
    'OrderLines', @orderLineID, 'Items', itemID,  @designDate, @drillNumber, 
    @comments + CASE WHEN sourceUsedInDupTargets = 0 then '' else ' (DUP)' end , @handleLocation,
    case when @handleLocation = 0 then 'East' when @handleLocation = '9' then 'West' else cast(@handleLocation as char(2)) end,
     hardHandle, @eastFlag
    from TempNewHandle where orderLineID = @orderLineID

     
-- IF THERE ARE DUPLICATE SOURCES ADD ALL OF THEM     
IF @dupFlag >= 1 BEGIN  -- changed 5/10 from > 0-- CHANGED 05/05/23 FROM @DUPFLAG = 1
    INSERT INTO [dbo].[NewHandleOrders]([ID], [BASVERSION], [BASTIMESTAMP], 
    rowNumber, orderNo, firstID, noSource, nonIntactSource, threeSourceFlag, longLength, takeAll, 
    [ps_OrderLines_REN], [ps_OrderLines_RID], 
    [ps_Items_REN], [ps_Items_RID],
    designDate, drillNumber, sourceUnitString, handleLocation, handleLocationAlpha, hardHandle, west4East0)    
    
    select next value for mySeq, 1, getdate(),
    @sortOrder, orderNo, firstID, noSource, noOpen, 1, maxLen, takeAll,
    'OrderLines', orderLineID, 'Items', itemID, @designDate, @drillNumber,
      '(DUP) Added' , @handleLocation,
           case when @handleLocation = '0' then 'East' when @handleLocation = '9' then 'West' else cast(@handleLocation as char(2)) end,
       0, @eastFlag
     FROM
        (select distinct orderNo, firstID, noOpen + noIntact as noSource, noOpen, maxLen, takeAll,
        orderLineID,  itemID
        from TempNewHandle where orderLineID <> @orderLineID and sourceUnit IN 
            (select sourceUnit from TempNewHandle where orderLineID = @orderLineID
             and (@handleLocation = '0' or @handleLocation = '9' or @noSourcesInoriginal + noOpen < 3) 
            )) as Z
       
    
    delete from tempNewHandle 
    -- THIS LOGIC BELOW IS NEW AS OF 5/11/23
    where orderLineID in  (select distinct orderLineID
        from TempNewHandle where orderLineID <> @orderLineID and sourceUnit IN 
            (select sourceUnit from TempNewHandle where orderLineID = @orderLineID
             and (@handleLocation = '0' or @handleLocation = '9' or @noSourcesInoriginal + noOpen < 3) 
            )) 
   
    
    END -- IF @DupFlag    
    
                                     
delete from TempNewHandle where orderLineID = @orderLineID
GO
