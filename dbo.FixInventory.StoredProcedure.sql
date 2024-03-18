USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FixInventory]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FixInventory]
--
-- 12/19/15
-- 01/15/16 -- ADDED LOGIC TO UPDATE TEMPLATABLE AMOUNTS IN ITEMS
-- 01/31/16 -- Update Customer DateOfLastOrder
-- 02/02/16 -- Updated Unit Length String
-- 06/29/16 -- compute unshipped freight
-- 10/14/16 -- update umAvailString
--

AS


PRINT '--> Clearing Data'
UPDATE UNITS SET LFStock = 0, piecesStock = 0, manuf = ''

UPDATE Items 
    SET LFStock = 0, LFOpenPO = 0,  LFUnshipped = 0, LFPocketWood=0, UMAvailable = 0,
UMAvailableString = '',
    UMOpenPOString = ''

UPDATE ITEMS
SET UMPerString = CASE WHEN UMPer = 1 THEN 'E' WHEN UMPer = 10 THEN 'X' WHEN UMPer = 12 THEN 'D' WHEN UMPer = 100 THEN 'C' ELSE 'M' END
WHERE UMPerSTring IS NULL

print '--> Updating Units and Unit Lengths'
--exec UpdateUnitsFromUnitLengths 0

   
PRINT '---> Updating the UnitLengths Table'
Update UnitLengths set UMOnHand = ROUND(length * qtyOnHand / I.LFperUM,0),
LFOnHand = length * qtyOnHand
from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
inner JOIN Items I ON U.ob_Items_RID = I.ID 
   
PRINT '--> Updating Unit Table'   
-- Updates Units, sets Totals from Unit Lengths
-- Check the Update Statement Below
UPDATE  Units SET LFStock = LFLengths, UMStock = ROUND(LFLengths / LFperUM,0), 
    piecesStock = totPcs, computedPieces = totComputedPieces FROM
    Units U inner join (select U.ID as UnitID, 
        SUM(Length * qtyOnHand) LFLengths, SUM(qtyOnHand) AS totPCS,
        SUM(coalesce(qtyOnHand,0) - FLOOR(isNull(nested2,0) / 2 + isNull(nested3,0) / 3 + isNull(nested4,0) / 4 + isNull(nested5,0) / 5 + isNull(nested6,0) / 6)) as totComputedPieces
        from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
        group by U.ID) as Z on U.ID = Z.UnitID
    inner join Items I ON U.ob_Items_RID = I.ID
 

PRINT '--> Updating Item Master Table'
PRINT '--> Pass 1...'
-- Ditto for Item Master
UPDATE  Items SET LFStock = LFUnits FROM
(SELECT ob_Items_RID AS Item, SUM(LFStock) LFUnits FROM Units
GROUP BY ob_Items_RID) U
JOIN Items I ON U.Item = I.ID

PRINT '--> Fixing PocketWood'

UPDATE items SET LFPocketWood = totLF
FROM Items I INNER JOIN (SELECT ob_Items_RID AS item, SUM(Length * qtyOnHand) AS totLF 
FROM Units U INNER JOIN unitLengths L ON U.ID = L.ob_Units_RID
WHERE U.pocketWoodFlag = 1 GROUP BY U.ob_Items_RID) AS Z ON I.ID = Z.item

PRINT '--> Fixing ShortLongString'
UPDATE UNITS
SET shortLongEorOString = rtrim(CAST(shortLength AS CHAR(2))) + '-' + 
rtrim(CAST(longLength AS CHAR(2))) + ' ' + evenOddRandom
WHERE shortLength < 99 AND longLength < 99 AND shortLength <> longLength

UPDATE UNITS
SET shortLongEorOString = rtrim(CAST(shortLength AS CHAR(2))) + ' ' + evenOddRandom
WHERE shortLength < 99 AND longLength < 99 AND shortLength = longLength

update units set manuf = name
from Units inner join Vendors V on Units.vendorID = V.ID

PRINT '--> Fixing Purchase Lines'
UPDATE purchaselines SET status = 'C'
  FROM purchaseorders P INNER JOIN Purchaselines L ON P.ID = L.ob_PurchaseOrders_RID
  WHERE P.status = 'C' AND L.status <> 'C'
  
update PurchaseLines set LFOrdered = quantityOrdered * LFperUM
from PurchaseLines P inner join Items I on P.ob_Items_RID = I.ID  

PRINT '--> Pass 2...'
PRINT 'Update OpenPO'
UPDATE  items SET LFOpenPO = COALESCE(LFOnOrder,0) FROM
(SELECT ob_Items_RID AS item, SUM(LFOrdered) LFOnOrder FROM PurchaseLines
WHERE status = 'Open'
GROUP BY ob_Items_RID) P
inner JOIN Items I ON P.item = I.ID

