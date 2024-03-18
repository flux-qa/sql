USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DisplayOrderTotalForTrip]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DisplayOrderTotalForTrip]

@tripNumber integer,
@customer   integer

as

declare @salesTaxPct decimal(10,4)

select @salesTaxPct = salesTaxPct from Customers where id = @customer

delete from InvoiceTotalsForCustomerForTrip

insert into InvoiceTotalsForCustomerForTrip (ID, BASVERSION, BASTIMESTAMP, orderNumber, noLines, orderTotal)

select row_number() over (order by O.orderNumber), 1, getDate(),
O.orderNumber, count(*) as noLines, ROUND(sum(L.UMShipped * L.actualPrice / L.per),2) as invoiceTotal

from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
inner join TripStopDetails TSD on TSD.ps_OrderLines_RID = L.ID
inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
where T.ID = @tripNumber and O.ob_Customers_RID = @customer
group by O.OrderNumber
order by O.OrderNumber


update InvoiceTotalsForCustomerForTrip set orderTotal = orderTotal +
    ROUND(case when isNull(@salesTaxPct,0) = 0 then 0 else isNull(@salesTaxPct,0) end 
        * orderTotal * 0.01,2)
GO
