USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateRecentOrders]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateRecentOrders]



as

declare @today date

set @today = cast(getDate() as date)



delete from RecentOrders


Insert into RecentOrders (ID, BASVERSION, BASTIMESTAMP, orderID, lineID, dateEntered, lastChange,
    estDeliveryDate, holdDesign, holdShipments, codFlag, qtyPriceFormatted, code, item, UMStock,
    name, city, sector, tripped, sectorTripped, orderNumber, lineNumber, vpoFlag, tripDate, stopValue, quantityReceived, noSooner, noLater)

select row_number() over (order by O.ID), 1 as BASVERSION, getdate() as BASTIMESTAMP,
O.ID as orderID, L.ID as lineID, O.dateEntered, O.BASTIMESTAMP as lastChange, 
    O.estDeliveryDate, O.holdDesign, O.holdShipments, O.codFlag,
    L.qtyFormatted, I.oldCode as code, I.internalDescription as item, I.UMStock,
    C.name, C.city, S.name as sector, 
    case when T1.ps_Customers_RID IS NULl then 0 else 1 end as tripped,
    case when T2.ps_sector_RID IS NULl then 0 else 1 end as sectorTripped,
    O.orderNumber, L.lineNumber, case when L.ps_PurchaseLines_RID > 0 OR L.ps_LinkToContractorOrderLine_RID > 0 then 1 else 0 end as vpoFlag,
    T1.startTime, Z.stopValue, case when PL.quantityReceived > 0 then format(PL.quantityReceived,'###,##0') else '' end as quantityReceived,
    O.deferred, O.deadline
    

    from OrderLines L inner join Orders O on ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join Sectors S on C.ps_Sector_RID = S.ID
    inner join Items I on L.ob_Items_RID = I.ID
    left outer join PurchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    
    -- SEE IF CUSTOMER IS ALREADY TRIPPED
    left outer join (select TS.ps_Customers_RID, T.startTime from TripStops TS inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
        where T.status = 'Proposed' or T.status = 'Actual') as T1 on T1.ps_Customers_RID = C.ID
        
    -- SEE IF CUSTOMER IS ON SECTOR
    left outer join (select distinct C.ps_Sector_RID
        from TripStops TS inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
        inner join Customers C on TS.ps_Customers_RID = C.ID
        where T.status = 'Proposed' or T.status = 'Actual') as T2 on T2.ps_Sector_RID = C.ps_Sector_RID
        
    -- GET TOTAL STOP VALUE FOR EACH CUSTOMER
     left outer join (select O.ob_Customers_RID, ROUND(sum(UMOrdered * actualPrice / L.per),0) as stopValue
        from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID 
        inner join Items I on L.ob_Items_RID = I.ID
        left outer join PurchaseLines P on L.ps_PurchaseLines_RID = P.ID
        where L.UMShipped = 0 AND
            (O.deferred is null or O.deferred <= @today) 
            and L.UMOrdered <= I.UMStock 
            and (L.ps_PurchaseLines_RID IS NULL or P.dateReceived is not null)
            group by O.ob_Customers_RID) as Z on Z.ob_Customers_RID = C.ID
    
    where UMShipped = 0 AND L.tripNumber = 0 AND L.UMOrdered <= I.UMStock AND (O.deferred is null OR O.deferred >= @today)
    AND (O.dateEntered >= @today 
    OR L.ob_Items_RID in (select ob_Items_RID from Units where dateEntered >= @today and ps_PurchaseLines_RID > 0))
    
    order by O.dateEntered desc
GO
