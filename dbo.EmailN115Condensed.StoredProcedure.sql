USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[EmailN115Condensed]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[EmailN115Condensed]
as 

declare @FileName varchar(40)

declare @ReportDate date
set @ReportDate = dateadd(dd, -1, getDate())

set @FileName = 'DailyUse' + rtrim(cast(cast(dateAdd(dd, -0, @reportDate) as date) as char(12))) + '.csv'

    exec MSDB..sp_send_dbmail @profile_name = 'Bruce',
    @recipients = 'bruce@notalker.com',
    @subject = 'Daily Usage Report',

    @attach_query_result_as_file=1,
    @execute_query_database = 'ALCAwareTest',
    @query_result_header=0,
    @query_attachment_filename=@FileName ,
    @query_result_separator = ',',
    @body = '',

    @query  = 'declare @noDays integer = 1

declare @lastDate date = getDate()
declare @firstdate date
declare @historyStart date
set @firstDate = dateAdd(dd, -@Nodays, @lastDate)
set @historyStart = dateAdd(dd, -1, @firstDate)

select rtrim(heading) as item , rtrim(description) as description, cast(isnull(qtySold,0) as int) as qtySold

from N115Items N inner join  ITEMS I on N.oldCode = I.oldCode

left outer join (
select I.oldCode, sum(customerQty) as qtySold
from ORDERLINES L inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
where O.dateEntered between @firstDate and @lastDate
group by I.oldCode

) as Z on N.oldCode = Z.oldCode

order by N.sortField

'
GO
