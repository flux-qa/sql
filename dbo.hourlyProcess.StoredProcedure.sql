USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[hourlyProcess]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[hourlyProcess]
as 

update customerquotesummary set oldcode = null where oldcode is not null

update items set lfopenpo = 0
UPDATE  items SET UMOpenPO = COALESCE(UMOnOrder,0) FROM
Items I inner join 
(SELECT ob_Items_RID AS item, SUM(quantityOrdered - isNull(quantityReceived,0)) as UMOnOrder 
FROM PurchaseLines L inner join PurchaseOrders P on L.ob_PurchaseOrders_RID = P.ID
WHERE (L.status = 'Open' or L.status = 'Partial') AND 
    P.status <> 'Complete' AND P.status <> 'Cancelled' AND P.status <> 'Open' AND
    P.dateSubmitted is not null AND P.ps_Customers_RID is null
GROUP BY ob_Items_RID) as P on P.item = I.ID

update Items set LFOpenPO = ROUND(UMOpenPO * LFperUM,0) from Items

update orderLines set dateShipped = O.dateShipped
    from orderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    where L.ob_Items_RID between 10000 and 10010 and O.dateShipped is not null

delete from orders where id not in (select ob_orders_RID from orderLines)

update customerRelations set balance = totBalance
    from customerRelations R inner join (select ob_billto_RID, sum(balance) as totBalance 
    from invoices
    group by ob_billto_RID) as z on R.id = z.ob_billto_RID
    where balance <> totBalance

exec createShippableunshippable
exec UpdateOrderTallyPiecesAvailable
exec ComputeItemLastCostandApproxValue
exec UpdateUnitsFromUnitLengths

-- FIX ORDER LINES WHERE WRONG ITEM ASSIGNED
update OrderLines set ob_Items_RID = Q.ob_Items_RID, itemOrSeagullDescription = Q.replaceDescription
from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
where L.ob_Items_RID <> Q.ob_Items_RID
and UMShipped = 0


-- UPDATE THE ORDER TALLY WHERE IT IS "SHORT" BECAUSE WAS A VPO ORDER AND DIDNT GENERATE CORRECT TALLY AT ORDER TIME
update OrderTally set pieces = L.customerQty
    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join Customers C on O.ob_Customers_RID = C.ID
    inner join OrderTally OT on OT.ob_OrderLines_RID = L.ID
    left outer join PurchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    inner join (select ob_OrderLines_RID, count(*) as noTally from OrderTally group by ob_OrderLines_RID) as Z
        on Z.ob_OrderLines_RID = L.ID
    where Z.noTally = 1 and L.customerUM = 'PCS' and L.UMShipped = 0  and WRD <> 'D'
    and OT.pieces <> L.UMOrdered and L.UMordered <= I.UMStock and OT.Modifier = '' and I.pcsBundle = 1

-- MARK FREIGHT AND HANDLING AS W/P   -- 06/14/21    
Update OrderLines set designStatus = 'W/P', workpapersProcessed = 1 where ob_Items_RID between 10000 and 10010
and UMShipped = 0

-- UPDATE PO IS LATE FLAG FOR OPEN PO'S THAT, DEPENDING ON SHIP VIA, ARE "X" DAYS BEFORE DUE
Update PurchaseOrders set POIsLateFlag = 0 

update PurchaseOrders set POIsLateFlag = 1
WHERE status = 'Ordered' and consignmentFlag = 0 and(
   ((Shipvia = 'Box Rail Car' or ShipVia = 'Flat Rail Car') and datediff(dd, getdate(), estReceivedDate) <= 14) OR
   (ShipVia = 'FlatBed Truck' and datediff(dd,  getdate(), estReceivedDate) < 1) OR
   (ShipVia = 'Van' and datediff(dd, getdate(), estReceivedDate) <= 35) OR
   (ShipVia = 'Courier' and  datediff(dd, getdate(), estReceivedDate) <= 3 ))
GO
