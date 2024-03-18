USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DiggingSummaryQuery]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DiggingSummaryQuery]
@DrillID integer = 1000381

as


declare @drillNumber integer,
@designDate date

select @drillNumber = drillNumber, @designDate = designDate from CADDRILLS where ID = @drillID

;

with w as (
select distinct D.diggerNumber as digger, @drillNumber as drillNumber, @designDate as designDate,
 'To Handling' as type, SU.ps_Unit_RID as unitNumber, bayList
   
    from CADSOURCEUNITS SU 

    inner join UNITS U on SU.ps_Unit_RID = U.ID
    inner join CADDRILLS CD on CD.ID = SU.ps_CADDrills_RID
    left outer join DIGGERBAYLINK D on D.bay = Left(location,1)
    left outer join DIGGERBAYSTRING S on D.diggerNumber = S.ID 

    Where SU.ps_CADDrills_RID =  @drillID

UNION ALL

select distinct D.diggerNumber as digger, @drillNumber as drillNumber, @designDate as designDate,
'Direct To Tank' as type, OU.ps_Units_RID as unitNumber, bayList
   
    from ORDERUNITS OU 

    inner join UNITS U on OU.ps_Units_RID = U.ID
    inner join CADDRILLS CD on CD.ID = OU.ps_CADDrills_RID
    left outer join DIGGERBAYLINK D on D.bay = Left(location,1)
    left outer join DIGGERBAYSTRING S on D.diggerNumber = S.ID

    Where OU.ps_CADDrills_RID =  @drillID and OU.wholeUnitAssigned = 1

UNION ALL

select distinct D.diggerNumber as digger, @drillNumber as drillNumber, @designDate as designDate,
'Previous To Handling' as type, SU.ps_Unit_RID as unitNumber, bayList
   
    from CADSOURCEUNITS SU 

    inner join UNITS U on SU.ps_Unit_RID = U.ID
    inner join CADDRILLS CD on CD.ID = SU.ps_CADDrills_RID
    left outer join DIGGERBAYLINK D on D.bay = Left(lastLocation,1)
    left outer join DIGGERBAYSTRING S on D.diggerNumber = S.ID

    Where CD.designDate = @DesignDate and CD.drillNumber < @drillNumber and D.diggerNumber is not null

UNION ALL

select distinct D.diggerNumber as digger, @drillNumber as drillNumber, @designDate as designDate,
'Previous Direct To Tank' as type, OU.ps_Units_RID as unitNumber, bayList
   
    from ORDERUNITS OU 

    inner join UNITS U on OU.ps_Units_RID = U.ID
    inner join CADDRILLS CD on CD.ID = OU.ps_CADDrills_RID
    left outer join DIGGERBAYLINK D on D.bay = Left(location,1)
    left outer join DIGGERBAYSTRING S on D.diggerNumber = S.ID

    Where CD.designDate = @DesignDate and OU.wholeUnitAssigned = 1  and CD.drillNumber < @drillNumber
)


select digger, drillNumber, designDate, type, bayList, count(*) as noUnits
from w group by digger, drillNumber, designDate, type, bayList
order by digger, type
GO
