USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateTripStatus]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateTripStatus]


@tripNumber integer = 1074

as

Update TripStops set orderLines = totLines, orderLinesComplete = totLinesComplete, 
    orderLinesMessage = case when totLinesComplete = totLines then 'Ready' else 
        rtrim(ltrim(cast(totLinesComplete as char(2)))) + ' of ' + rtrim(ltrim(cast(totLines as char(2)))) end

from TripStops TS inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
    inner join (select TSD.ob_tripStops_RID as stopNo, 
    count(*) as totLines, 
    sum(case when L.designStatus = 'W/P' then 1 else 0 end) as totLinesComplete
        from TripStopDetails TSD 
        inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID group by TSD.ob_tripStops_RID) as Z on TS.ID = Z.stopNo

where T.tripNumber = @tripNumber
        

Update TripCalendar set noOrderLines = totLines, noOrderLinesComplete = totLinesComplete, 
    orderLinesMessage = case when totLinesComplete = totLines then 'Ready' else 
        rtrim(ltrim(cast(totLinesComplete as char(2)))) + ' of ' + rtrim(ltrim(cast(totLines as char(2)))) end

from TripCalendar T 
    inner join (select TS.ob_tripCalendar_RID as tripNo, 
    count(*) as totLines, 
    sum(case when L.designStatus = 'W/P' AND O.holdShipments <> 1 then 1 else 0 end) as totLinesComplete
        from TripStopDetails TSD inner join TripStops TS on TSD.ob_tripStops_RID = TS.ID
        inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID 
        inner join Orders O on L.ob_Orders_RID = O.ID
        group by TS.ob_tripCalendar_RID) as Z on T.ID = Z.tripNo

where T.tripNumber = @tripNumber
GO
