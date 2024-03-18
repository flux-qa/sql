USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[NightlyProcess]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[NightlyProcess]

-- LAST CHANGE 10/27/23

as


delete from Aware.dbo.EXECUTION_CONTEXTS 


INSERT INTO [dbo].[InventoryDailyTotals]( [inventoryID], dateUpdated, [oldCode], [LFStock], [UMStock], [LFOpenPO], [UMOpenPO], [avgCost], UMShipped, UMReceived, UMAvailable, UMConsignment) 
select ID, dateadd(dd, -1, cast(getdate() as date)), oldCode, LFStock, UMStock, LFOpenPO, UMOpenPO, avgCost, ISNULL(UMShipped,0), ISNULL(round(LFReceived / I.LFperUM,0),0) as UMReceived, UMAvailable, consignmentUM from ITEMS I 
    left outer join (select ob_Items_RID, sum(UMShipped) as UMShipped from OrderLines 
        where dateShipped between dateAdd(dd, -1, getDate()) and getdate()  group by ob_Items_RID) as US on US.ob_Items_RID = I.ID
     left outer join (select ob_Items_RID, sum(L.length * L.originalQty)  as LFReceived
        from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
        inner join Items I on U.ob_Items_RID = I.ID
        where U.dateReceived between dateAdd(dd, -1, getDate()) and getdate()  group by ob_Items_RID) as UR on UR.ob_Items_RID = I.ID




-- RECOMPUTE THE UNIT SHIPPED QUANTITIES
update units set piecesSHipped = 0, lfshipped = 0, umshipped = 0

Update Units
set  piecesShipped = coalesce(qtyShipped,0),
     LFShipped = coalesce(Z.LFShipped,0),
     UMShipped = ROUND(coalesce(Z.LFShipped,0) / I.LFperUM,0)
    
from Units U inner join Items I on U.ob_Items_RID = I.ID
    inner join (select ob_Units_RID as unitID, 
    sum(qtyShipped) as qtyShipped,
    sum(length * qtyShipped) as LFShipped
    from unitLengths WHERE qtyShipped > 0 group by ob_Units_RID) as Z on U.ID = Z.unitID

-- RECOMPUTE THE TEMPLATES

-- 1ST ADD ANY MISSING LENGTHS
Insert into Templates (ID, BASVERSION, BASTimeStamp, ob_Items_REN, ob_Items_RID, ob_Items_RMA, length)
    select next Value for BAS_IDGEN_SEQ, 1, getdate(), 'Items', Z.ob_Items_RID, null, Z.length
from (select distinct U.ob_Items_RID, L.length from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    left outer join Templates T on T.ob_Items_RID = U.ob_Items_RID and T.length = L.length
    where L.qtyOnHand > 0 and T.ID IS NULL) as Z
    
update Templates set suggestedPCT = round(100.0  * ISNULL(totalLF,0) / itemTotal,1) 
    from Templates T left outer join ItemLengthsStockPlusShipped2Years I on T.ob_Items_RID = I.ID and T.length = I.length
    inner join (select ID, sum(totalLF) as itemTotal
        from ItemLengthsStockPlusShipped2Years 
        group by ID
        ) as w on T.ob_Items_RID = W.ID
    where itemTotal > 0

EXEC UpdateUnitsFromUnitLengths


-- MAKE SURE ALL SERVICE CHARGES HAVE A DATE SHIPPED
update orderLines set dateShipped = O.dateShipped, UMShipped = UMOrdered,  
    shipDateOrDesignStatus = convert(varchar(10), O.dateShipped, 7)
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    where O.dateShipped > '12/01/2018' and L.ob_Items_RID between 10000 and 10010 and (L.dateShipped is null or UMShipped = 0)

-- DITTO FOR ANY SHIPPED DATE (i.e. Directs)
update orderLines set shipDateOrDesignStatus = rtrim(convert(char(12), dateShipped, 7))
where dateShipped is not null and shipDateOrDesignStatus is null


-- SAVE PA TOTALS FOR DAILY COMPARISONS
insert into PurchaseAdvisoryDailyTotals (itemID, oldCode, toOrder, toOrderGrowth, loginName)
    select ID, oldCode, toOrder, toOrderGrowth, loginName
    from purchaseAdvisory
    
-- REBUILD THE PURCHASE ADVISORY
delete from PurchaseAdvisory


exec CreatePurchaseAdvisory 91, 0, 'JK'
exec CreatePurchaseAdvisory 91, 0, 'RP'
exec CreatePurchaseAdvisory 91, 0, 'SK'
exec CreatePurchaseAdvisory 91, 0, 'JT'
exec CreatePurchaseAdvisory 91, 0, 'JG'
exec CreatePurchaseAdvisory 91, 0, 'Bruce'