UPDATE PurchaseLines
    SET transitDays = DATEDIFF(dd, P.dateSubmitted, L.dateReceived)
FROM PurchaseLines L INNER JOIN PurchaseOrders P
    ON L.ob_PurchaseOrders_RID = P.ID
WHERE P.dateSubmitted IS NOT NULL AND L.dateReceived IS NOT NULL

/*
PRINT 'Update UnShipped'
UPDATE  I SET I.LFUnshipped = LFOnOrder FROM
(SELECT L.ob_Items_RID AS item, SUM(LFMaxQty) LFOnOrder FROM OrderLines L
LEFT OUTER JOIN PurchaseLines P on L.ps_PurchaseLines_RID = P.ID
WHERE LFShipped = 0 and (WRD = 'W' OR P.LFReceived > 0)
GROUP BY L.ob_Items_RID) P
JOIN Items I ON P.item = I.ID
*/



PRINT ' * * * SUCCESSFUL * * *'

PRINT 'Updating UM from LF'
UPDATE items SET UMStock = Round(LFStock / LFperUM,0),
UMPocketWood = Round(LFPocketWood / LFperUM,0),
UMOpenPO = Round(LFOpenPO / LFperUM,0),
UMUnShipped = Round(LFUnshipped / LFperUM,0),
UMAvailable = round(Round(LFStock / LFperUM,0) - (UMPocketWood + UMUnshipped),0),
UMTemplatable = Round(Round(LFStock / LFperUM,0) - ((LFUnShipped + LFPocketWood) / LFperUM),0),
LFTemplatable = LFStock,
pctTemplatable = 1.0,
deltaValueTemplatable = 0,
daysToSunsetQuote = CASE WHEN daysToSunsetQuote > 0 THEN daysToSunsetQuote ELSE 2 END
where LFperUM > 0


    UPDATE  Items SET LFStock = LFUnits, UMStock = ROUND(LFUnits / I.LFperUM,0), UMAvailable = ROUND(LFUnits / I.LFperUM,0) 
    FROM Items I inner join (SELECT ob_Items_RID AS Item, SUM(LFStock) LFUnits FROM Units
    GROUP BY ob_Items_RID)  as U ON U.Item = I.id
    
    Update Items set UMAvailable = UMStock - (isNull(totalUnShipped,0) + ISNULL(totalPocketWood,0))
    from Items I left outer join (select L.ob_items_RID, sum(UMOrdered) as totalUnShipped from OrderLines L 
    left outer join PurchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
        where UMShipped = 0 and ps_PurchaseLines_RID is null and  (SRO <> 'O' OR ISNULL(PL.LFReceived,0) > 0) group by L.ob_Items_RID) as Z on I.ID = Z.ob_Items_RID
    left outer join (SELECT ob_Items_RID AS Item, SUM(UMStock) as totalPocketWood FROM Units
    where pocketWoodFlag = 1 GROUP BY ob_Items_RID) as U on U.item = I.ID



UPDATE items SET UMAvailableString = 
RTRIM(REPLACE(CONVERT(varchar(20), (CAST(UMAvailable AS money)), 1), '.00', '') 
+ ' ' + UM)
WHERE UMAvailable > 0

UPDATE items SET UMOpenPOString = 
RTRIM(REPLACE(CONVERT(varchar(20), (CAST(UMOpenPO AS money)), 1), '.00', '') 
+ ' ' + UM)
WHERE UMOpenPO > 0



PRINT 'Updating Vendor Yearly Totals'
UPDATE VENDORS 
    SET currentPurchases = 0, previousYearPurchases = 0,
    NumberOpenPOs = 0

update VENDORS
set currentPurchases = Z.last12Months, previousYearPurchases = z.prev12Months,
numberOpenPOs = noOpenPOs, DOLPO = lastPO

from VENDORS V inner join (
    select P.ob_vendors_RID,  max(P.PONumber) as PONumber, count(distinct L.PONumber) as noTotalPOs,
  sum (case when P.status <> 'C' then 1 else 0 end) as noOpenPOs,
  max (P.dateEntered) as lastPO,
  cast (sum(case when dateDiff(dd, P.dateEntered, getDate()) < 366 then
    quantityOrdered * cost / costPer else 0 end) as integer) as last12Months,
  cast (sum(case when dateDiff(dd, P.dateEntered, getDate()) > 365
  and dateDiff(dd, P.dateEntered, getDate()) < 732  then
    quantityOrdered * cost / costPer else 0 end) as integer) as prev12Months

    from PurchaseOrders P inner join PurchaseLines L on L.ob_PurchaseOrders_RID = P.ID
    where costPer > 0 
    group by P.ob_vendors_RID) as Z on V.ID = Z.ob_Vendors_RID

