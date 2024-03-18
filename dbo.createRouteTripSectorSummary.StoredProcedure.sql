USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[createRouteTripSectorSummary]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[createRouteTripSectorSummary] 

@TripID integer = 0

as

set @TripID = Coalesce(@TripID,0)


delete from ROUTETRIPSECTORSUMMARY

INSERT INTO [dbo].[ROUTETRIPSECTORSUMMARY]
([ID], [BASVERSION], [BASTIMESTAMP], 
sectorID, sectorName, tripID, tripName, routeID, routeName, noCustomers,
noLines, noOrders, BMEs)

select Max(RT.ID * 10000 + RM.ID * 100 + S.ID) as ID,
max(1) as BASVERSION, max(getDate()) as BASTIMESTAMP,
S.ID as sectorID, S.name as sectorName, RT.ID as tripID, RT.name as tripName, 
RM.ID as routeID, RM.name as routeName, count(distinct C.ID) as noCustomers,
count(*) as noLines, count(distinct L.ob_Orders_RID) as noOrders, Round(sum(L.BMEs) / 100, 0) / 10.0 as BMEs 
from CUSTOMERS C inner join SECTORS S on C.ps_Sector_RID = S.ID
inner join ROUTETRIPSECTORS RTS on RTS.ob_Sectors_RID = S.ID
inner join ROUTETRIPS RT on RTS.ob_RouteTrips_RID = RT.ID
inner join ROUTEMASTER RM on RTS.ob_RouteMaster_RID = RM.ID
inner join ORDERS O on O.ob_Customers_RID = C.ID
inner join ORDERLINES L on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
where L.dateShipped is null and L.UMOrdered >= I.UMStock
and L.WRD = 'W' and (@TripID = 0 OR RT.ID = @TripID)
group by S.ID, S.name, RT.ID, RT.name, RM.ID, RM.name
order by RM.name, RM.ID, RT.name, RT.ID, S.ID, S.name
GO
