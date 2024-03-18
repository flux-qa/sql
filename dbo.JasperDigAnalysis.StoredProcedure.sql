USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperDigAnalysis]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperDigAnalysis]
--  declare
    @fromDate   date = '06/16/2022',
    @thruDate   date = '06/21/2022'

as
 
SET NOCOUNT ON 
 
declare 
    @workdays   integer 
       
Update DigsAnalysis set drill1Bays = 0, drill1Sources = 0, drill1WholeUnits = 0, drill1Targets = 0,
        otherBays = 0, otherSources = 0, otherWholeUnits = 0, otherTargets = 0, drill1UnDigs = 0, otherUnDigs = 0  


SELECT @workDays = (DATEDIFF(dd, @fromDate, @thruDate) + 1)
    -(DATEDIFF(wk, @fromDate, @thruDate) * 2)
    -(CASE WHEN DATENAME(dw, @fromDate) = 'Sunday' THEN 1 ELSE 0 END)
    -(CASE WHEN DATENAME(dw, @thruDate) = 'Saturday' THEN 1 ELSE 0 END)    
  

;
   
drop table if exists #tempW

select heading, undigHeading, handled, designDate, drillNo, unit, location, unitType, dateLoc, targetID into #tempW
from (
select Distinct
    case when (SUBSTRING(U.location,2,1) = 'L' OR SUBSTRING(U.location,2,1) = 'R') AND
    (LEFT(U.location,1) >= '1' AND LEFT(U.location,1) <= '5') OR
    (LEFT(U.location,2) >= 'C5' AND LEFT(U.location,2) <= 'C8') THEN 'West'
    when (SUBSTRING(U.location,2,1) = 'L' OR SUBSTRING(U.location,2,1) = 'R') AND
    ((LEFT(U.location,1) >= '6' AND LEFT(U.location,1) <= '9') OR LEFT(U.location,1) = '0') OR
    (LEFT(U.location,2) >= 'C1' AND LEFT(U.location,2) <= 'C4') THEN 'East'
    when CHARINDEX(LEFT(U.location,1), 'SXYZ') > 0 then 'Special' else DA.heading end as heading,
    
    case when (SUBSTRING(UML.location,2,1) = 'L' OR SUBSTRING(UML.location,2,1) = 'R') AND
    (LEFT(UML.location,1) >= '1' AND LEFT(UML.location,1) <= '5') OR
    (LEFT(UML.location,2) >= 'C5' AND LEFT(UML.location,2) <= 'C8') THEN 'West'
    when (SUBSTRING(UML.location,2,1) = 'L' OR SUBSTRING(UML.location,2,1) = 'R') AND
    ((LEFT(UML.location,1) >= '6' AND LEFT(UML.location,1) <= '9') OR LEFT(UML.location,1) = '0') OR
    (LEFT(UML.location,2) >= 'C1' AND LEFT(UML.location,2) <= 'C4') THEN 'East'
    when CHARINDEX(LEFT(UML.location,1), 'SXYZ') > 0 then 'Special' else DA.heading end as undigHeading,
    

    'H' as handled, D.designDate, case when D.drillNumber = 1 then 1 else 2 end as drillNo, 
    U.unit, U.location, U.unitType, convert(varchar(8), D.designDate, 1) + U.location as dateLoc, T.ps_TargetUnit_RID as targetID 
    from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
    inner join CADDrills D on T.ps_CADDrills_RID = D.ID
    left outer join UndigByMaxLen UML on UML.ob_Items_RID = I.ID and UML.maxlen = U.longLength
    inner join DigsAnalysis DA on (CHARINDEX(left(U.location,1), DA.searchString) > 0) OR
    (DA.heading = case when (SUBSTRING(U.location,2,1) = 'L' OR SUBSTRING(U.location,2,1) = 'R') AND
    (LEFT(U.location,1) >= '1' AND LEFT(U.location,1) <= '5') OR
    (LEFT(U.location,2) >= 'C5' AND LEFT(U.location,2) <= 'C8') THEN 'West'
    when (SUBSTRING(U.location,2,1) = 'L' OR SUBSTRING(U.location,2,1) = 'R') AND
    ((LEFT(U.location,1) >= '6' AND LEFT(U.location,1) <= '9') OR LEFT(U.location,1) = '0') OR
    (LEFT(U.location,2) >= 'C1' AND LEFT(U.location,2) <= 'C4') THEN 'East'
    when CHARINDEX(LEFT(U.location,1), 'SXYZ') > 0 then 'Special' else '' end)
    where D.designDate between @fromDate and @thruDate
union All


select distinct     case when (SUBSTRING(U.location,2,1) = 'L' OR SUBSTRING(U.location,2,1) = 'R') AND
    (LEFT(U.location,1) >= '1' AND LEFT(U.location,1) <= '5') OR
    (LEFT(U.location,2) >= 'C5' AND LEFT(U.location,2) <= 'C8') THEN 'West'
    when (SUBSTRING(U.location,2,1) = 'L' OR SUBSTRING(U.location,2,1) = 'R') AND
    ((LEFT(U.location,1) >= '6' AND LEFT(U.location,1) <= '9') OR LEFT(U.location,1) = '0') OR
    (LEFT(U.location,2) >= 'C1' AND LEFT(U.location,2) <= 'C4') THEN 'East'
    when CHARINDEX(LEFT(U.location,1), 'SXYZ') > 0 then 'Special' 
    when left(U.location,3) = 'OFF' or left(U.location,3) = 'CAB' then 'OFF,CAB'
    else DA.heading end as heading,


    case when (SUBSTRING(UML.location,2,1) = 'L' OR SUBSTRING(UML.location,2,1) = 'R') AND
    (LEFT(UML.location,1) >= '1' AND LEFT(UML.location,1) <= '5') OR
    (LEFT(UML.location,2) >= 'C5' AND LEFT(UML.location,2) <= 'C8') THEN 'West'
    when (SUBSTRING(UML.location,2,1) = 'L' OR SUBSTRING(UML.location,2,1) = 'R') AND
    ((LEFT(UML.location,1) >= '6' AND LEFT(UML.location,1) <= '9') OR LEFT(UML.location,1) = '0') OR
    (LEFT(UML.location,2) >= 'C1' AND LEFT(UML.location,2) <= 'C4') THEN 'East'
    when CHARINDEX(LEFT(UML.location,1), 'SXYZ') > 0 then 'Special' else DA.heading end as undigHeading,
    
     'W' as handled, D.designDate, case when D.drillNumber = 1 then 1 else 2 end as drillNo, 
    U.unit, U.location, U.unitType, convert(varchar(8), D.designDate, 1) + U.location as dateLoc, null as targetID  
    from OrderUnits OU inner join Units U on OU.ps_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
    inner join CADDrills D on OU.ps_CADDrills_RID = D.ID
    left outer join UndigByMaxLen UML on UML.ob_Items_RID = I.ID and UML.maxlen = U.longLength
    inner join DigsAnalysis DA on (CHARINDEX(left(U.location,1), DA.searchString) > 0) OR
    DA.heading = (case when (SUBSTRING(U.location,2,1) = 'L' OR SUBSTRING(U.location,2,1) = 'R') AND
    (LEFT(U.location,1) >= '1' AND LEFT(U.location,1) <= '5') OR
    (LEFT(U.location,2) >= 'C5' AND LEFT(U.location,2) <= 'C8') THEN 'West'
    when (SUBSTRING(U.location,2,1) = 'L' OR SUBSTRING(U.location,2,1) = 'R') AND
    ((LEFT(U.location,1) >= '6' AND LEFT(U.location,1) <= '9') OR LEFT(U.location,1) = '0') OR
    (LEFT(U.location,2) >= 'C1' AND LEFT(U.location,2) <= 'C4') THEN 'East'
    when CHARINDEX(LEFT(U.location,1), 'SXYZ') > 0 then 'Special' 
    when left(U.location,3) = 'OFF' or left(U.location,3) = 'CAB' then 'OFF,CAB' 
    else '' end)
    where D.designDate between @fromDate and @thruDate and unitType <> 'T') as Z


 Update DigsAnalysis set drill1Undigs = Z.drill1Undigs, otherUndigs = Z.otherUnDigs
	from digsAnalysis D inner join (select sum(case when heading <> 'East' and undigHeading = 'East' and drillNo = 1 then 1 else 0 end) as drill1Undigs,
	sum(case when heading <> 'East' and undigHeading = 'East' and drillNo <> 1 then 1 else 0 end) as otherUndigs  
	from #tempW) as Z on 1 = 1
	where heading = 'East'
	
 Update DigsAnalysis set drill1Undigs = Z.drill1Undigs, otherUndigs = Z.otherUnDigs
	from digsAnalysis D inner join (select sum(case when heading <> 'West' and undigHeading = 'West' and drillNo = 1 then 1 else 0 end) as drill1Undigs,
	sum(case when heading <> 'West' and undigHeading = 'West' and drillNo <> 1 then 1 else 0 end) as otherUndigs  
	from #tempW) as Z on 1 = 1
	where heading = 'West'
		



Update DigsAnalysis set 
    drill1Bays = noBaysDrill1, 
    otherBays = noBaysOtherDrill,
    drill1WholeUnits = noWUDrill1, 
    otherWholeUnits = noWUOtherDrill,
    drill1Sources = noDigsDrill1, 
    otherSources = noDigsOtherDrill,
    drill1Targets = noTargetsDrill1,
    otherTargets = noTargetsOther
    
    from DigsAnalysis DA inner join (select heading, 
    count(distinct case when drillNo = 1 then dateLoc else null end) as noBaysDrill1,
    count(distinct case when drillNo = 2 then dateLoc else null end) as noBaysOtherDrill,
    sum(case when handled = 'H' and drillNo = 1 then 1 else 0 end) as noDigsDrill1,
    sum(case when handled = 'H' and drillNo = 2 then 1 else 0 end) as noDigsOtherDrill,
    sum(case when handled = 'W' and drillNo = 1 then 1 else 0 end) as noWUDrill1,
    sum(case when handled = 'W' and drillNo = 2 then 1 else 0 end) as noWUOtherDrill,
	
    count (distinct case when drillNo = 1 then 
    --case when undigHeading = 'West' or undigHeading = 'East' or undigHeading = 'Special' then 
    targetID else null end
    --else null end
    ) as noTargetsDrill1,
    count (distinct case when drillNo = 2 then 
    --case when undigHeading = 'West' or undigHeading = 'East' or undigHeading = 'Special' then
    targetID else null end 
    --else null end
    ) as noTargetsOther
    from #tempW group by heading) as Z on DA.heading = Z.heading


Update DigsAnalysis set 
    drill1Bays = round(drill1Bays / @workDays,0), 
    drill1Sources = round(drill1Sources / @workDays, 0), 
    drill1WholeUnits = round(drill1WholeUnits / @workDays,0),
    drill1Targets = round(drill1Targets / @workDays,0),
    otherBays = round(otherBays / @workDays,0), 
    otherSources = round(otherSources / @workDays,0), 
    otherWholeUnits = round(otherWholeUnits / @workdays,0),
    otherTargets    = round(otherTargets / @workdays,0)
    
--update DigsAnalysis set drill1Targets = 0, otherTargets = 0 where heading not in ('East', 'West', 'Special')    

select heading, drill1Bays, drill1Sources, drill1WholeUnits, drill1Targets,
    otherBays, otherSources, otherWholeUnits, otherTargets, drill1Undigs, otherUndigs
    from DigsAnalysis order by sortOrder
GO
