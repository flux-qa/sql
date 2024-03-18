USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[N115Condensed]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[N115Condensed]

as



declare @noDays integer = 1



declare @lastDate date = getDate()
declare @firstdate date
declare @historyStart date
set @firstDate = dateAdd(dd, -@Nodays, @lastDate)
set @historyStart = dateAdd(dd, -1, @firstDate)

--select @firstDate, @lastDate

select left(heading,8) as item,  left(description,12) as description, isnull(qtySold,0) as qtySold

from N115Items N inner join  ITEMS I on N.oldCode = I.oldCode

left outer join (
select I.oldCode, sum(case when C.oldCustNo <> 'N115' then customerQty else 0 end) as qtySold
from ORDERLINES L inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
where O.dateEntered between @firstDate and @lastDate
group by I.oldCode

) as Z on N.oldCode = Z.oldCode

--where qtySold is not null

order by N.sortField
GO
