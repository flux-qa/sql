USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeOrderShippableStatistics]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeOrderShippableStatistics]     
AS

-- last change 02/10/17
-- called before any / all of the caddesign screens run
-- changed the days till tripdate to be actual #
-- last change 11/13/18 to default Pickup to Tank PU
declare @today date = getDate()

/*
-- GET THE CURRENT DRILL #
declare @maxDrillID integer

select top 1 @maxDrillID = ID from CADDRILLS
where noOrderLines > 0 order by ID desc
*/
-- CLEAR SOME DATA FROM UNSHIPPED ORDERS
update ORDERLINES set UMDesigned = 0, pctDesigned = 0, tank = '',
CADTotalPieces = 0, cadHigh = 0, cadWide = 0, cadPlus = 0
where UMShipped = 0 and designStatus = '';

-- IF ASSIGNED TO A TRIP THEN UPDATE THE TANK #
Update ORDERLINES set tank = T.tank
from ORDERLINES L 
inner join TRIPSTOPDETAILS TSD on TSD.ps_OrderLines_RID = L.ID
inner join TRIPSTOPS TS on TSD.ob_TripStops_RID = TS.ID
inner join TRIPCALENDAR T on TS.ob_TripCalendar_RID = T.ID
where UMShipped = 0 and L.designStatus = '' and T.tank IS NOT NULL and T.Tank <> '';

-- DEFAULT TANK TO SECTOR (or PU if Pickup)
Update ORDERLINES set tank = case when L.pickup = 1 or O.pickup = 1 then 'PU' else S.tank end
from ORDERLINES L 
inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join CUSTOMERS C on O.ob_customers_RID = C.ID
inner join SECTORS S on C.ps_Sector_RID = S.ID
where L.tank = '' and S.tank IS NOT NULL and S.tank <> ''

--with w as (select distinct ob_Items_RID as itemNo 
--from ORDERLINES where ps_CADDrills_RID = @MaxDrillID)

update ORDERLINES
set noLines = coalesce(Z.noLines,0), 
noShippableLines = coalesce(Z.noShippable,0), 
noTrippedLines  = coalesce(Z.noTripped,0), 
minDeadline = Z.minDeadline,
minEstDeliveryDate = Z.minEstDeliveryDate,
--inPlayFlag = case when w.itemNo IS NULL then 0 else 1 end,
 
-- DAYS UNTIL TRIP = 0 IF TRIPPED FOR TOMORROW, ELSE 1 IF NOT TRIPPED OR > 1 DAY FROM TODAY

-- daysUntilTripped is sort order, 0 if tripped for tomorrow or pickup, otherwise 1
daysUntilTrip = case when O.pickup = 1 then 0 when O.codFlag = 1 and O.holdDesign = 0 then 0
    when L.tripDate IS NULL then 9999
    else  
        datediff(dd, @today, L.tripDate) - (datediff(wk, @today, L.tripDate) * 2) -
        case when datepart(dw, @today) = 1 then 1 else 0 end +
        case when datepart(dw, L.tripDate) = 1 then 1 else 0 end 
    end,

-- daysUntilDeadline is sort order, compute the min # of days till due
daysUntilDeadline = case when Z.minDeadline IS NULL then 9999 else  
    datediff(dd, @today, Z.minDeadline) - (datediff(wk, @today, Z.minDeadline) * 2) -
    case when datepart(dw, @today) = 1 then 1 else 0 end +
    case when datepart(dw, Z.minDeadline) = 1 then 1 else 0 end end

from ORDERLINES L INNER JOIN ORDERS O on L.ob_Orders_RID = O.ID
--left outer join w on w.itemNo = L.ob_Items_RID 
left outer join (select O.ob_Customers_RID as custno, count(*) as noLines,
    SUM(case when L.dateShipped IS NULL AND L.UMOrdered <= I.UMStock AND
    (O.deferred IS NULL OR O.deferred <= getDate()) then 1 else 0 end) as noShippable,
    min(o.deadline) as minDeadline, 
    min(case when L.UMOrdered <= I.UMStock then O.estDeliveryDate else '12/31/2029' end) 
        as minEstDeliveryDate, count(distinct L.tripNumber) as noTripped

    FROM ORDERLINES L inner join ORDERS O on L.ob_Orders_RID = O.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID 


    where L.UMShipped = 0 group by O.ob_Customers_RID) as Z on O.ob_Customers_RID = Z.custno

WHERE L.UMShipped = 0


update CUSTOMERS
set unshippedTrippedLines = coalesce(z.noTripped,0),
    unshippedLines = coalesce(z.noOrderLines,0),
    unshippedDesignedLines = coalesce(noDesigned,0),
    unShippedShippableLines = coalesce(noShippable,0)

from CUSTOMERS C left outer join 
    (select ob_Customers_RID as custno, count(*) as noOrderLines, count(distinct T.ID) as noTripped,
    sum(case when L.designStatus is null or L.designStatus <> 'OK' then 0 else 1 end) as noDesigned,
    SUM(case when L.dateShipped IS NULL AND L.UMOrdered <= I.UMStock AND
    (O.deferred IS NULL OR O.deferred <= getDate()) then 1 else 0 end) as noShippable
    from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
    inner join ITEMS I on L.ob_Items_RID = I.ID  
    left outer join TRIPSTOPDETAILS T on L.ID = T.ps_OrderLines_RID
    where L.UMShipped = 0 GROUP BY O.ob_Customers_RID) as Z on C.ID = Z.custno


EXEC CADPreProcessForALL
GO
