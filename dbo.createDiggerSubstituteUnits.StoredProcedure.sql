USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[createDiggerSubstituteUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[createDiggerSubstituteUnits]

-- last change 01/30/24


@digID      integer

as

declare 
@sourceUnit integer,
@wholeUnit  integer

select @sourceUnit = unitNumber, @wholeUnit = wholeUnit from DiggerMobile where ID = @digID

delete from DiggerSubstituteUnits WHERE digID = @digID


declare     @currentBay     varchar(20),
            @dateReceived   date,
            @itemID         integer,
            @tallyString    varchar(200),
            @drillID        integer
            
select  @currentBay = location, 
        @dateReceived = cast(dateReceived as date),
        @itemID = ob_Items_RID,
        @tallyString = dbo.unitTallyToString(ID) 
    from Units where unit = @sourceUnit
    
select @drillID = min(ID) from CADDrills where designDate >= cast(getdate() as date)    

;
-- W IS USED WHEN SUBSTITUTING SOURCE UNITS
with w as (
select length, sum(take) as pieces, count(*) as noLengths
    from CADTransactionView 
    where sourceUnit = @sourceUnit
    and designStatus = 'Des'
    group by length)
     
/*
bayFlag = 0 if same bay, 1 if different bay plan to dig, 2 if different bay
dateFlag = 0 if received before, 1 if same date and 2 if received later
tallyFlag = 0 if same tally and 1 if different 
*/


INSERT INTO [dbo].[DiggerSubstituteUnits]([id], [BASVERSION], [BASTIMESTAMP], 
[substituteUnit], sourceUnit, currentBay, bay, dateReceived, UMStock, lengths,
orderNumberUnitAssignedTo, sortOrder, tallyFlag, bayFlag, dateFlag, digID)


select next value for mySeq, 1, getdate(),
unit, @sourceUnit, @currentBay , bay, dateReceived, UMStock, lengths, 
    orderNumberUnitAssignedTo,
    cast(case when tallyFlag = 0 and bayflag = 0 and dateFlag = 0 then 1 -- Same bay, Tally, Older date
        when tallyFlag = 0 and bayflag = 0 and dateFlag = 1 then 2  -- Same Bay, Tally, Same received date
        when tallyFlag = 0 and bayflag = 0 and dateFlag = 2 then 3  -- Same Bay, Tally, Newer received
        when tallyFlag = 0 and bayflag = 1 and dateFlag < 2 then 4  -- Different Bay, Same Tally, plan to Dig today
        when tallyFlag = 0 and bayflag = 2 and dateFlag < 2 then 5  -- Different Bay, Same Tally, Don't plan to Dig today
        when tallyFlag = 1 and bayflag = 0 then 6                   -- Same Bay, Different Tally
        else 7 end as integer) as sortFlag, cast(tallyFlag as integer) as tallyFlag, 
        cast(bayFlag as integer) as bayFlag, cast(dateFlag as integer) as dateFlag, @digID
 from (      
 select U.unit, U.location as bay, cast(U.dateReceived as date) as dateReceived, U.UMStock, 
    U.shortLongEorOString as lengths, ISNULL(OL.orderLineForDisplay, '') as orderNumberUnitAssignedTo,
    case when @currentBay = U.location then 0 when T.location IS NULL then 1 else 1 end as bayFlag,
    case when cast(dateReceived as date) < @dateReceived then 0 
        when cast(dateReceived as date) = @dateReceived then 1 else 2 end as dateFlag,
    case when @tallyString = dbo.unitTallyToString(U.ID) then 0 else 1 end as tallyFlag
         
        FROM Units U inner join Items I on U.ob_Items_RID = I.ID
        
        -- SEE HOW MANY LENGTHS FOR EACH UNIT HAS >= PIECES REQUIRED  -- USED FOR SOURCE UNITS
        left outer join (SELECT U.unit, max(w.noLengths) as noLengths, count(*) as noLengthsValid
	        from UnitLengths L Inner join Units U on L.ob_Units_RID = U.ID
	        inner join W on L.length = W.length
	        where U.ob_Items_RID = @itemID
	        and U.ps_OrderLines_RID is NULL
	        and L.qtyOnHand >= W.pieces
	        and U.unit <> @sourceUnit
	        group by U.unit) as S on U.unit = S.unit
                      
        left outer join OrderLines OL on U.ps_OrderLines_RID = OL.ID
        left outer join (select distinct location 
            from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
                inner join Units U on L.ob_Units_RID = U.ID
                inner join CADDrills D on T.ps_CADDrills_RID = D.ID
                where D.ID >= @drillID) as T on U.location = T.location
        where U.ob_Items_RID = @itemID and U.unit <> @sourceUnit AND U.UMstock > 0 and U.unitType = 'I' 
        and U.lostFlag = 0 and U.missingFlag = 0
        and (@wholeUnit = 1 or S.noLengthsValid = S.noLengths) 
        ) as Z
GO
