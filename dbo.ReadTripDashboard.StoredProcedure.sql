USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadTripDashboard]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadTripDashboard]
@fieldRep char(5)

as

select  T.ID, T.BASVERSION, T.BASTIMESTAMP, LEFT(DateName(dw, StartTime),3) as dayOfWeek,
StartTime, Subject ,
noStops,  round(T.BMEs / 1000.0,1) as BMEs,
case when noStops >= maxStops or T.BMEsperFT3 > 98 or T.BMEsperLB > 98 then 'FULL'
else format(maxStops - noStops, '#') + ' stops, ' + 
case when BMEsperFT3 > BMEsperLB then format(BMEsperFT3, '#') + '% Cube'
else format(BMEsperLB, '#') + '% LBs' end

end as openToFill, Z.customersInSector, status,
 maxStops, RecID, noOrderLines, RecRule, Subject, openToFill, 
 RecExc, dateTripComplete, stopMsg, EndTime, dayOfWeek, Description, 
 tank, BMEs,  dateTripInvoiceGenerated, shipDate, AllDayEvent, 
 status, orderLinesMessage, mBMEs, estDate, tripNumber,  
 AvailableBMEs, RecRef_REN, RecRef_RID, RecRef_RMA, CODFlag, stopCost, 
 noStops, Priority, profit, DOLChange, route, IsDowntime, 
 OKToShip, noOrderLinesComplete, BMEsperFT3, BMEsperLB, profitAfterFreight, truckCost, driver 





from TRIPCALENDAR T left outer join (select  T.ID, count(Distinct CR.ID) as customersInSector
    from TRIPCALENDAR T inner join TRIPSTOPS TS on TS.ob_TripCalendar_RID = T.ID
    inner join CUSTOMERS C on TS.ps_Customers_RID = C.ID
    inner join CUSTOMERS CR on CR.ps_Sector_RID = C.ps_Sector_RID
    where left(CR.fieldRep,2) = @FieldRep and CR.active = 'A' and left(CR.name,1) <> '['  
    AND  (T.status = 'Proposed' or T.status = 'Actual') 
    group by T.ID) as Z on T.ID = Z.ID

where Z.customersInSector > 0
order by startTime, route
GO
