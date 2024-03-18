USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[JasperDiggingList]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JasperDiggingList]

/*
* SERVER INSTRUCTIONS ADD EXTRA UNIT WHEN ALL USED UP.  NEED THIS ON DIGGING ALSO
* last change 05/17/23 -- added 1L and 0R to exclusion List
* 01/18/24 -- Changed sort order
*/

@drillID integer = 11282548

as

declare @designDate     date,
        @drillNumber    integer
        
select @designDate = designDate, @drillNumber = drillNumber
    from CADDrills where ID = @drillID



select distinct bay as area, D.diggerNumber as digger, 
    U.unit, left(U.location,1) as Location1, U.location as fromLocation, U.shortLongEorOString as lengths, U.UMStock, 
    I.internalDescription, 
    case when NHO.west4East0 is null then I.CADHandle when NHO.west4East0 = 4 then 'West' else 'East' end as CADhandle, 
    --I.CADHandle,
    I.CADUnDigTo, I.UM,
     DL.noTargets as noTargetsFromLocation, DL.noSourcesPerBay as noSourcesFromLocation,
    '' as customer, '' as Tank, 0 as wholeUnits, CD.designDate, CD.drillNumber,
    	v.name as vendor, s.bayList, I.oldCode, case when Z.ps_Unit_RID IS NULL then '' else 'InPlay' end as inplay,
    	dbo.substituteUnit(U.unit) as substituteUnits, U.longLength

    from CADSOURCEUNITS SU 

    inner join UNITS U on SU.ps_Unit_RID = U.ID
    left outer join DiggingListSortOrder DL on U.location = DL.location
    inner join ORDERLINES L on SU.ps_OrderLines_RID = L.ID
        inner join ITEMS I on U.ob_Items_RID = I.ID
    inner join CADDRILLS CD on CD.ID = SU.ps_CADDrills_RID
    left outer join NewHandleOrders NHO on NHO.ps_OrderLines_RID = L.ID
    left outer join PURCHASEORDERS P on U.ps_PurchaseOrders_RID = P.ID
    left outer join VENDORS V on P.ob_Vendors_RID = V.ID
    left outer join DIGGERBAYLINK D on D.bay = Left(U.location,1)
    left outer join DIGGERBAYSTRING S on D.diggerNumber = S.ID 
    left outer join OrderUnits OU on OU.ps_Units_RID = U.ID
    left outer join (select  distinct CSU.ps_Unit_RID 
        from CADSOURCEUNITS CSU 
        inner join ORDERLINES OL on CSU.ps_OrderLines_RID = OL.ID  
        WHERE CSU.ps_CADDrills_RID < @drillID and OL.wholeUnits = 0 and OL.designStatus = 'Des') as Z on Z.ps_Unit_RID = U.ID
         
    Where SU.ps_CADDrills_RID =  @drillID and 
    (OU.wholeUnitAssigned is null or OU.wholeUnitAssigned <> 1) AND
    ((len(U.location) = 3 AND (left(U.location,1) <> 'C') OR left(U.location,2) = '0R' or left(U.location,2) = '1L') OR 
    (len(U.location) = 4 and (left(U.location,1) < '0' or left(U.location,1) > '9')))


/*
UNION ALL


    select distinct bay as area, D.diggerNumber as digger, 
    U.unit, left(U.location,1) as Location1, U.location as fromLocation, U.shortLongEorOString as lengths, U.UMStock, 
    I.internalDescription, I.CADHandle, I.CADUnDigTo, I.UM,
     DL.noTargets as noTargetsFromLocation, DL.noSourcesPerBay as noSourcesFromLocation,
    '' as customer, '' as Tank, 0 as wholeUnits, @designDate, @drillNumber,
    	v.name as vendor, s.bayList, I.oldCode, 'EXTRA'  as inplay,
    	dbo.substituteUnit(U.unit) as substituteUnits

    from WholeUnitsToAddToDiggingList WU 

    inner join UNITS U on WU.unit = U.unit
    left outer join DiggingListSortOrder DL on U.location = DL.location
        inner join ITEMS I on U.ob_Items_RID = I.ID
    left outer join PURCHASEORDERS P on U.ps_PurchaseOrders_RID = P.ID
    left outer join VENDORS V on P.ob_Vendors_RID = V.ID
    left outer join DIGGERBAYLINK D on D.bay = Left(U.location,1)
    left outer join DIGGERBAYSTRING S on D.diggerNumber = S.ID 
         
*/    
    
    /*
    and SU.ps_Unit_RID NOT In (select  CSU.ps_Unit_RID 
        from CADSOURCEUNITS CSU 
        inner join ORDERLINES OL on CSU.ps_OrderLines_RID = OL.ID  
        WHERE CSU.ps_CADDrills_RID < @drillID and OL.wholeUnits = 0 and OL.designStatus = 'Des')  
    */

UNION ALL

select distinct bay as area, D.diggerNumber as digger, 
    U.unit, left(U.location,1) as Location1, U.location as fromLocation, U.shortLongEorOString as lengths, U.UMStock, 
    I.internalDescription,  I.CADHandle, I.CADUnDigTo, I.UM,
    DL.noTargets as noTargetsFromLocation, DL.noSourcesPerBay,
    C.name as customer, L.tank, 1 as wholeUnits, CD.designDate, CD.drillNumber,
    V.name as vendor, S.bayList, I.oldCode, '', 
    dbo.substituteUnit(U.unit) as substituteUnits, U.longLength


    from ORDERUNITS OU
    inner join ORDERLINES L on OU.ob_OrderLines_RID = L.ID
    inner join ORDERS O on L.ob_Orders_RID = O.ID
    inner join CUSTOMERS C on O.ob_Customers_RID = C.ID

    inner join UNITS U on OU.ps_Units_RID = U.ID
    left outer join DiggingListSortOrder DL on U.location = DL.location

    inner join ITEMS I on U.ob_Items_RID = I.ID
    inner join CADDRILLS CD on CD.ID = OU.ps_CADDrills_RID
    left outer join PURCHASEORDERS P on U.ps_PurchaseOrders_RID = P.ID
    left outer join VENDORS V on P.ob_Vendors_RID = V.ID
    left outer join DIGGERBAYLINK D on D.bay = Left(U.location,1)
    left outer join DIGGERBAYSTRING S on D.diggerNumber = S.ID 
    

    
    Where OU.ps_CADDrills_RID = @drillID and OU.wholeUnitAssigned = 1
    AND
    ((len(U.location) = 3 AND left(U.location,1) <> 'C') OR 
    (len(U.location) = 4 and (left(U.location,1) < '0' or left(U.location,1) > '9')))
    


Order by 
--location
D.diggerNumber, noTargetsFromLocation desc, noSourcesFromLocation desc, 
--U.longLength desc, 
U.location
GO
