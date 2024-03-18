USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[RenumberTripStops]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RenumberTripStops]   

@TripID         integer,
@TripStopID     integer = 0,
@NewStopNumber  integer = 0

as

begin transaction
-- 1ST, SAVE THE NEW STOP # BEING CHANGED
Update TRIPSTOPS 
    set stopNumber = 
    case when @newStopNumber > stopNumber then @newStopNumber else @newStopNumber end
    where ID = @TripStopID AND @tripStopID > 0

commit transaction; 

with w as (select ID, stopNumber,
    row_Number() over 
    (order by stopNumber, case when ID = @TripStopID then 1 else 0 end desc) as newStopNumber
    from TRIPSTOPS Q where ob_TripCalendar_RID = @TripID)

-- 2ND order by stop # and renumber the stops
Update TRIPSTOPS 
    set stopNumber = newStopNumber -1, 
    stopNumberStartingWith1 = newStopNumber
from TRIPSTOPS T inner join W on T.ID = W.ID
GO
