USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ShowBackorderTrips]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[ShowBackorderTrips]

as

Select row_number() over (order by TC.tripNumber) as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP, 

TC.tripNumber, C.name, O.orderNumber, cast(TC.StartTime as date) as tripDate 

from TripCalendar TC inner join TripStops TS on tS.ob_TripCalendar_RID = TC.ID
inner join TripStopDetails TSD on TSD.ob_TripStops_RID = TS.ID
inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
inner join Orders O on L.ob_Orders_RID = O.ID
inner join Customers C on O.ob_Customers_RID = C.ID
inner join (select orderNumber, count(distinct tripNumber) as noTrips 
    from orderLines where tripNumber > 0 group by orderNumber having count(distinct tripNumber) > 1) 
    as Z on Z.orderNumber = O.orderNumber
    
where TC.status = 'Rolling'
GO
