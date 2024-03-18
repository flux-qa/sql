USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[createRouteTripSummary]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[createRouteTripSummary]
@TripID integer = 0
as
delete from RouteTripSummary

INSERT INTO [dbo].[ROUTETRIPSUMMARY]([ID], [BASVERSION], [BASTIMESTAMP],
tripID, tripName, noCustomers, noLines, noOrders, BMEs, BMEsperFT3, BMEsperLB)

select max(RT.ID * 1000 + RT.ID) as ID, max(1) as BASVERSION, max(getDate()) as BASTIMESTAMP,
RT.ID as tripID, RT.name as tripName,
count(distinct C.ID) as noCustomers,
count(*) as noLines, count(distinct L.ob_Orders_RID) as noOrders, Round(sum(L.BMEs) / 100, 0) / 10.0 as BMEs,
Round(sum(L.BMEsperFT3),1) as BMEsperFT3, round(sum(L.BMEsperLB),1) as BMEsperLB
from CUSTOMERS C inner join SECTORS S on C.ps_Sector_RID = S.ID
inner join ROUTETRIPSECTORS RTS on RTS.ob_Sectors_RID = S.ID
inner join ROUTETRIPS RT on RTS.ob_RouteTrips_RID = RT.ID
inner join ORDERS O on O.ob_Customers_RID = C.ID
inner join ORDERLINES L on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
where L.dateShipped is null and L.UMOrdered >= I.UMStock
and O.orderNumber not in
(select O.orderNumber from TRIPSTOPDETAILS T
inner join ORDERLINES L on T.ps_OrderLines_RID = L.ID
inner join ORDERS O on L.ob_Orders_RID = O.ID)
-- IF TRIPID PASSED THEN FIND THE # OF DISTINCT SECTORS IN THE SELECTED TRIP
-- AND COUNT THE NUMBER OF ROUTETRIPSECTORS THAT MATCH THE SECTORS IN THE TRIPSTOP
-- IF THEY ARE THE SAME (I.E. 3 DISTINCT SECTORS AND 3 MATCHING RECORDS IN ROUTETRIPS)
-- THEN, THIS IS A KEEPER
and (@TripID = 0 or
RT.ID in (select R.ob_RouteTrips_RID from ROUTETRIPSECTORS R
where ob_Sectors_RID in (
select distinct C.ps_Sector_RID
from TRIPStops S inner join CUSTOMERS C on S.ps_Customers_RID = C.ID
where S.ob_TripCalendar_RID = @TripID)
group by R.ob_RouteTrips_RID
having count(*) = (
select count (distinct C.ps_Sector_RID)
from TRIPStops S inner join CUSTOMERS C on S.ps_Customers_RID = C.ID
where S.ob_TripCalendar_RID = @TripID)
)
)
group by RT.ID, RT.name
order by  RT.name, RT.ID
GO
