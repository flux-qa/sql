USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateOrderTallyForTesting]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateOrderTallyForTesting]
as
delete from ORDERTALLY

update Items set pcsBundle = 1 where pcsBundle < 1

INSERT INTO [dbo].[ORDERTALLY]([ID], [BASVERSION], [BASTIMESTAMP],
 [length], [pieces], [qtyUM], 
 [ob_OrderLines_REN], [ob_OrderLines_RID], [ob_OrderLines_RMA],  [pct]) 

select row_Number() over (order by L.ID ) as recno, 1, getDate(),
T.length, ROUND(ROUND(T.pctStock * L.UMOrdered * I.LFperUM / T.length + 0.4 ,0) / pcsBundle, 0) * pcsBundle as pcs,
ROUND(T.pctStock * L.UMOrdered * I.LFperUM / T.length + 0.4 ,0) / I.LFperUM * T.length
 as qtyUM, 'OrderLines', L.ID, 'om_OrderTally', T.pctStock

from ORDERLINES L inner join ITEMS I on L.ob_Items_RID = I.ID
inner join TEMPLATES T on T.ob_Items_RID = I.ID

where L.UMShipped = 0 and T.length > 0 and I.LFperUM > 0
GO
