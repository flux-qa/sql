USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DesignTotalsForTripDate]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DesignTotalsForTripDate]

@tripDate           date = '06/26/2019',
@totalDesignedLines integer out,
@totalWholeUnits    integer out

as

select @totalDesignedLines = sum (case when L.wholeUnits = 1 then 0 else 1 end),
 @totalWholeUnits = sum (case when L.wholeUnits = 1 then 1 else 0 end)
    from OrderLines L inner join TripStopDetails TSD on L.ID = TSD.ps_OrderLines_RID
    inner join TripStops TS on TS.ID = TSD.ob_TripStops_RID
    inner join TripCalendar T on T.ID = TS.ob_TripCalendar_RID
    where T.StartTime = @tripDate and L.designStatus = ''
GO
