USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeTripStopOrderLinesComplete]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeTripStopOrderLinesComplete]
as

update TripStops set orderLines = noOrderLines, 
    orderLinesComplete = noOrderLinesComplete
    from TripStops T inner join (select S.ID, count(*) as noOrderLines, 
    sum(case when L.designStatus = 'W/P' and O.holdShipments <> 1 then 1 else 0 end) as noOrderLinesComplete
    from TripStops S inner join TripCalendar C on S.ob_TripCalendar_RID = C.ID
    inner join TripStopDetails D on S.ID = D.ob_TripStops_RID
    inner join OrderLines L on L.ID = D.ps_OrderLines_RID
    inner join Orders O on L.ob_Orders_RID = O.ID
    where (C.status = 'Proposed' or C.status = 'Actual')
    group by S.ID) as Z on T.ID = Z.ID
    
    
update TripStops set orderLinesMessage = 
    case when orderLinesComplete = orderLines then 'Ready' else
    rtrim(cast(orderLinesComplete as char(2))) + ' of ' + cast(orderLines as char(2)) end  
    
    from TripStops S inner join TripCalendar C on S.ob_TripCalendar_RID = C.ID
    where (C.status = 'Proposed' or C.status = 'Actual')
    
    
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

where T.status = 'Proposed' or T.status = 'Actual'
GO
