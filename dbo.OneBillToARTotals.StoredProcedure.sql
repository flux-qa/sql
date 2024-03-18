USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[OneBillToARTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OneBillToARTotals]

@billToID integer
as

select max(1) as ID, max(1) as BASVERISON, max(getdate()) as BASTIMESTAMP,
    sum(case when datediff(dd, I.dueDate, getdate()) < 0 then I.balance else 0 end) as currentDue,
    sum(case when datediff(dd, I.dueDate, getdate()) >= 0 and datediff(dd, I.dueDate, getdate()) < 31 then I.balance else 0 end) as pastDue,
    sum(case when  datediff(dd, I.dueDate, getdate()) >= 31 and datediff(dd, I.dueDate, getdate()) < 61 then I.balance else 0 end) as over30,
    sum(case when  datediff(dd, I.dueDate, getdate()) >= 61 then I.balance else 0 end) as over60
from Invoices I inner join CustomerRelations R on I.ob_BillTo_RID = R.ID
where I.ob_BillTo_RID = @billToID AND I.balance <> 0
GO
