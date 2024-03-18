USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[GenerateTripRouteName]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GenerateTripRouteName]
  

-- Last Change 01/02/16

@tripNo integer,
@route varchar(90) OUTPUT,
@maxStops integer = 5 OUTPUT,
@noLines  integer OUTPUT,
@stopCost integer OUTPUT

as

declare @noSectors  integer
declare @noTrips    integer


-- 1st get the # of distinct sectors
select @noSectors = count(distinct S.ID)
        from TRIPSTOPS T inner join CUSTOMERS C on T.ps_Customers_RID = C.ID
        inner join SECTORS S on C.ps_Sector_RID = S.ID
        where ob_TripCalendar_RID = @tripNo

-- number of stops
select @noLines = count(*) 
    from TRIPSTOPS T inner join TRIPSTOPDETAILS D
    on T.ID = D.ob_TripStops_RID
    where ob_TripCalendar_RID = @tripNo



--select @nosectors as 'no sectors'
delete from SectorsOnTrip where tripID = @tripNo

if @noLines = 0 BEGIN

        set @route = 'empty'
        set @stopCost = 0
        set @maxStops = 0
end



if @noLines > 0 BEGIN
-- 2nd Create records in SectorsOnTrips Table
-- Find all of the trips that have at least all of the selected sectors
-- Do that by making sure the matches = the # of sectors

insert into SectorsOnTrip(tripID, sectorID)
select distinct @tripNo, ob_Sectors_RID
    from ROUTETRIPSECTORS where ob_RouteTrips_RID in (
select ob_RouteTrips_RID from  ROUTETRIPSECTORS 
where ob_Sectors_RID in (
        select distinct C.ps_sector_RID
        from CUSTOMERS C 
        inner join TRIPSTOPS T ON T.ps_Customers_RID = C.ID
        where T.ob_TripCalendar_RID = @tripNo)
group by ob_RouteTrips_RID
having count(*) = @noSectors )


Insert into MyAwareLog(comment, ID, numericComment) values('GenerateTripRouteName', @tripNo, @noSectors)

;
-- 3rd Find the RouteTripName
with w as (
    select name, maxStops, stopCost 
    from ROUTETRIPS where ID in (
        select  distinct ob_RouteTrips_RID
            from ROUTETRIPSECTORS where ob_RouteTrips_RID in (
        select ob_RouteTrips_RID from  ROUTETRIPSECTORS 
        where ob_Sectors_RID in (
                select distinct C.ps_sector_RID
                from CUSTOMERS C 
                inner join TRIPSTOPS T ON T.ps_Customers_RID = C.ID
                where T.ob_TripCalendar_RID = @tripNo)
        group by ob_RouteTrips_RID
        having count(*) = @noSectors )
        and ob_RouteTrips_RID in (select ob_RouteTrips_RID from  ROUTETRIPSECTORS 
        group by ob_RouteTrips_RID
        having count(*) = @noSectors)
    )
)

select @route = name, @MaxStops = maxStops, @stopCost = coalesce(stopCost,1000)
from W


if @route IS NULL -- NO *LEGAL* TRIP
    begin
        select @route = COALESCE(@route + ', ', '') + name
        from (select distinct S.name      
            from TRIPSTOPS T inner join CUSTOMERS C on T.ps_Customers_RID = C.ID
            inner join SECTORS S on C.ps_Sector_RID = S.ID
            where ob_TripCalendar_RID = @tripNo) as Z 
    end

end -- IF @noLines > 0
GO
