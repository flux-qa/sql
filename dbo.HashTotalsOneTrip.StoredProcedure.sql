USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[HashTotalsOneTrip]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HashTotalsOneTrip]

@trip       integer = 2015,
@status     integer OUT,
@statusMsg  varchar(1000) OUT

as

set @status = 0
set @statusMsg = 'OK'

-- STEP 1 COMPUTE UNITS UM SHIPPED TO ORDERLINES UMSHIPPED
select @status = count(*) 
    from OrderLines L inner join (
        select U.ps_OrderLines_RID, sum(UMShipped) as unitsUMShipped, count(*) as noUnits from Units U group by U.ps_OrderLines_RID) as Z
     on Z.ps_OrderLines_RID = L.id
    where L.tripNumber = @trip and ABS(UMShipped - unitsUMShipped) > (noUnits - 1)
    
IF @status > 0 BEGIN
    print 'Failed Units Shipped to Order Line Shipped'
    set @statusMsg = cast(@status as char(2)) + 'Line(s) Failed Units Shipped to Order Line Shipped'
    return
    END
  
/*
-- STEP 2 COMPUTE ORDER TOTAL
select @status = count(*)

from TripStops TS 
inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
inner join 
        (select O.ob_Customers_RID, sum(ROUND(L.umShipped * L.actualPrice / L.per,case when L.per = 1000 then 0 else 2 end)) as lineTotal
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    where L.tripNumber = @trip group by O.ob_Customers_RID) as Z on Z.ob_Customers_RID = TS.ps_Customers_RID


where T.tripNumber = @trip and TS.totalSaleAmount <> lineTotal

 
 IF @status > 0 BEGIN
    print 'Failed Order Lines to Order Total'
    set @statusMsg = cast(@status as char(2)) + 'Order Line(s) Failed Order Lines to Order Total'
    return
    END
*/
GO
