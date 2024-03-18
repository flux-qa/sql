USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeTotalsForTripDashboard]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeTotalsForTripDashboard]

@fieldRep char(10) = ''
/*
@noTrips integer OUTPUT,
@noQuotes integer OUTPUT,
@noFresh integer OUTPUT,
@noReminders integer OUTPUT
*/
as


declare @noTrips  integer
declare @noQuotes integer
declare @noFresh integer
declare @noReminders integer


select @noQuotes = count(*), @noFresh = sum(case when datediff(dd, dolChange, getDate()) < 6 then 1 else 0 end)
from QUOTES Q inner join CUSTOMERS C on Q.ob_Customers_RID = C.ID
where C.fieldRep = @fieldRep AND Q.status = 'Q'
;
with w as (
select C.ID, C.fieldRep,
dateAdd(dd, case when datePart(mm, getDate()) = 12 or datePart(mm, getDate()) < 4 then
    21 else 7 end + 457 / isNull(C.noOrderDays,1), 
    case when C.dateOfLastContact is NULL or lastOrder > C.dateOfLastContact 
        then lastOrder else C.dateOfLastContact end) as projectedDateNextContact


 from CUSTOMERS C 
left outer join (select O.ob_Customers_RID as custID, 
    max(O.dateEntered) as lastOrderDate
    from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
    where L.dateShipped > dateAdd(dd, -457, getdate()) and L.per > 0
    group by O.ob_Customers_RID) as w on C.ID = W.custID

where active = 'A' and left(C.name,1) <> '[' and left(C.fieldRep,2) = @FieldRep
)

select @noReminders = count(*) from  W
where projectedDateNextContact < getDate()


select  @noTrips = count(*)

from TRIPCALENDAR T left outer join (select  T.ID, count(Distinct CR.ID) as customersInSector
    from TRIPCALENDAR T inner join TRIPSTOPS TS on TS.ob_TripCalendar_RID = T.ID
    inner join CUSTOMERS C on TS.ps_Customers_RID = C.ID
    inner join CUSTOMERS CR on CR.ps_Sector_RID = C.ps_Sector_RID
    where (@fieldRep = '' OR left(CR.fieldRep,2) = @FieldRep) and CR.active = 'A' and left(CR.name,1) <> '[' 
    AND (T.status = 'Proposed' or T.status = 'Actual')
    group by T.ID) as Z on T.ID = Z.ID

where  Z.customersInSector > 0


Update REGULARUSER set
    numberOpenQuotes = ISNULL(@noQuotes,0), 
    numberFreshQuotes = ISNULL(@noFresh,0), 
    numberOfCustomersToContact = ISNULL(@noReminders,0),
    noTripDashboard = ISNULL(@noTrips,0)

    where LoginName = @fieldRep
GO
