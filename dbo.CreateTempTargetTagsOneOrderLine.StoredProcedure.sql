USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTempTargetTagsOneOrderLine]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[CreateTempTargetTagsOneOrderLine]

@orderLineID	integer = 12459909

as
-- last change 11/17/22 --


set nocount on

delete from TempTargetTags
;


with w as (
select
ISNULL(N.west4East0,999) as westEast, row_Number() over (order by N.rowNumber) as rowNo, 
LEFT(ISNULL(N.handleLocationAlpha, I.CADHandle),2) as handle, L.tank, U.unit,
left(C.name,11) as name, LEFT(C.city,20) as city, left(O.PONumber,20) as PONumber, L.orderLineForDisplay




from ORDERLINES L 
LEFT OUTER join 
(select distinct ps_OrderLines_RID, west4East0, rowNumber, handleLocationAlpha
from NewHandleOrders) as N on N.ps_OrderLines_RID = L.ID

inner join ORDERS O on L.ob_Orders_RID = O.ID
inner join ITEMS I on L.ob_Items_RID = I.ID
inner join CUSTOMERS C on O.ob_Customers_RID = C.ID
inner join CADTRANSACTIONS T on T.ps_OrderLines_RID = L.ID
inner join UNITS U on U.ps_OrderLines_RID = L.ID

    where L.ID = @orderLineID
    and L.designStatus = 'Des' and C.ID <> 6456 -- SKIP NEWTECH
)

 insert into TempTargetTags (ID, BASVERSION, BASTIMESTAMP,
	westEast, rowno, handle, tank, unit, name, city, PONumber, orderLineForDisplay)



select next value for myseq, 1, getdate(),
	westEast, row_number() over (order by westEast, X.rowno), handle,
	tank, unit, name, city, PONumber, orderLineForDisplay
	from (select 
		westEast, min(rowno) as rowno, handle,
		tank, unit, name, city, PONumber, orderLineForDisplay
		from w group by westEast, handle, tank, unit, name, city, PONumber, OrderLineForDisplay) as X
GO
