USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadTerminalPurchaseOrdersForShipments]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadTerminalPurchaseOrdersForShipments]
@V integer = 1042823

as

SELECT P.ID, [BASVERSION], [BASTIMESTAMP], [buyer], [dateModifier], 
[statusFormatted], [comments], [mustEnterFreight], [miscCharges], 
[totalFlatCharge], [datePrinted], [ps_OrderLines_REN], [ps_OrderLines_RID], 
[ps_OrderLines_RMA], [subTotal], [ob_Vendors_REN], [ob_Vendors_RID], [ob_Vendors_RMA], 
[totalBMEs], [vendorContact], [destinationCompany], 
[ps_Customers_REN], [ps_Customers_RID], [ps_Customers_RMA], [FOB], [revisionNumber], 
[dateSubmitted], [dateLastChange], [freight], [noLinesFormatted], 
[numberOfUnitsToCreate], [dateConfirmed], [vendorNumber], [dateEntered], 
[status], [allowSaleFromVPOWhenRolling], [notifyBuyerBeforeReceiving], 
[estRollingDate], [terms], [internalComments], [RFQ], [noFreightLines], 
[F2F], [directMessage], [estReceivedDate], [allowSaleFromVPOAnyTime], 
[submitRequest], [PONumber], [actualReceivedDate], [destinationAddress], 
[shipVia], realNoLines as noLines, [dateRevised], [customerNumber], [actualRollingDate], 
[destinationCityStateZip], [BASTIMESTAMPTime], [minutesSinceMidnight], 
[sellFromOnOrder], [assignedToTerminalCommitment] 

from PurchaseOrders P inner join 
 (select L.ob_PurchaseOrders_RID as ID, count(*) as realNoLines 
    from PurchaseLines L inner join TerminalItems T on L.ob_Items_RID = T.ID
    -- and T.balance > 0  -- removed to show ALL terminal Orders
    group by L.ob_PurchaseOrders_RID) as Z on P.ID = Z.ID
 
where P.ob_Vendors_RID = @V
and P.assignedToTerminalCommitment = 0
    
order by P.dateEntered desc
GO
