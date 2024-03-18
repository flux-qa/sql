USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[Import Order Header and Lines]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Import Order Header and Lines]    
as 


-- last change 05/07/18

delete from orders

INSERT INTO [ORDERS]([ID], [BASVERSION], [BASTIMESTAMP], 
[dateCode], fieldRep, 
[DOLChange], 
[FOB], 
[creditNumber], [terms], [noLines], [PONumber], [tripNumber],  
[shipVia], [orderNumber], [dateEntered], [dating], 
[dateShipped], [ob_Customers_REN], [ob_Customers_RID], [ob_Customers_RMA], 
[contact], [estDeliveryDate], [deadline], [pickup], 
[ob_BillTo_REN], [ob_BillTo_RID], [ob_BillTo_RMA], [deferred], holdshipments,
originalShipTo_REN, originalShipTo_RID, originalShipTo_RMA
) 

select orderNumber, 1, getDate(),
dateCode, fieldRep, 
case when DOLChange < '01/01/2001' then dateEntered else DOLChange end, 
fob, 
creditNumber, terms, 0, PONumber, tripNumber,
shipVia, orderNumber, dateEntered, dating, 
dateShipped, 'Customers', custno, 'om_Orders', 
contact, 
--estDeliveryDate, deadline,
case when estDeliveryDate > '10/01/2017' then getDate() else estDeliveryDate end, 
case when deadline > '10/01/2017' then getDate() else deadline end, 
pickup, 'Customers', billTo, 'om_OrdersBillTo', deferred, 0,
'Customers', custno, null

from ALC.dbo.OrderHeader where dateEntered > '01/01/2010' order by dateEntered
    

update orders set ob_BillTo_RID = CR.ID
from Orders O inner join CustomerRelations_REF CR
on CR.RID = O.ob_Customers_RID


DELETE from  ORDERLINES
--where ob_Orders_RID not in (select ID from ORDERS where ob_CUSTOMERS_RID = 2991)
/*
INSERT INTO [dbo].[ORDERLINES]([ID], [BASVERSION], [BASTIMESTAMP], 
[LFShipped], [ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], 
[additionalInvoiceComments], [SRO], [LFMaxQty], [mktCost], 
[ob_Orders_REN], [ob_Orders_RID], [ob_Orders_RMA], 
[suggestedPrice], [termsCost], [numbTarget], [internalComments], [WRDCost], [SGACost], 
[comments], [unitCost], [designComments], [customerQty], [LFOrdered], 
[BMEs], [freightCost], [tallyDeltaCost], [WRD], [datePrinted],
 [lineNumber], [designStatus], workPapersProcessed, [projectedCost], [dateShipped], 
[salesTax], [avgCost], [actualPrice], [per], [dateInvoiced], [customerUM], [numbSource],
UMOrdered, UMShipped, shipDateOrDesignStatus, shippedFlag, orderNumber, orderLineForDisplay) 

select row_number() over (order by L.orderNumber, L.lineNumber), 1, getDate(), 
shippedQty, 'Items', BI.ID, 'om_OrderLines', 
additionalInvoiceComments, SRO, maxQty, L.mktCost, 
'Orders', orderNumber, 'om_OrderLines',
suggestedPrice, termsCost, numbTarget, internalComments, WRDCost, SGACost,
comments, unitCost, designComments, customerQty, orderQty,
BMEs, freightCost, tallyDeltaCost, wrd, datePrinted,
lineNumber, '', '', projectedCost, dateShipped,
salesTax, L.AvgCost, actualPrice, per, dateInvoiced, customerUM, numbSource,
round(maxQty * I.LFtoUM,0), round(shippedQty * I.LFtoUM,0),
case when dateShipped is null then '' else cast(dateShipped as char(11)) end,
case when dateShipped is null then 0 else 1 end, orderNumber,
cast(orderNumber as char(6)) + '-' + ltrim(rtrim(cast(lineNumber as char(2))))

from ALC.dbo.OrderLines L inner join ALC.dbo.Items I on L.item = I.item
inner join ITEMS BI on I.oldCode = BI.oldCode
 where orderNumber >= 311101 and left(i.oldCode,1) <> '|'
 and row_number() over (order by L.orderNumber, L.lineNumber)  
    not in (select ID from OrderLines )
*/

