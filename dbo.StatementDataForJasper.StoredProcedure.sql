USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[StatementDataForJasper]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[StatementDataForJasper]
@statementDate  date = '20210131',
@billTo         integer = 0,
@skipEmail      integer = 0

as

declare 
        @statementStart date,
        @over30         date

set @statementStart = dateAdd(dd, -30, @statementDate)
set @over30         = dateAdd(dd, -30, @statementStart)

select case when I.seqNumber = 0 then rtrim(ltrim(cast(I.invoiceNumber as char(7)))) else
    rtrim(ltrim(cast(I.invoiceNumber as char(7)))) + '-' +rtrim(ltrim(cast(I.seqNumber as char(2)))) end as invoiceNumber,
I.ID, I.ob_BillTo_RID as custno, I.dateEntered, 
case when I.dateShipped is null then I.invoiceDate else I.dateShipped end as dateShipped,
I.dateLastPayment, I.subTotal, I.salesTax, I.subTotal + I.salesTax as invoiceTotal, 
ISNULL(I.totalPaid,0) as totalPaid, ISNULL(I.totalDiscount,0) + ISNULL(I.totalCredit,0) as totalCreditAndDiscount, I.balance,
I.dueDate, I.discountDate, T.discountPct, ROUND(I.subTotal * T.discountPct * 0.01,2) as discountAmount,
Z.currentDue, Z.over30, Z.over60, 
R.name, R.add1, R.add2, R.city, R.state, R.zip, case when z.over30 + z.over60 <= 0 or financeCharge < 0 then 0 else financeCharge end as financeCharge,
R.supressPaymentReceived

from Invoices I inner join CustomerRelations R on I.ob_BillTo_RID = R.ID
left outer join Terms T on R.whseTerms_RID = T.ID

left outer join (select I.ob_BillTo_RID as custno, 
    ROUND(sum(case when dueDate >= @statementDate then 0 else (1 + datediff(mm, dueDate, @statementDate)) * 0.015 * I.balance end),2) as financeCharge,
    ROUND(sum(case when dueDate >= @statementDate then I.balance else 0 end), 2) as currentDue,
    ROUND(sum(case when dueDate >= @statementStart and dueDate < @statementDate then I.balance else 0 end), 2) as over30,
    ROUND(sum(case when dueDate < @statementStart then I.balance else 0 end), 2) as over60

    from Invoices I inner join CustomerRelations R on I.ob_BillTo_RID = R.ID
    where I.balance <> 0 
    group by I.ob_BillTo_RID) as Z on I.ob_BillTo_RID = Z.custno

where (I.balance <> 0 or  (I.dateLastPayment > @statementStart AND R.supressPaymentReceived <> 1 ))
AND (currentDue + over30 + over60 > 0  OR @billTo > 0) and (@billTo = 0 OR @billTo = I.ob_BillTo_RID )
AND (@skipEmail = 0 OR @billto > 0 OR R.emailStatements = 0 OR R.email = '')

order by R.name, I.ob_BillTo_RID, I.dueDate, I.dateEntered, I.invoiceNumber
GO
