USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateNoTargetsInTripStops]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateNoTargetsInTripStops]
as

Update TripStops set noTargets = noUnits
from TripStops T inner join TripCalendar C on T.ob_TripCalendar_RID = C.ID
inner join (

select D.ob_TripStops_RID as tripID, count(*) as noUnits
from orderLines L inner join Units U on L.ID = U.ps_OrderLines_RID
inner join TripStopDetails D on L.ID = D.ps_OrderLines_RID

group by D.ob_TripStops_RID) as Z on T.ID = Z.tripID
WHERE C.status <> 'Complete'
GO