-- CREATE ALERTS FOR PA ITEMS THAT JUST WENT NEGATIVE
declare @yesterday  date
declare @ID         bigInt
declare @buyer      varchar(5)
set @yesterday = dateadd(dd,-1, getdate())  
  
DECLARE myCursor CURSOR FOR 
    select distinct P.ps_Items_RID, buyer from PurchaseAdvisory P 
        inner join PurchaseAdvisoryDailyTotals P2 on P.oldcode = P2.oldcode and P2.dateEntered = @yesterday
    where P.toOrderGrowth < 0 and P2.toOrderGrowth >= 0 and P.buyer = P.loginName

OPEN myCursor 
FETCH NEXT FROM mycursor INTO @ID, @buyer 

WHILE @@FETCH_STATUS = 0  
BEGIN 

INSERT INTO [dbo].[ALERTS]([ID], [BASVERSION], [BASTIMESTAMP], 
    [isArchived], [objectID], [forUser], [alertType], [fromProcess], [processName], 
    [objectName], [comment], [dateArchived], [dateCreated]) 

    select next Value For BAS_IDGEN_SEQ, 1, getDate(),
        0, 0, case when @buyer = '' then 'jk' else @buyer end, 'To Order Went Negative', 'Nightly Process', 'PurchaseAdvisory',
        'PurchaseAdvisory', 'Negative To Order Days for Item: ' + I.oldCode + ' ' +  I.internalDescription, null, getdate() 
        from PurchaseAdvisory P inner join Items I on P.ps_Items_RID = I.ID
        where P.ps_Items_RID = @ID and @buyer = P.loginName

    FETCH NEXT FROM mycursor INTO @ID, @buyer

END 

CLOSE mycursor  
DEALLOCATE mycursor   

-- CREATE TEMPLATES FOR ITEMS WITH STOCK AND NO TEMPLATE
DECLARE myCursor CURSOR FOR 
    select ID from Items where UMStock > 0 and ID not in (select ob_Items_RID from Templates)
    and (ID < 10000 or ID > 10010)
    

OPEN myCursor 
FETCH NEXT FROM mycursor INTO @ID 

WHILE @@FETCH_STATUS = 0  
BEGIN 

    Exec CreateDefaultTemplate @ID

    FETCH NEXT FROM mycursor INTO @ID

END 

CLOSE mycursor  
DEALLOCATE mycursor 


   

update Quotes set selectedFlag = 0
Update CustomerSummaryForTrips set noLines = 0
update CustomerQuoteSummary set oldcode = null

-- UPDATE ITEMS OPEN PO
update items set LFOpenPO = 0

UPDATE  items SET LFOpenPO = COALESCE(LFOnOrder,0) FROM
Items I inner join 
(SELECT ob_Items_RID AS item, SUM(LFOrdered) LFOnOrder 
FROM PurchaseLines L inner join PurchaseOrders P on L.ob_PurchaseOrders_RID = P.ID
WHERE (L.status = 'Open' or L.status = 'Partial') AND P.status <> 'Complete' AND P.status <> 'Cancelled' AND P.dateSubmitted is not null AND P.ps_Customers_RID is null
GROUP BY ob_Items_RID) as P on P.item = I.ID

--update Items set UMOpenPO = ROUND(LFOpenPO / LFperUM,0) from Items


-- UPDATE LAST ORDER IN CUSTOMER FILE
Update Customers set lastOrder =  Z.lastOrder
from Customers C inner join (select ob_Customers_RID, max(dateEntered) as lastOrder
    from Orders
    group by ob_Customers_RID) as Z on C.ID = Z.ob_Customers_RID
    
-- UPDATE BILL TO BALANCE
update CustomerRelations set balance = Z.totalOwed, creditAvailable = creditLimit - Z.totalOwed

from CustomerRelations R inner join (select ob_BillTo_RID, 
    sum(balance) as totalOwed from Invoices group by ob_BillTo_RID) as Z
    on R.ID = Z.ob_BillTo_RID
    
    
-- UPDATE STANDARD UNIT SIZE IN ITEM
update items set standardUnitSize = largestUnit
from Items I inner join  (select ob_Items_RID, max(UMStock) as largestUnit
from Units where UMStock > 0 and UnitType = 'I' group by ob_Items_RID) as Z on I.ID = Z.ob_Items_RID

-- CLEAR AVG COST IF NO STOCK
update items set avgCost = 0 where avgcost > 0 and UMStock <= 0

