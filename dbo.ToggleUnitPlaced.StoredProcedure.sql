USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ToggleUnitPlaced]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ToggleUnitPlaced]

-- last change 3/13/24

@digID      integer,
@high       integer = 0,
@wide       integer = 0

as

declare @datePlaced     dateTime,
        @wholeUnit      integer,
        @unit           integer,
        @success        integer,
        -- FOLLOWING FOR WHOLE UNIT PROCESSING
        @noWholeUnitsForOrderLine   integer,
        @noWholeUnitsProcessed      integer,
        @orderLineID                integer,
        @today                      date
        
set @today = cast(getdate() as date)

-- READ CURRENT STATUS OF DATE PLACED AND IF THIS IS A WHOLE UNIT DIG
select @datePlaced = case when datePlaced is null then getdate() else null end, 
    @wholeUnit = wholeUnit, 
    @unit = unitNumber 
    from DiggerMobile where ID = @digID

if @unit is null
    select 0 as success, 'Invalid DIG ID' as message
else begin    
    
    -- TOGGLE DATE PLACED IN DIGGER MOBILE
    Update DiggerMobile  set datePlaced = @DatePlaced  where ID = @digID
    
    Update RegularUser
        set noDigsToday = noDigsToday + case when @datePlaced is null then -1 else 1 end
        from RegularUser R inner join DiggerMobile D on D.digger = R.diggerNumber
        where D.ID = @digID
    
    Update HandleTargetSources set isPlaced = case when @datePlaced is null then 0 else 1 end

        from HandleTargetSources HTS inner join Units U on HTS.ps_SourceUnit_RID = U.ID
        inner join CADDrills CD on HTS.ps_CADDrills_RID = CD.ID
        inner join DiggerMobile DM on DM.unitNumber = U.Unit
        where DM.ID = @digID and DM.designDate = @today -- ONLY TODAYS DESIGN
    
    -- 03/13/24 -- also update CADTransactions
    Update CADTransactions set sourceUnitDug = case when @datePlaced is null then null else 1 end
        from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        inner join CADDrills D on T.ps_CADDrills_RID = D.ID
        where U.unit = @unit and D.designDate = @today
    
    IF @wholeUnit = 1 begin
        Update Units set dateWorkPapersProcessed = @datePlaced where unit = @unit
        select @orderLineID = ps_OrderLines_RID from Units where unit = @unit
    
        -- NOW SEE IF ALL UNITS HAVE BEEN PROCESSED, IF SO, SET ORDER LINE TO W/P
        select @noWholeUnitsForOrderLine = count(*), 
            @noWholeUnitsProcessed = sum(case when dateWorkPapersProcessed is null then 0 else 1 end) 
            from Units where ps_OrderLines_RID = @orderLineID
        
            Update OrderLines set designStatus = 
                case when @noWholeUnitsProcessed = @noWholeUnitsForOrderLine then 'W/P' else 'Des' end 
            where ID = @orderLineID
  
        end -- IF WHOLE UNIT
        
    select 1 as success, '' as message
    end -- if @unit is null
GO