;

with w as (

select row_number() over (order by L.orderNumber, L.lineNumber) as ID, 1 as BASVERSION, getDate() as BASTIMESTAMP, 
shippedQty, 'Items' ob_items_REN, BI.ID as ob_Items_RID, 'om_OrderLines' as ob_Items_RMA, 
additionalInvoiceComments, SRO, maxQty, L.mktCost, 
'Orders' as ob_Orders_REN, orderNumber as ob_Orders_RID, 'om_OrderLines' as ob_Orders_RMA,
suggestedPrice, termsCost, numbTarget, internalComments, WRDCost, SGACost,
comments, unitCost, designComments, customerQty, maxQty as LFOrdered,
BMEs, freightCost, tallyDeltaCost, wrd, datePrinted,
lineNumber, '' as designStatus, '' as workpapersprocessed, projectedCost, dateShipped,
salesTax, L.AvgCost, actualPrice, per, dateInvoiced, customerUM, numbSource,
round(maxQty * I.LFtoUM,0) as UMOrdered, round(shippedQty * I.LFtoUM,0) as UMShipped,
case when dateShipped is null then '' else rtrim(convert( char(11), dateShipped ,7)) end as shipdateordesignstatus,
case when dateShipped is null then 0 else 1 end as shippedFlag, orderNumber,
cast(orderNumber as char(6)) + '-' + ltrim(rtrim(cast(lineNumber as char(2)))) as orderLineForDisplay

from ALC.dbo.OrderLines L inner join ALC.dbo.Items I on L.item = I.item
inner join ITEMS BI on I.oldCode = BI.oldCode
 where orderNumber >= 300000 and left(i.oldCode,1) <> '|'
)

INSERT INTO [dbo].[ORDERLINES]([ID], [BASVERSION], [BASTIMESTAMP], 
[LFShipped], [ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], 
[additionalInvoiceComments], [SRO], [LFMaxQty], [mktCost], 
[ob_Orders_REN], [ob_Orders_RID], [ob_Orders_RMA], 
[suggestedPrice], [termsCost], [numbTarget], [internalComments], [WRDCost], [SGACost], 
[comments], [unitCost], [designComments], [customerQty], [LFOrdered], 
[BMEs], [freightCost], [tallyDeltaCost], [WRD], [datePrinted],
 [lineNumber], [designStatus], workPapersProcessed, [projectedCost], [dateShipped], 
[salesTax], [avgCost], [actualPrice], [per], [dateInvoiced], [customerUM], [numbSource],
UMOrdered, UMShipped, shipDateOrDesignStatus, shippedFlag, orderNumber, orderLineForDisplay) 
select * from w 

Update ORDERLINES
set perString = case when per = 1000 then 'M' when per = 100 then 'C' 
    when per = 12 then 'D' when per = 10 then 'X' when per = 1 then 'E' else 'M' end,
mBMEs = round(bmes / 1000,1),
wholeunits = 0

update CUSTOMERS set unshippedBMEs = 0, unshippedLines = 0, unshippedProfit = 0

update CUSTOMERS 
    set unshippedBMEs = round(Z.BMEs / 100,0) / 10,
    unshippedLines = z.noLines, unshippedProfit = Z.profit
from CUSTOMERS C
inner join (select C.ID as custno, count(*) as noLines, sum(L.BMEs) as bmes, sum(profit) as profit
from CUSTOMERS C inner join ORDERS O on C.ID = O.ob_Customers_RID
inner join ORDERLINES L on O.id = L.ob_Orders_RID
where UMShipped = 0
group by C.ID) as Z on C.ID = Z.custno

