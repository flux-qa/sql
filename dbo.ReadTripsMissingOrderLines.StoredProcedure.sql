USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadTripsMissingOrderLines]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadTripsMissingOrderLines]

as

select row_number() over (order by T.tripNumber, T.startTime, C.name, O.orderNumber, L.lineNumber) as ID,
1 as BASVERSION, getdate() as BASTIMESTAMP,
T.tripNumber, convert(char(11), T.StartTime,7) as tripDate, C.name as shipTo, C.city,
rtrim(cast(O.orderNumber as char(7))) + '-' + cast(L.lineNumber as char(2)) as orderNo,
 I.oldCode as code, I.internalDescription as item, L.UMOrdered as ordered, I.UMStock as stock, I.UM,
 O.codFlag, O.holdShipments

from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
inner join Customers C on O.ob_Customers_RID = C.ID
inner join Items I on L.ob_Items_RID = I.ID
inner join TripStops TS on O.ob_Customers_RID = TS.ps_Customers_RID
inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
left outer join PurchaseLines P on L.ps_PurchaseLines_RID = P.ID
where (T.status = 'Proposed' or T.status = 'Actual')
    AND L.UMShipped = 0 and L.tripNumber = 0 
    and L.UMOrdered <= I.UMStock and L.WRD <> 'D'  
    and O.pickup = 0
    
    AND (L.WRD = 'W' OR P.LFReceived > 0) 

order by T.tripNumber, T.startTime, C.name, O.orderNumber, L.lineNumber
GO
