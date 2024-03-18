USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateDailyDiggingSummary]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateDailyDiggingSummary] 
as

with w as (
    select bay, max(sourceUnits) as sourceUnits, max(wholeUnits) as wholeUnits from (
    select left(isnull(lastLocation,location),1) as bay, 
        count(distinct U.ID) as sourceUnits, max(0) as wholeUnits
        
        from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        inner join OrderLines OL on T.ps_orderLines_RID = OL.ID
        inner join CADDrills C on T.ps_CADDrills_RID = C.ID
        left outer join OrderUnits OU on OU.ps_CADDrills_RID = C.ID and OU.ob_OrderLines_RID = OL.ID AND
        OU.wholeUnitAssigned = 1
             
        Where C.designDate >= cast(getDate() as date)
        
        group by left(isnull(lastLocation,location),1)
    
union 
    
    select left(isnull(lastLocation,location),1) as bay, max(0) as sourceUnits,
    count(distinct OU.ID) as wholeUnits
    from OrderUnits OU inner join Units U on OU.ps_Units_RID = U.ID
    inner join OrderLines OL on OU.ob_orderLines_RID = OL.ID
    inner join CADDrills C on OU.ps_CADDrills_RID = C.ID
         
    Where C.designDate >= cast(getDate() as date) and OU.wholeUnitAssigned = 1
    
    group by left(isnull(lastLocation,location),1)) as z
    group by bay
    )
    
     
select row_number() over (order by bay) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP, 
bay, wholeUnits, sourceUnits
    from W order by bay
GO