update ORDERLINES  set qtyPriceFormatted = 
    rtrim(REPLACE(CONVERT(varchar, CAST(customerQty AS money), 1), '.00', '')) + ' ' +
        customerUM + ' @ ' + 
        rtrim(REPLACE(CONVERT(varchar, CAST(actualPrice AS money), 1), '.00', '')) + '/' +
        perString,
    
    qtyFormatted = rtrim(rtrim(REPLACE(CONVERT(varchar, CAST(customerQty AS money), 1), '.00', '')) + 
    ' ' + customerUM) ,

    priceFormatted = rtrim(rtrim(REPLACE(CONVERT(varchar, CAST(actualPrice AS money), 1), '.00', '')) + 
    ' /' + perString)

DELETE FROM ORDERLINES where UMShipped = 0 AND
ob_Orders_RID in (select ID from ORDERS where estDeliveryDate < '02/01/2018')



-- now import the invoices from the american system
delete from INVOICES

INSERT INTO [dbo].[INVOICES]([ID], [BASVERSION], [BASTIMESTAMP], 
[ob_Customer_REN], [ob_Customer_RID], [ob_Customer_RMA],
[ob_BillTo_REN], [ob_BillTo_RID], [ob_BillTo_RMA], 
[ps_OrderNumber_REN], [ps_OrderNumber_RID], [ps_OrderNumber_RMA],
invoiceNumber, subTotal, salesTax, totalPaid, totalCredit, totalDiscount, 
[dateLastPayment], [dateEntered], dateShipped, [dueDate], discountdate, comments,
[ps_TermsCode_REN], [ps_TermsCode_RID], [ps_TermsCode_RMA], seqNumber, invoiceNumberString,
invoiceDate, invoiceType) 

select row_number() over (order by I.invoice_Number), 1, getDate(),
'Customers', C.ID, 'om_Invoices',
'CustomerRelations', R.ID, 'om_Invoices',
'Orders', O.ID, null,
I.Invoice_Number, I.Sub_Total, I.Sales_Tax, I.Total_Paid, I.Total_Credited, I.Total_Discount,
I.Date_Paid, I.Date_Entered, I.dateShipped, I.Due_Date, I.Discount_Date, '',
'Terms', T.ID, null, 0, rtrim(cast(I.invoice_Number as char(7))), invoiceDate, 'Invoice'

from AMERICAN.dbo.Invoices I inner join American.dbo.Names N on I.ShipTo_Customer = N.Name_Number
inner join American.dbo.Names B on I.SoldTo_Customer = B.Name_Number

inner join CUSTOMERS C on N.oldCustNo = C.oldCustNo
left outer join ORDERS O ON O.ID = I.Order_Number

INNER JOIN CUSTOMERRELATIONS R ON B.oldCustNo = R.oldBillToCode
and R.relationType = 'Bill To'
left outer join TERMS T on T.ID = R.whseTerms_RID


Update INVOICES set balance = ROUND((subTotal + salesTax) - (totalPaid + totalDiscount + totalCredit),2)


update CUSTOMERRELATIONS set balance = null

update CUSTOMERRELATIONS set balance = totOwed from 
CUSTOMERRELATIONS CR inner join (
select CR.ID, ROUND(100.0 * sum(I.balance), 0) / 100  as totOwed
from CUSTOMERRELATIONS CR inner join INVOICES I on CR.ID = I.ob_BillTo_RID
where I.balance <> 0
group by CR.ID) as Z on CR.ID = Z.ID

update orderLines set LFOrdered = LFmaxQty

update orderLines set pickup = 0 where pickup is null

update orders set holdshipments = 0 where holdshipments is null

-- COMPUTE THE BMEs
update OrderLines
set BMEsperLB = round(100.0 * LFOrdered / I.LFperWeight / 48000,6),
BMEsperFT3 = round(100.0 * LFOrdered / I.LFperCube / 2336,6),
BMES = 0

from OrderLines L inner join Items I on L.ob_Items_RID = I.ID
where L.LFOrdered > 0 and I.LFperWeight > 0 and I.LFperCube > 0

exec updateTemplatePctStock

exec CreateOrderTallyForTesting
GO
