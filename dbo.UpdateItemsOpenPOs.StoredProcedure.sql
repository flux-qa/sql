USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateItemsOpenPOs]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateItemsOpenPOs]

as

-- UPDATE ITEMS OPEN PO
update items set LFOpenPO = 0, UMOpenPO = 0, UMDirectPO = 0

UPDATE  items SET LFOpenPO = COALESCE(LFOnOrder,0) 
FROM Items I inner join 
    (SELECT ob_Items_RID AS item, SUM(LFOrdered - case when LFReceived > LFOrdered then LFOrdered else LFReceived end) LFOnOrder 
    FROM PurchaseLines L inner join PurchaseOrders P on L.ob_PurchaseOrders_RID = P.ID
    WHERE (p.status = 'Ordered' or P.status = 'Partial' or P.status = 'Rolling') and L.status <> 'Complete'
    --WHERE (L. status = 'Open' or L.status = 'Rolling') 
    --AND P.status <> 'Complete' AND P.status <> 'Cancelled' 
    AND P.ps_Customers_RID is null
    GROUP BY ob_Items_RID) as P on P.item = I.ID

update Items set UMOpenPO = ROUND(LFOpenPO / LFperUM,0) from Items


Update Items set UMDirectPO = totDirects
from Items I inner join (select L.ob_Items_RID, sum(L.quantityOrdered) as totDirects
    from PurchaseLines L inner join PurchaseOrders P on L.ob_PurchaseOrders_RID = P.ID
    where P.status = 'Ordered' AND  P.ps_Customers_RID > 0 
    group by L.ob_Items_RID) as Z on I.ID = Z.ob_Items_RID
GO
