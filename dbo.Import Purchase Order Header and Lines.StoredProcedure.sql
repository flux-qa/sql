USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Import Purchase Order Header and Lines]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Import Purchase Order Header and Lines]
as


truncate table PURCHASEORDERS
update alc.dbo.PurchaseOrder set estReceivedDate = null where estReceivedDate > '01/01/2020'
update alc.dbo.PurchaseOrder set estRollingDate = null where estRollingDate > '01/01/2020'

INSERT INTO [PURCHASEORDERS]([ID], [BASVERSION], [BASTIMESTAMP], 
[ob_Vendors_REN], [ob_Vendors_RID], [ob_Vendors_RMA], [dateModifier], 
[dateRevised], [FOB], [F2F], [miscCharges], [freight], [TotalBMEs], 
[internalComments], [dateConfirmed], [customerNumber], [comments], 
[terms], [PONumber], [estReceivedDate], [mustEnterFreight], [shipVia], 
[subTotal], [datePrinted], [submitRequest], [estRollingDate], [dateEntered], 
[status], statusFormatted, [buyer], [dateLastChange], [dateSubmitted], [vendorNumber], 
[actualRollingDate], [RFQ], [revisionNumber], [actualReceivedDate], [vendorContact], sellFromOnOrder,
assignedToTerminalCommitment) 

select PONumber, 1, getDate(),
'Vendors', vendor, 'ob_Vendors', 'Prox', 
revisionDate, FOB, f2f, miscCharges, freight, TotalBMEs, 
internalComments, dateConfirmed, custno, comments,
terms, PONumber, estReceivedDate, mustEnterFreightBeforeReceive, shipVia,
subTotal, datePrinted, submitRequest, estRollingDate, dateEntered,
case when status = 'C' then 'Complete' when status = 'P' then 'Partial' when status = 'R' then 'Rolling' else 'Open' end,
case when status = 'C' then 'Received' when status = 'P' then 'Partial' when status = 'R' then 'Rolling' else 'Open' end,
buyer, dateLastChange, dateSubmitted, vendor,
actualRollingDate, RFQ, revisionNumber, actualReceivedDate, vendorContact, 'Anytime',
0

    from ALC.dbo.PurchaseOrder P


update VENDORS
set DOLPO = P.lastPO

    from VENDORS V inner join
(select vendorNumber, max(dateEntered) as lastPO
    from PURCHASEORDERS group by vendorNumber) as P on V.ID = P.vendorNumber

update VENDORS
set numberOpenPOs = P.noOpenPOs

    from VENDORS V inner join
(select vendorNumber, count(*) as noOpenPOs
    from PURCHASEORDERS 
    where status = 'O' group by vendorNumber) as P on V.ID = P.vendorNumber

truncate table [PURCHASELINES]

INSERT INTO [PURCHASELINES]([ID], [BASVERSION], [BASTIMESTAMP], 
[costPerString], [costPer], [quantityOrdered], [UM], [comments],  
[LFRolling], [LFOrdered], [theirItemCode], [lineNumber], [status], 
[description], [dateShipped], [LFReceived], [cost], [item], 
[estDeliveredCost], [dateReceived], 
[ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], 
[ob_PurchaseOrders_REN], [ob_PurchaseOrders_RID], [ob_PurchaseOrders_RMA],
quantityReceived, quantityAvailable) 


select recID, 2, getDate(),
case when L.costPer = 1000 then 'M' when L.costPer = 100 then 'C' when costPer = 12 then 'D' when costPer = 10 then 'X' else 'E' end,
L.costPer, quantityOrdered, L.um, comments, 
LFRolling, LFOrdered, theirItemCode, lineNumber, 
case when status = 0 then 'Open' when status = 1 then 'Rolling' when status = 2 then 'Partial' else 'Complete' end ,
L.description, dateShipped, LFReceived, cost, BI.ID, 
estDeliveredCost, dateReceived,
'Items', BI.ID, 'om_PurchaseLines',
'PurchaseOrders', PONumber, 'om_PurchaseLines', 0, quantityOrdered

from ALC.dbo.PurchaseLines L inner join ALC.dbo.Items I on L.item = I.item
inner join ITEMS BI on I.oldCode = BI.oldCode

update PURCHASEORDERS
set noLines = L.numberLines
from PURCHASEORDERS P inner join
(select ob_PurchaseOrders_RID, count(*) as numberLines from PURCHASELINES 
    group by ob_PurchaseOrders_RID) as L
on P.ID = L.ob_PurchaseOrders_RID

Update PURCHASELINES 
set lineTotal = quantityOrdered * cost / costPer,
 estDeliveredCost=quantityOrdered*cost/costPer, BMEOrdered = Round(L.LFOrdered / I.LFperBME,0) 

from PURCHASELINES L inner join ITEMS I on L.ob_Items_RID = I.ID

-- DELETE LINES WHERE NO QTY RECEIVED AND PO MARKED COMPLETE
update PurchaseLines set status = 'Complete'
from PurchaseOrders P inner join PurchaseLines L on P.ID = L.ob_PurchaseOrders_RID
where P.status = 'Complete' and L.quantityReceived = 0


update PURCHASEORDERS set shipVia = 'FlatBed Truck' where shipVia = 'Truck'
update PURCHASEORDERS set shipVia = 'Flat Rail Car' where shipVia = 'Flat Car'
update PURCHASEORDERS set shipVia = 'Box Rail Car' where shipVia = 'BoxCar'
update PURCHASEORDERS set shipVia = 'Pickup' where shipVia = 'PickUp'
update PURCHASEORDERS set shipVia = 'FlatBed Truck' where shipVia = 'FlatBed TT'
update PURCHASEORDERS set shipVia = 'Van' where shipVia = 'Pig Van'
GO
