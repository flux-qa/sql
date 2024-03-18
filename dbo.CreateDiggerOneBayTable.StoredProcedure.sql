USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateDiggerOneBayTable]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create procedure [dbo].[CreateDiggerOneBayTable]

as

INSERT INTO [dbo].[DiggerOneBay]([ID], [BASVERSION], [BASTIMESTAMP],
    bay, digger, destination, code, item, 
    unitNumber, originalUnitNumber, designDate, drillNumber,
    dateEntered, status, wholeUnit, 
    noSubstituteUnits, completeFlag, rowno, typeOfDig) 
    
select next value for mySeq, 1, getdate(),
    Z.bay, DBL.diggerNumber, cadHandle, Z.code, Z.item, 
    unit, unit, Z.designDate, Z.drillNumber, getdate(), 'Open', Z.wholeUnit,
    case when Z.wholeUnit = 1 then dbo.numberOfSubstituteWholeUnits(Z.unit) 
        else dbo.numberOfValidSourceUnitsToSubstitute(Z.unit, Z.designDate, Z.drillNumber) end
    , 0, 
    row_number() over (partition by IID order by IID, Z.unit) as rowno,
    'Design'

from (

select distinct U.location as bay, 
    U.ID as UID, null as LID, I.ID as IID, 
    case when NHO.west4East0 is null then I.CADHandle 
        when NHO.west4East0 = 4 then 'West' else 'East' end as CADhandle,
    CD.designDate, CD.drillNumber, 0 as wholeUnit, U.unit,
    I.oldcode as code, I.internaldescription as item
    
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
         
    Where  L.designStatus = 'Des' 
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
    I.oldcode as code, I.internalDescription as item
    
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
      
    Where OU.wholeUnitAssigned = 1
    AND DM.ID IS NULL and L.designStatus = 'Des'
    AND
    ((len(U.location) = 3 AND left(U.location,1) <> 'C') OR 
    (len(U.location) = 4 and (left(U.location,1) < '0' or left(U.location,1) > '9')))
   
    ) as Z inner join DiggerBayLink DBL on DBL.bay = left(Z.bay,1)
    left outer join DiggerOneBay D on 
        D.bay = Z.bay and D.designDate = Z.designDate and D.drillNumber = Z.drillNumber
        
where D.ID IS NULL
GO