-- CLEAR ANY ORDER TALLY IF ORDER LINE DELETED
delete from orderTally where ob_OrderLines_RID not in (select ID from orderLines)

update  orderLines set shipDateOrDesignStatus = convert(char(8), dateshipped, 1 )
where shipDateOrDesignStatus = 'W/P' and dateShipped is not null

-- RECOMPUTE THE LAST COSTS FROM LAST PURCHASE ORDER
/*
Update Items set lastCost = L.cost
    from PurchaseLines L inner join Items I on L.ob_Items_RID = I.ID
    inner join PurchaseOrders P on L.ob_PurchaseOrders_RID = P.ID
    inner join (select ob_Items_RID as item, max(P.poNumber) as maxID 
    from PurchaseLines L inner join PurchaseOrders P on L.ob_PurchaseOrders_RID = P.ID
     group by ob_items_RID)
    as Z on L.ob_Items_RID = Z.item and P.poNumber = Z.maxID
    where I.lastCost <> L.cost
*/
    
-- UPDATE BUYER AUDIT TABLE
--insert into buyerAuditTable (oldCode, buyer)
--select oldcode, buyer from items

-- RECOMPUTE THE TALLY DELTA COST %
EXEC UpdateTemplateDeltaCostPct

-- UPDATE CUSTOMERS LAST SHIPMENT
update customers set lastShipment = z.lastshipment
from customers C inner join (
    select O.ob_Customers_RID, max(dateShipped) as lastShipment from Orders O group by O.ob_Customers_RID)
    as Z on C.ID = Z.ob_Customers_RID


PRINT 'Updating Vendor Yearly Totals'
UPDATE VENDORS 
    SET currentPurchases = 0, previousYearPurchases = 0,
    NumberOpenPOs = 0

update VENDORS
set currentPurchases = Z.last12Months, previousYearPurchases = z.prev12Months,
 DOLPO = lastPO

from VENDORS V inner join (
    select P.ob_vendors_RID,  max(P.PONumber) as PONumber, count(distinct L.PONumber) as noTotalPOs,
  max (P.dateEntered) as lastPO,
  cast (sum(case when dateDiff(dd, P.dateEntered, getDate()) < 366 then
    quantityOrdered * cost / costPer else 0 end) as integer) as last12Months,
  cast (sum(case when dateDiff(dd, P.dateEntered, getDate()) > 365
  and dateDiff(dd, P.dateEntered, getDate()) < 732  then
    quantityOrdered * cost / costPer else 0 end) as integer) as prev12Months

    from PurchaseOrders P inner join PurchaseLines L on L.ob_PurchaseOrders_RID = P.ID
    where costPer > 0 
    group by P.ob_vendors_RID) as Z on V.ID = Z.ob_Vendors_RID
    
update vendors set numberOpenPOs = 0
   
update vendors set numberOpenPOs = Z.noOPenPOs
from vendors V inner join (select P.ob_Vendors_RID, count(*) as noOpenPOs
from PurchaseOrders P 
where P.status <> 'Complete'
group by P.ob_vendors_RID) as Z on V.id = Z.ob_Vendors_RID


-- FIX THE OrderTally TallyCosts

update OrderTally set costDeltaPctFromTemplate = QT.costDeltaPctFromTemplate,
suggestedPct = QT.suggestedPct

from OrderTally OT inner join Quotes Q on OT.ob_OrderLines_RID = Q.ps_OrderLines_RID
inner join QuoteTally QT ON QT.ob_Quotes_RID = Q.ID and QT.length = OT.length

exec ComputeUnitTallyCostDelta
exec ComputeItemSourceUnitDifficultyFactor
exec FindOldPocketWoodItems

-- Compute actual # of source units used
Update OrderLines set NumbSourceActual = noSource
from OrderLines L inner join (
    select L.ID, count(distinct UL.ob_Units_RID) as noSource
    from CADTransactions T inner join OrderLines L on T.ps_OrderLines_RID = L.ID
    inner join UnitLengths UL on T.ps_UnitLengths_RID = UL.ID
group by L.ID) as Z on L.ID = Z.ID

EXEC ComputeItemSourceUnitDifficultyFactor

-- CREATE NUMB SOURCE LOOKUP TABLE
delete from ItemSourceLookupTable

INSERT INTO [dbo].[ItemSourceLookupTable]([ID], [BASVERSION], [BASTIMESTAMP], 
itemID, numbSource, numbSourceLookup) 

select row_number() over (order by E.ID), 1, getdate(),
ID, numbSource, avgActual
from estVsActSourceSummary as E
where avgActual >= 1


