USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[QuarterPivotFor1Salesperson]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[QuarterPivotFor1Salesperson]
@FieldRep char(2),
@SelectedYear integer

as 

select C.custno, C.name, c.city, c.state, [1st], [2nd], [3rd], [4th]
from 
(select id, isNull([1],0) as '1st', isNull([2],0) as '2nd', 
isNull([3],0) as '3rd', isNull([4],0) as '4th' from (select C.ID,
datePart(q, L.dateShipped) as qtr,

sum(cast (L.UMShipped * L.actualPrice / L.per as integer))  as saleAmount
from ORDERS O inner join ORDERLINES L on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID

where left(C.fieldRep,2) = @FieldRep and year(L.dateShipped) = @SelectedYear
group by C.ID, datePart(q, L.dateShipped)) as A

pivot (max(saleAmount) for qtr in ([1], [2], [3], [4])) as pvt) as Z
inner join CUSTOMERS C on Z.ID = C.ID

order by Name, state, city
GO
