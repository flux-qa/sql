USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateTripStopTotalSaleAmount]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateTripStopTotalSaleAmount]

as

declare @salesTaxPct decimal(10,4)

select @salesTaxPct = localSalesTax
    from SYSTEMSETTINGS


-- DELETE DUPLICATE TRIP STOP DETAIL LINES
delete from TripStopDetails where id in (
    select T1.id from tripStopDetails T1 
        inner join TripStopDetails T2 on T1.ps_OrderLines_RID = T2.ps_OrderLines_RID AND T1.ob_TripStops_RID = T2.ob_TripStops_RID
        where  T1.id < t2.id)
    

Update TripStops set totalSaleAmount = invoiceTotal + 
ROUND(case when isNull(C.salesTaxPct,0) = 0 then 0 else isNull(C.salesTaxPct,0) end 
    * invoiceTotal * 0.01,2)
    
from TripStops TS inner join Customers C on TS.ps_Customers_RID = C.ID
inner join (select TS.ID, TS.ps_Customers_RID,
 ROUND(sum(ROUND(L.UMShipped * L.actualPrice / L.per,2)),2) as invoiceTotal

from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
inner join TripStopDetails TSD on TSD.ps_OrderLines_RID = L.ID
inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
where T.status = 'Rolling'
group by TS.ID, TS.ps_Customers_RID) as Z on TS.ID = Z.ID and TS.ps_Customers_RID = Z.ps_Customers_RID


-- ALSO UPDATE THE UNIT TALLY STRING
Update Units set tallyString = dbo.unitTallyShippedtoString(U.id)
from Units U inner join  OrderLines L  on U.ps_OrderLines_RID = L.ID
inner join TripStopDetails TSD on TSD.ps_OrderLines_RID = L.ID
inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
where T.status = 'Rolling'

-- RE-COMPUTE COD FLAG IN TRIP CALENDAR
Update TripCalendar  set codFlag = Z.codFlag
from TripCalendar T inner join (select T.ID,  
    max(case when O.codFlag = 1 then 1 else 0 end ) as codflag

    from TripCalendar T inner join TripStops TS on TS.ob_TripCalendar_RID = T.ID
    inner join TripStopDetails TSD on TSD.ob_TripStops_RID = TS.ID
    inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    where T.status = 'Rolling'
    group by T.ID) as Z on T.ID = Z.ID
GO
