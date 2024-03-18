USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CountTripDashboard]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CountTripDashboard]
@fieldRep char(10) = '',
@noTrips    integer output

as

select  @noTrips = count(*)


from TRIPCALENDAR T left outer join (select  T.ID, count(Distinct CR.ID) as customersInSector
    from TRIPCALENDAR T inner join TRIPSTOPS TS on TS.ob_TripCalendar_RID = T.ID
    inner join CUSTOMERS C on TS.ps_Customers_RID = C.ID
    inner join CUSTOMERS CR on CR.ps_Sector_RID = C.ps_Sector_RID
    where (@fieldRep = '' OR left(CR.fieldRep,2) = @FieldRep) and CR.active = 'A' and left(CR.name,1) <> '[' 
    AND (T.status = 'Proposed' or T.status = 'Actual')
    group by T.ID) as Z on T.ID = Z.ID

where  Z.customersInSector > 0
GO
