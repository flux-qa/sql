USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckCustomerTripStatus]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CheckCustomerTripStatus]
@TripID integer,
@custno integer,

@unTrippedOrderFlag integer OUTPUT, 
@splitTripFlag integer OUTPUT,
@hasLength18ft integer OUTPUT

as

set @hasLength18ft = 0

-- 1ST SEE IF ANY UNTRIPPED ORDER LINES
--
select @unTrippedOrderFlag = case when count(*) = 0 then 0 else 1 end
    from ORDERLINES L 
    inner join ORDERS O on L.ob_Orders_RID = O.ID
    left outer join TRIPSTOPDETAILS T on T.ps_OrderLines_RID = L.ID
    left outer join TRIPSTOPS TS on T.ob_TripStops_RID = TS.ID
    left outer join TripCalendar TC on TS.ob_TripCalendar_RID = TC.ID
    where O.ob_Customers_RID = @custno and L.UMShipped = 0 and (TC.status = 'Proposed' or TC.status = 'Actual')
    and (O.deferred is null or dateAdd(dd, 1, getDate())  >= O.deferred )
    and TS.ob_TripCalendar_RID is null
    and L.wrd = 'W'

-- 2ND SEE IF ANY ORDERS FOR THIS TRIP ARE NOT FULLY TRIPPED
--
select @splitTripFlag = MAX(case when noLines > noTripped then 1 else 0 end)  from (
select L.orderNumber, count(*) as noLines, 
    sum(case when TS.ob_TripCalendar_RID = @TripID then 1 else 0 end) as noTripped
    from ORDERLINES L 
    inner join ORDERS O on L.ob_Orders_RID = O.ID
    left outer join TRIPSTOPDETAILS T on T.ps_OrderLines_RID = L.ID
    left outer join TRIPSTOPS TS on T.ob_TripStops_RID = TS.ID
    left outer join TripCalendar TC on TS.ob_TripCalendar_RID = TC.ID
    where O.ob_Customers_RID = @custno and L.UMShipped = 0 and (TC.status = 'Proposed' or TC.status = 'Actual')
    and (O.deferred is null or dateAdd(dd, 1, getDate())  >= O.deferred )
    --and TS.ob_TripCalendar_RID is null
    and L.wrd = 'W'
    group by L.orderNumber) as Z where noTripped > 0

-- CHECK IF COD MESSAGE NEEDED
IF Exists (select 1
    from ORDERLINES L 
    inner join ORDERS O on L.ob_Orders_RID = O.ID
    inner join CUSTOMERRELATIONS R on O.ob_BillTo_RID = R.ID
    inner join TRIPSTOPDETAILS T on T.ps_OrderLines_RID = L.ID
    inner join TRIPSTOPS TS on T.ob_TripStops_RID = TS.ID
    inner join TERMS TE on R.whseTerms_RID = TE.ID
    where O.ob_Customers_RID = @custno and left(TE.description,1) = 'C'
    AND TS.ob_TripCalendar_RID = @tripID)
   
        Update TRIPSTOPS set comments = 'COD - DRIVER PICK UP CHECK', CODFlag = 1
            where ob_TripCalendar_RID = @TripID and ps_Customers_RID = @custno
            
-- SEE IF ANY LENGTHS 18' or MORE
    
IF Exists (select 1
    from ORDERLINES L 
    inner join ORDERS O on L.ob_Orders_RID = O.ID
    inner join OrderTally OT on OT.ob_OrderLines_RID = L.ID
    left outer join TRIPSTOPDETAILS T on T.ps_OrderLines_RID = L.ID
    left outer join TRIPSTOPS TS on T.ob_TripStops_RID = TS.ID
    where TS.ob_TripCalendar_RID = @tripID and TS.ps_Customers_RID = @custno
    and OT.length > 17 and OT.pieces > 0 )

    set @hasLength18ft = 1
GO
