USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ValidateTripStops]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ValidateTripStops]

@tripNumber     integer = 4264,
@out            varchar(max) OUT

as

    
select @Out = COALESCE(@Out + '   ', '') + 
 rtrim(C.name) + ' ' +  cast(O.orderNumber as varchar(7)) + '-' + cast(L.lineNumber as varchar(2)) 
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    where L.tripNumber = @tripNumber 
    and L.ID not in (
        select TSD.ps_OrderLines_RID
            from TripStopDetails TSD inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
            inner join TripCalendar TC on TS.ob_TripCalendar_RID = TC.ID
            where TC.tripNumber = @tripNumber)
GO
