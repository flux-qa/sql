USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTemplatesFromStockAndSales]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateTemplatesFromStockAndSales]
as


--delete from Templates
declare @maxID integer

select @maxID =  max(ID) from templates where id < 100000
;


with w as (select ID, sum(totalLF) as itemTotal 
from ItemLengthsStockPlusShipped2Years group by ID)


INSERT INTO [dbo].[Templates]([ID], [BASVERSION], [BASTIMESTAMP], 
[ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], 
 [length], [suggestedPct]) 

select @maxID + row_number() over (order by I.ID, length), 1, getDate(),
'Items', I.ID, null , I.length, round(100.0  * totalLF / itemTotal,1) as suggestedPct
from ItemLengthsStockPlusShipped2Years I left outer join W on I.ID = W.ID

where I.ID not in (select ob_items_rid from Templates)
GO