update Items set dateOverAllocated = null where id not in (
    select I.ID 
    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    where L.UMShipped = 0 and L.WRD = 'W'
    group by I.id, I.oldcode, I.internalDescription
    having max(UMStock) - max(UMPocketWood) < sum(L.UMordered))

update Items set dateOverAllocated = getDate() where dateOverAllocated is null and id in (
    select I.ID 
    from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    where L.UMShipped = 0 and L.WRD = 'W'
    group by I.id, I.oldcode, I.internalDescription
    having max(UMStock) - max(UMPocketWood) < sum(L.UMordered))
    
-- UPDATE UNIT HISTORY

INSERT INTO [dbo].[UnitDailyTotals]([ID], [BASVERSION], [BASTIMESTAMP], 
[location], [UMStock], 
[ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], 
[ob_Units_REN], [ob_Units_RID], [ob_Units_RMA], [dateCreated]) 

select next Value For MySeq, 1, getdate(),
location, UMStock,
'Items', ob_Items_RID, null,
'Units', ID, null, cast(getdate() as date)
from Units
where UMStock > 0 and lostFlag <> 1

-- FIX Double quotes into 2 appostrophies
update items
set internalDescription = REPLACE(internalDescription, '"', '''''')
where internalDescription like '%"%'

-- UPDATE MONTHLY USAGE OF ITEMS BY MAXLEN
exec DailyUpdateUnitMaxlenData
/*
THIS IS DONE IN THE DAILY UPDATE SO NOT NEEDED HERE
-- FOR ITEMS WITH < 12 MONTHS SALES, UPDATE THE MONTHLYUSAGE BY RATIO OF PART OF YEAR WE SOLD IT
Update UnitMaxLenData set monthlyUsage = MonthlyUsage * 12 / noMonths
from UnitMaxLenData U inner join 
(select ob_Items_RID, minDate, datediff(m, mindate, getdate()) as noMonths
    from (select L.ob_Items_RID, min(dateShipped) as minDate
    from OrderLines L 
    where dateadd(yy, -1, getdate()) < dateShipped 
    group by L.ob_Items_RID) as Z) as Y on Y.ob_Items_RID = U.ob_Item_RID
    where Y.noMonths between 1 and 11
*/

DELETE From SalesPersonKeyToSellPocketWood

-- CREATE BILLTO DAILY TOTALS
INSERT INTO [dbo].[BillToDailyTotals]([billToID], [dateEntered], [totalOwed], [totalLate])

select ob_BillTo_RID as billTo, getdate(),
    sum(balance) as totalOwed, 
    sum(case when getDate() <=dueDate then 0 else balance end) as totalLate

    from Invoices 
    where balance <> 0
    group by ob_Billto_RID
    
-- CREATE CONSIGNMENT DAILY LOG
insert into consignmentDailyLogs (inventoryID, oldcode, consignmentUM, date)
    select id, oldcode, consignmentUM, dateadd(dd, -1, cast(getdate() as date)) as date
    from Items --where consignmentUM <> 0
    
-- ANY PO WHICH HAS ALL LINES MARKED COMPLETE, MAKE THE PO HEADER COMPLETE
Update PurchaseOrders set status = 'Complete', statusFormatted = 'Complete'
where ID in 
    (select ob_PurchaseOrders_RID 
    from PurchaseLines L inner join PurchaseOrders P on L.ob_PurchaseOrders_RID = P.ID
    where P.status <> 'Complete'
    group by ob_PurchaseOrders_RID
    having count(*) = sum(case when L.status = 'Complete' then 1 else 0 end) )
    
    
exec CreateUndigByMaxLen

-- CLEAR POCKETWOOD FOR ALL NON-INTACT UNITS THAT WERE HIT

Update Units set pocketWoodFlag = 0

    from Units U inner join Items I on U.ob_Items_RID = I.ID
    -- THIS JOIN IS USED TO OVERRIDE THE DONOTUNPOCKETWOOD FOR ITEMS
    -- WITH INTACT UNITS OF SAME LENGTH
    left outer join
    (select ob_Items_RID, longLength from Units where UMStock > 0 and UnitType = 'I' 
    and pocketWoodFlag = 0 and lostflag = 0 and longLength = shortLength)
    as Z on Z.ob_Items_RID = I.ID and Z.longLength = U.longLength
    
    where U.UMStock > 0 and U.lostFlag = 0 and U.pocketWoodFlag = 1
    and (I.doNotUnPocketWoodNonIntactUnits = 0 or Z.ob_Items_RID is not null)
    
    and U.ID in (select U.ID
        from CADTransactions T inner join CADDrills D on T.ps_CADDrills_RID = D.ID
        inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units U on L.ob_Units_RID = U.ID
        WHERE D.designDate >= cast(getdate() as date) -- ADDED 09/13/23 TO ONLY UNPOCKETWOOD ITEMS DESIGNED TODAY
        )
    
    and U.ID in (select U.ID from Units U inner join UnitLengths L on L.ob_Units_RID = U.ID
    where L.qtyOnHand < L.originalQty)
    
    
