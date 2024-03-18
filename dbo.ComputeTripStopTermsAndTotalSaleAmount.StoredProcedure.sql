USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeTripStopTermsAndTotalSaleAmount]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeTripStopTermsAndTotalSaleAmount]


as

Update TripStops set totalSaleAmount = 0
    from TripStops TS inner join TripCalendar TC on TS.ob_TripCalendar_RID = TC.ID
    where  TS.ID not in (select ob_TripStops_RID from TripStopDetails)

Update TRIPSTOPS
set terms = terms2, 
    totalSaleAmount = totalPrice,
    CODFlag = case when left(terms2,1) = 'C' then 1 else 0 end,
    CODInstructions = case when left(terms2,1) = 'C' then 
    '** COD ** Pick up check for ' + 
    format(totalPrice + case when salesTaxPct > 0 then round(totalPrice * salesTaxPct * 0.01,2) else 0 end,
     '###,##0.00.00')  else '' end


from TRIPSTOPS TS inner join (
    select TS.ID,  max(t2.description) as terms2, max(isNull(C.salesTaxPct,0)) as salesTaxPct,
    sum(case when L.per = 1000 then 
    ROUND(case when L.UMShipped > 0 then L.UMShipped else L.UMOrdered end  * L.actualPrice / L.per, 2) else
    ROUND(case when L.UMShipped > 0 then L.UMShipped else L.UMOrdered end  * L.actualPrice / L.per, 2) end) 
    as totalPrice
    from TRIPSTOPDETAILS TSD
    inner join TRIPSTOPS TS on TSD.ob_TripStops_RID = TS.ID 
    inner join  ORDERLINES L on TSD.ps_OrderLines_RID = L.ID
    inner join ORDERS O ON L.ob_Orders_RID = O.ID
    inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
--    left outer join TERMS T1 on C.whseTerms_RID = T1.ID
    left outer join CUSTOMERRELATIONS R on O.ob_BillTo_RID = R.ID
    left outer join TERMS T2 on R.whseTerms_RID = T2.ID
    group by TS.ID ) as Z on TS.ID = Z.ID

Update TRIPCALENDAR
set CODFlag = isCOD 
from TRIPCALENDAR INNER JOIN
    (select ob_TripCalendar_RID as tripID, max(case when CODFLag = 1 then 1 else 0 end) as isCOD
    from TRIPSTOPS
    group by ob_TripCalendar_RID) as Z on ID = Z.tripID
GO
