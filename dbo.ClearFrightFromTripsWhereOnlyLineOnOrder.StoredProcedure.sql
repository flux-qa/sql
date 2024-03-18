USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ClearFrightFromTripsWhereOnlyLineOnOrder]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ClearFrightFromTripsWhereOnlyLineOnOrder]

@custno integer = 6740,
@tripStop   integer = 1651982

as

delete from TripStopDetails where ps_OrderLines_RID in (
    select L.ID
        from Orders O inner join OrderLines L on L.ob_Orders_RID = O.ID
        inner join TripStopDetails TSD on TSD.ps_OrderLines_RID = L.ID AND TSD.ob_TripStops_RID = @tripStop
        where L.dateShipped is null AND L.ob_Items_RID between 10000 and 10010 AND O.OrderNumber NOT IN 
            (select O.orderNumber
            from TripStopDetails TSD inner join OrderLines L on TSD.ps_OrderLines_RID = L.ID
            inner join Orders O on L.ob_Orders_RID = O.ID
            where TSD.ob_TripStops_RID = @tripStop and (L.ob_Items_RID < 10000 OR L.ob_Items_RID > 10010)
            )
      )
      
update orderLines set tripNumber = 0, tripDate = null

    from OrderLines L WHERE L.dateShipped is NULL AND L.ID not in (select ps_OrderLines_RID from TripStopDetails)
    and L.tripNumber > 0
GO