-- UPDATE PO IS LATE FLAG FOR OPEN PO'S THAT, DEPENDING ON SHIP VIA, ARE "X" DAYS BEFORE DUE
Update PurchaseOrders set POIsLateFlag = 0 

update PurchaseOrders set POIsLateFlag = 1
WHERE status = 'Ordered' and consignmentFlag = 0 and(
   ((Shipvia = 'Box Rail Car' or ShipVia = 'Flat Rail Car') and datediff(dd, getdate(), estReceivedDate) <= 14) OR
   (ShipVia = 'FlatBed Truck' and datediff(dd,  getdate(), estReceivedDate) < 1) OR
   (ShipVia = 'Van' and datediff(dd, getdate(), estReceivedDate) <= 35) OR
   (ShipVia = 'Courier' and  datediff(dd, getdate(), estReceivedDate) <= 3 ))
 
 

-- CREATE THE CONSIGNMENT CONSIGNMENT TRANSACTIONS. 
exec CreateConsignmentTransactionsFromConsignmentCustomers
exec CreateConsignmentTransactionsFromNonConsignmentCustomers   
   
-- FIX WHERE CONSIGNMENTUM > UMAVAILABLE + POCKETWOOD -- HAPPENS FROM MANUAL ADJUSTMENTS
INSERT INTO [dbo].[ConsignmentTransactions]([ID], [BASVERSION], [BASTIMESTAMP], 
[cost], [pieces], [qtyUM], [action], [dateEntered], 
[description], [consignmentUM], [qtySold], [qtyPurchased],
[ps_User_REN], [ps_User_RID], [ps_User_RMA], 
[ps_Items_REN], [ps_Items_RID], [ps_Items_RMA]) 

select next value for mySeq, 1, getdate(),
    I.avgCost, (I.consignmentUM - (I.UMAvailable + I.UMpocketWood)), 
    (I.consignmentUM - (I.UMAvailable + I.UMpocketWood)),
    'Consignment > Avail', dateAdd(dd, -1, getdate()),
    'Adjustments Made UMAvailable < Consignment UM', I.consignmentUM, 
    (I.consignmentUM - (I.UMAvailable + I.UMpocketwood)), 0, 
    'RegularUser', 3, null,
    'Items', I.ID, null
from Items I where consignmentUM > (UMAvailable + UMpocketwood) 
    AND consignmentUM > 0 and UMAvailable >= 0

Update Items set consignmentUM = UMAvailable + UMPocketWood 
where consignmentUM > (UMAvailable + UMPocketwood) and consignmentUM > 0 and UMAvailable + UMPocketWood >= 0

-- FILL IN ANY MISSING UNDIGBYMAXLEN
Insert into UndigByMaxLen(ID, BASVERSION, BASTIMESTAMP, ob_Items_REN, ob_Items_RID, dateAdded, maxlen, len)

select next value for mySEQ, 1, getdate(), 
    'Items', Z.ID, getdate(), Z.longLength, rtrim(cast(Z.longLength as char(4))) + ''''
    from (select distinct I.ID, I.oldCode, U.longLength

    from Units U inner join Items I on U.ob_Items_RID = I.ID
    left outer join UndigByMaxLen UML on UML.ob_Items_RID = I.ID and UML.maxLen = U.longLength
    where U.UMStock > 0 and U.lostFlag = 0
    and UML.ID is null) as Z
    
    
-- MAKE SURE TRIP STOPS HAVE CORRECT PROFIT
update TripStops set profit = Z.profit

from TripStops TS inner join (select TS.ID as TSID, sum(TSD.profit) as profit
from TripStopDetails TSD inner join TripStops TS on TSD.ob_TripStops_RID = TS.ID
inner join TripCalendar T on TS.ob_TripCalendar_RID = T.ID
--where dateadd(dd, -100, getdate()) < T.startTime 
group by TS.ID
having sum(TSD.profit)<>  max(TS.profit) 
) as Z on TS.ID = Z.TSID


exec UpdateLargestIntactUnitByLength

exec UpdateBayTotals

update orderLines set orderLineForDisplay = orderLineForDisplay + cast(lineNumber as varchar(2))
where right(orderLineForDisplay,1) = '-'

delete from orderLines where id in (select L.id from orderLines L 
where ob_Orders_RID not in (select id from orders))
GO
