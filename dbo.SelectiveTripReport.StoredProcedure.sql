USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[SelectiveTripReport]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SelectiveTripReport]

@custno  char(6),
@From    datetime,
@Thru    datetime 

as


select O.tripNumber, C.Name, C.FieldRep as rep,  count(*) as noLines,
    sum(cast (L.UMShipped * (L.ActualPrice) / L.per as integer)) as sale,
    sum(cast (L.UMShipped * (L.ActualPrice - L.AvgCost) / L.per as integer)) as profit,
    sum(cast (L.BMEs as integer))  as BMEs
    

    from customers C inner join Orders O on C.ID = O.ob_Customers_RID
    inner join OrderLines L on O.ID = L.ob_Orders_RID
    inner join Items I on L.ob_Items_RID = I.ID
    where O.tripNumber in (select distinct T0.ID

        from TripCalendar T0 inner join TripStops TS on TS.ob_TripCalendar_RID = T0.ID
                inner join TripStopDetails T on T.ob_TripStops_RID = TS.ID
                inner join OrderLines L on T.ps_OrderLines_RID = L.ID 
                where L.ob_Orders_RID in (select H.ID
                from Customers C inner join Orders H on C.ID = H.ob_Customers_RID
                where C.OldCustNo = @custno
                and H.DateShipped between @From and @Thru))

group by O.tripnumber, Name, C.fieldrep
GO
