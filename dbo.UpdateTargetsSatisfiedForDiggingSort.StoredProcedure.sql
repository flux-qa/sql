USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateTargetsSatisfiedForDiggingSort]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateTargetsSatisfiedForDiggingSort]
@DrillID integer = 3828837

AS

SET NOCOUNT ON


declare @designDate     date,
        @drillNumber    integer
        
select @designDate = designDate, @drillNumber = drillNumber from CADDrills where ID = @drillID        

exec CreateDiggingListSortOrder @drillID


-- LAST CHANGE 12/17/16

-- FIND THE LOCATIONS (BAYS) WHERE A TARGET IS TOTALLY SATISFIED FROM
-- AND THE # OF TARGETS THIS BAY FEEDS
-- UPDATES FIELDS IN SOURCE UNITS TABLE TO BE USED FOR SORTING

Update CADSOURCEUNITS set noTargetsSatisfied = 0, noTargetsFromLocation = 0, noSourcesFromLocation = 0
    where ps_CADDrills_RID = @DrillID

Update ORDERUNITS set sortOrderForDigging = 0 where ps_CADDrills_RID = @DrillID
   

Update CADSOURCEUNITS
    set noTargetsSatisfied = X.noTargetsSatisfied, 
    noTargetsFromLocation = X.noTargetsFromLocation,
    noSourcesFromLocation = W.noSourcesFromLocation
     

from CADSOURCEUNITS SU 
inner join UNITS U on SU.ps_Unit_RID = U.ID
inner join ( 
    -- THIS SELECT COMPUTES THE NUMBER OF TARGETS FOR EACH LOCATION AND COUNTS THE #
    -- OF TARGETS THAT ARE TOTALLY SATISFIED FROM ONE LOCATION
    select location, count(distinct ps_targetUnit_RID) as noTargetsFromLocation,
    sum (case when noLocations = 1 then 1 else 0 end) as noTargetsSatisfied from (

        -- THIS SELECT FINDS THE LOCATION NAME FOR EACH TARGET UNIT
        select distinct U.location, T.ps_TargetUnit_RID , noLocations
        from CADSOURCEUNITS SU 
        inner join UNITS U on SU.ps_Unit_RID = U.ID
        inner join CADTRANSACTIONS T on T.ps_TargetUnit_RID = U.ID
        inner join (
                -- THIS SELECT FINDS THE NUMBER OF DISTINCT LOCATIONS FOR EACH TARGET UNIT
                select T.ps_TargetUnit_RID, count(Distinct U.location) as noLocations
                from CADTRANSACTIONS T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
                inner join UNITS U on L.ob_Units_RID = U.ID
                where T.ps_CADDrills_RID = @DrillID
                group by T.ps_TargetUnit_RID
                    ) as Z on Z.ps_TargetUnit_RID = T.ps_TargetUnit_RID
        ) as Y
        group by location
    ) as X on X.location = U.location

    -- GET THE NUMBER OF SOURCES USED IN THIS BAY
    left outer join (select U.location, count (distinct ps_Unit_RID) as noSourcesFromLocation
    from CADSOURCEUNITS SU inner join UNITS U on SU.ps_Unit_RID = U.ID
    where SU.ps_CADDrills_RID = @DrillID
    group by U.location) as W on W.location = U.location

where SU.ps_CADDrills_RID = @DrillID

-- FIND WHOLE UNITS AND CONNECT VIA LOCATION AND UPDATE THE SORT ORDER
Update ORDERUNITS set sortOrderForDigging = Z.noTargetsSatisfied, noSourcesFromLocation = W.noSourcesFromLocation

from ORDERUNITS OU inner join UNITS U on OU.ps_Units_RID = U.ID
inner join (select location, max(noTargetsSatisfied) as noTargetsSatisfied
    from CADSOURCEUNITS SU inner join UNITS U on SU.ps_Unit_RID = U.ID
    where SU.ps_CADDrills_RID = @DrillID
    group by location) as Z on Z.location = U.Location

   -- GET THE NUMBER OF SOURCES USED IN THIS BAY
    left outer join (select U.location, count (distinct ps_Unit_RID) as noSourcesFromLocation
    from CADSOURCEUNITS SU inner join UNITS U on SU.ps_Unit_RID = U.ID
    where SU.ps_CADDrills_RID = @DrillID
    group by U.location) as W on W.location = U.location


where OU.ps_CADDrills_RID = @DrillID

-- COMPUTE THE SHORT AND LONG LENGTH IN UNIT
update UNITS
set shortLength = minLength,
longLength = maxLength

from  UNITS U 
inner join ORDERUNITS OU on U.ID = OU.ps_Units_RID

inner join (select ob_Units_RID, min(length) as minLength,
max(length) as maxLength from UNITLENGTHS L where qtyOnHand > 0
group by ob_Units_RID) as Z on U.ID = Z.ob_Units_RID

where OU.ps_CADDrills_RID = @drillID


/*
-- CREATE THE DATA FOR THE NEW HANDLING INSTRUCTIONS
delete from NewHandleOrders where designDate = @designDate and drillNumber = @drillNumber  

exec GenerateNewHandlingInstructionsWestOrEast @designDate, @drillNumber, 0 -- Generate for East
exec GenerateNewHandlingInstructionsWestOrEast @designDate, @drillNumber, 4 -- Generate for West
*/
GO
