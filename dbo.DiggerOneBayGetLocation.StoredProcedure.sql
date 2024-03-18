USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DiggerOneBayGetLocation]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DiggerOneBayGetLocation]

-- last change 1/05/24

@digger         integer = 2,
@location       varchar(5)  out

as



declare @topLocation varchar(5)

-- THE FOLLOWING FINDS THE TOP LOCATION FOR THE DIGGER

;
with w as (
    select U.location,  Z.noTargets, z.noSourcesPerBay , 0 as wholeUnits    
    from CADSourceUnits SU inner join Units U on SU.ps_Unit_RID = U.ID
    inner join OrderLines L on SU.ps_OrderLines_RID = L.ID
    -- THIS SELECT FINDS THE NUMBER OF TARGETS PER SOURCE LOCATION
    inner join (select U.location, count(Distinct T.ps_TargetUnit_RID) as noTargets, 
        count(distinct U.ID) as noSourcesPerBay
        from CADTRANSACTIONS T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join UNITS U on L.ob_Units_RID = U.ID
        inner join OrderLines OL on T.ps_OrderLines_RID = OL.ID
        inner join CADDrills CD on T.ps_CADDrills_RID = CD.ID
        -- MAKE SURE NOT ALREADY IN THE DIGGER ONE BAY FILE
        left outer join DiggerOneBay DM on DM.unitNumber = U.unit 
        and DM.designDate = CD.designDate and DM.drillNumber = CD.drillNumber
        where OL.designStatus = 'Des' and U.location is not null and DM.ID IS NULL
        group by U.location) as Z on Z.location = U.location

    where L.designStatus = 'Des'  
    AND ((len(U.location) = 3 AND (left(U.location,1) <> 'C') 
    OR left(U.location,2) = '0R' or left(U.location,2) = '1L') 
    OR (len(U.location) = 4 and (left(U.location,1) < '0' 
    or left(U.location,1) > '9'))) 
        
union all  
    
    select U.location, 0 as noTargets, 0 as noSourcesPerBay, count(*) as wholeUnits
        from ORDERUNITS OU inner join UNITS U on OU.ps_Units_RID = U.ID
        inner join OrderLines L on OU.ob_OrderLines_RID = L.ID
        inner join CADDRILLS CD on CD.ID = OU.ps_CADDrills_RID
        -- MAKE SURE NOT ALREADY IN DIGGER ONE BAY
        left outer join DiggerOneBay DM on DM.unitNumber = U.unit 
        and DM.designDate = CD.designDate and DM.drillNumber = CD.drillNumber
        where L.designStatus = 'Des' 
        and U.location is not null AND DM.ID IS NULL
        AND ((len(U.location) = 3 AND (left(U.location,1) <> 'C') 
        OR left(U.location,2) = '0R' or left(U.location,2) = '1L') 
        OR (len(U.location) = 4 and (left(U.location,1) < '0' 
        or left(U.location,1) > '9')))
        group by U.location
)  
    
      
select top 1 @location = location
      from W 
      inner join DIGGERBAYLINK D on D.bay = Left(W.location,1)
      inner join DIGGERBAYSTRING S on D.diggerNumber = S.ID 
      where D.diggerNumber = @digger
      
      group by W.location
      order by sum(noTargets) desc, max(noSourcesPerBay) + max(wholeUnits) desc
GO
