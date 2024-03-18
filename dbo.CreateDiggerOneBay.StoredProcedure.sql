USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateDiggerOneBay]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateDiggerOneBay]

-- last change 01/05/24 -- added ps_Units and changed Top Location Logic

@digger         integer = 2


as
declare 
@topLocation    varchar(5)

/*

with w as (select  DV.bay, count(*) as noDigsInBay, 
    sum(case when DV.wholeUnit = 1 then 1 else 0 end) as wholeUnits, 
    count(distinct TargetID) as noTargets
    from diggerView DV inner join DiggerOneBay DOB on DV.unit = DOB.unitNumber 
        and DV.designDate = DOB.designDate and DV.drillNumber = DOB.drillNumber
    where DV.digger = @digger and DOB.ID IS NULL    
    group by  DV.bay)

select top 1 @topLocation = bay from w

order by noTargets desc, noDigsInBay + wholeUnits desc
*/
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
    
      
select top 1 @topLocation = location
      from W 
      inner join DIGGERBAYLINK D on D.bay = Left(W.location,1)
      inner join DIGGERBAYSTRING S on D.diggerNumber = S.ID 
      where D.diggerNumber = @digger
      
      group by W.location
      order by sum(noTargets) desc, max(noSourcesPerBay) + max(wholeUnits) desc



INSERT INTO [dbo].[DiggerOneBay]([ID], [BASVERSION], [BASTIMESTAMP],
    bay, digger, destination, code, item, 
    unitNumber, originalUnitNumber, designDate, drillNumber,
    dateEntered, status, wholeUnit, 
    noSubstituteUnits, completeFlag, rowno, skippedFlag,
    ps_Units_REN, ps_Units_RID, pieces, maxLen) 
    


select next value for mySeq, 1, getdate(),
    bay, @digger, cadHandle, code, item, 
    unit, unit, designDate, drillNumber, getdate(), 'Open', wholeUnit,
    case when wholeUnit = 1 then dbo.numberOfSubstituteWholeUnits(Z.unit) 
        else dbo.numberOfValidSourceUnitsToSubstitute(Z.unit) end, 0, 
    row_number() over (partition by IID order by IID, Z.unit) as rowno, 0,
     'Units', UID, piecesStock, maxLen

from (

select distinct U.location as bay, 
    U.ID as UID, null as LID, I.ID as IID, 
    case when NHO.west4East0 is null then I.CADHandle 
        when NHO.west4East0 = 4 then 'West' else 'East' end as CADhandle,
    CD.designDate, CD.drillNumber, 0 as wholeUnit, U.unit,
    I.oldcode as code, I.internaldescription as item, U.piecesStock, 
    case when U.shortLength = U.longLength then '' else 'Max: ' end +
        cast(U.longLength as varchar(2)) + '''' as maxLen
    
    from CADSOURCEUNITS SU 
    inner join UNITS U on SU.ps_Unit_RID = U.ID 
    inner join Items I on U.ob_Items_RID = I.ID
    inner join ORDERLINES L on SU.ps_OrderLines_RID = L.ID
    inner join CADDRILLS CD on CD.ID = SU.ps_CADDrills_RID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
   -- MAKE SURE NOT ALREADY IN DIGGER MOBILE
    left outer join DiggerOneBay DM on DM.unitNumber = U.unit 
    and DM.designDate = CD.designDate and DM.drillNumber = CD.drillNumber
 
    left outer join NewHandleOrders NHO on NHO.ps_OrderLines_RID = L.ID

    left outer join OrderUnits OU on OU.ps_Units_RID = U.ID
         
    Where U.location = @topLocation and L.designStatus = 'Des' 
    and (OU.wholeUnitAssigned is null or OU.wholeUnitAssigned <> 1) 
    AND ((len(U.location) = 3 AND (left(U.location,1) <> 'C') 
    OR left(U.location,2) = '0R' or left(U.location,2) = '1L') 
    OR (len(U.location) = 4 and (left(U.location,1) < '0' 
    or left(U.location,1) > '9')))
    AND DM.ID IS NULL

UNION ALL

    select distinct U.location as bay, 
     U.ID as UID, L.ID as LID, I.ID as IID,
    'Tank: ' + L.tank as CADhandle, 
    CD.designDate, CD.drillNumber, 1 as wholeUnit, U.unit, 
    I.oldcode as code, I.internalDescription as item, U.piecesStock, 
    case when U.shortLength = U.longLength then '' else 'Max: ' end +
        cast(U.longLength as varchar(2)) + '''' as maxLen
    
    from ORDERUNITS OU
    inner join ORDERLINES L on OU.ob_OrderLines_RID = L.ID
    inner join UNITS U on OU.ps_Units_RID = U.ID

    inner join ITEMS I on U.ob_Items_RID = I.ID
    inner join CADDRILLS CD on CD.ID = OU.ps_CADDrills_RID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
   -- MAKE SURE NOT ALREADY IN DIGGER MOBILE
    left outer join DIGGERMOBILE DM on DM.ps_Units_RID = U.ID 
    and DM.designDate = CD.designDate and DM.drillNumber = CD.drillNumber
 
    left outer join PURCHASEORDERS P on U.ps_PurchaseOrders_RID = P.ID
    left outer join VENDORS V on P.ob_Vendors_RID = V.ID
      
    Where U.location = @topLocation and OU.wholeUnitAssigned = 1
    AND DM.ID IS NULL and L.designStatus = 'Des'
    AND
    ((len(U.location) = 3 AND left(U.location,1) <> 'C') OR 
    (len(U.location) = 4 and (left(U.location,1) < '0' or left(U.location,1) > '9')))
   
    ) as Z
GO
