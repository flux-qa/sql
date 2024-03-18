USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadCustomersOnTrips]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadCustomersOnTrips]
as

select row_number() over (order by c.name) as ID, 1 as BASVERSION, getDate() as BASTIMESTAMP,
    T.tripNumber, C.name as shipTo, C.city, S.name as sector, T.shipDate

    from Customers C left outer join sectors S on C.ps_Sector_RID = S.ID 
    inner join TripStops TS on C.ID = TS.ps_Customers_RID
    inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
    where (T.status = 'Proposed' OR T.status = 'Actual')
    order by c.name, city
GO
