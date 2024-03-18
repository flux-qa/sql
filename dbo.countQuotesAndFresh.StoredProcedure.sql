USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[countQuotesAndFresh]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[countQuotesAndFresh]

@fieldRep char(4)

as

declare @noQuotes integer
declare @noFresh integer
declare @noReminders integer

select @noQuotes = count(*), @noFresh = sum(case when datediff(dd, dolChange, getDate()) < 6 then 1 else 0 end)
from QUOTES Q inner join CUSTOMERS C on Q.ob_Customers_RID = C.ID
where C.fieldRep = @fieldRep AND Q.status = 'Q'

select @noReminders = count(*) from CUSTOMERS C 
left outer join (select O.ob_Customers_RID as custID, count (distinct O.dateEntered) as noOrderDays,
    max(O.dateEntered) as lastOrderDate
    from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
    where L.dateShipped > dateAdd(dd, -457, getdate()) and L.per > 0
    group by O.ob_Customers_RID) as w on C.ID = W.custID

where active = 'A' and left(C.name,1) <> '[' and left(C.fieldRep,2) = @FieldRep
and dateAdd(dd, case when datePart(mm, getDate()) = 12 or datePart(mm, getDate()) < 4 then
    21 else 7 end + 457 / isNull(w.noOrderDays,1), case when C.dateOfLastContact is NULL or lastOrderDate > C.dateOfLastContact 
    then lastOrderDate else C.dateOfLastContact end) < getDate()


Update REGULARUSER set
    numberOpenQuotes = ISNULL(@noQuotes,0), 
    numberFreshQuotes = ISNULL(@noFresh,0), 
    numberOfCustomersToContact = ISNULL(@noReminders,0)
    where LoginName = @fieldRep
GO