-- COMPUTE ORDERLINES TOTALS, THEN ORDER TOTALS THEN CUSTOMER UNSHIPPED TOTALS
Update ORDERLINES 
set lineTotal = round(customerQty * actualPrice / per,2),
totalCost = Round(customerQty * projectedCost / per,2)

Update ORDERS
set totalSale = lineSales, 
totalCost = lineCosts,
totalBMEs = lineBMEs
from ORDERS O inner join (select ob_Orders_RID as orderNumber,
sum(lineTotal) as lineSales, sum(totalCost) as lineCosts, sum(BMEs) as lineBMEs 
from ORDERLINES
group by ob_orders_RID) as L on O.ID = L.orderNumber

Update ORDERS set profit = totalSale - totalCost

Update CUSTOMERS 
    SET unshippedSales = 0, unshippedBMEs=0, 
    unshippedProfit = 0, unshippedCost = 0

Update CUSTOMERS 
    SET unshippedSales = totUnshippedSales, 
    unshippedBMEs=totUnshippedBMEs, 
    unshippedCost = totUnshippedCost,
    unshippedProfit = round(totUnShippedSales - totUnshippedCost,0),
    creditAvailable = creditLimit - coalesce( unshippedSales,0)

from CUSTOMERS C inner join (
    select ob_Customers_RID as custno, sum(totalSale) as totUnShippedSales,
    sum(totalCost) as totUnShippedCost,
    sum(totalBMEs) as totUnshippedBMEs
    FROM ORDERS
    where dateShipped is NULL
    group by ob_customers_RID) as O on C.ID = O.custno


UPDATE CUSTOMERS
SET lastOrder = maxOrderdate
FROM CUSTOMERS C INNER JOIN  (
SELECT ob_Customers_RID AS custno, MAX(dateEntered) AS maxOrderDate
    FROM  ORDERS GROUP BY ob_Customers_RID) AS Z ON C.ID = Z.custno


-- Compute the unshipped Freight
Update CUSTOMERS
set unshippedFreight = 0

Update CUSTOMERS
set unShippedFreight = ROUND(case 
when S.truckCost / (S.maxStops -1) > C.unshippedBMEs * S.truckCost / 20000 
then S.truckCost / (S.maxStops -1)
when C.unshippedBMEs > 20000 then S.truckCost
else C.unshippedBMEs * S.truckCost / 20000 end ,0)

from CUSTOMERS C inner join SECTORS S on C.ps_Sector_RID = S.ID
where S.maxStops > 0 and C.unshippedBMEs > 0

exec UpdateCustomerShipmentTotals

exec ComputeUnitTallyCostDelta

update Items set approxValue = CASE
when UMAvailable <= 0 then 0
when mktprice > 0 then mktPrice
else Round(avgCost + avgCost * grossMargin / 100.0,0)
end

update Items set UMStock = 9999, UMAvailable = 9999, LFStock = 9999, UMAvailableString = 'Unlimited'
where ID > 10000 and ID < 10003

exec createShippableUnShippable
exec ComputeUnitHighAndWide

update customers set balance =  0

update customers set balance = totalOwed
from customers C inner join (select ob_customer_RID as custno, 
    round(SUM(subTotal + salesTax - (totalPaid + totalDiscount + totalCredit)),2) as totalOwed
    from invoices group by ob_customer_RID) as Z on C.ID = Z.custno
    
update CustomerRelations set balance =  0

update customerRelations set balance = totalOwed
from CustomerRelations C inner join (select ob_BillTo_RID as custno, 
    round(SUM(subTotal + salesTax - (totalPaid + totalDiscount + totalCredit)),2) as totalOwed
    from invoices group by ob_BillTo_RID) as Z on C.ID = Z.custno
    
exec updateTemplatePctStock


update Items set avgCost =  round(1.0 * totalCost / totalUM,2) 
from Items I inner join (select ob_Items_RID, sum(UMStock * actualCost) as TotalCost, sum(UMStock) as TotalUM
    from Units where UMStock > 0 group by ob_Items_RID) as Z on I.ID = Z.ob_Items_RID
   

update items set UMAvailableString = format(UMAvailable, '###,##0') + ' ' + UM

delete from orderTally where ob_OrderLines_RID not in (select id from orderLines)
GO
