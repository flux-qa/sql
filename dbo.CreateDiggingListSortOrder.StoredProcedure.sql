USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateDiggingListSortOrder]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateDiggingListSortOrder]
@DrillID integer = 3870973

as

delete from diggingListSortOrder

; 

with w as (select U.location,  Z.noTargets, z.noSourcesPerBay , 0 as wholeUnits
    
        from CADSourceUnits SU inner join Units U on SU.ps_Unit_RID = U.ID
        inner join OrderLines L on SU.ps_OrderLines_RID = L.ID
        -- THIS SELECT FINDS THE NUMBER OF TARGETS PER SOURCE LOCATION
        inner join (select U.location, count(Distinct T.ps_TargetUnit_RID) as noTargets, count(distinct U.ID) as noSourcesPerBay
            from CADTRANSACTIONS T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
            inner join UNITS U on L.ob_Units_RID = U.ID
            where T.ps_CADDrills_RID = @drillID and U.location is not null
            group by U.location) as Z on Z.location = U.location
    
        where SU.ps_CADDrills_RID = @drillID   
        
    union  
    
    select U.location, 0 as noTargets, 0 as noSourcesPerBay, count(*) as wholeUnits
        from ORDERUNITS OU inner join UNITS U on OU.ps_Units_RID = U.ID
        inner join CADDRILLS CD on CD.ID = OU.ps_CADDrills_RID
        where CD.ID = @drillID and U.location is not null
        group by U.location
)  
    
insert into diggingListSortOrder (location, noTargets, noSourcesPerBay)
      
select location, sum(noTargets) as noTargets, max(noSourcesPerBay) + max(wholeUnits)
      from W group by location
GO
