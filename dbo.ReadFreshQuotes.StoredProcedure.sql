USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadFreshQuotes]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadFreshQuotes]
@fieldRep char(4) = ''
as


select Q.ID,  Q.BASVERSION, Q.BASTIMESTAMP,  datediff(dd, dolChange, getDate()) as daysOld,
case when datediff(dd, dolChange, getDate()) < 1 then 'Today'
when datediff(dd, dolChange, getDate()) < 2 or
 (datePart(dw, getDate()) = 2 and datediff(dd, dolChange, getDate()) = 3) then 'Yesterday'
else rtrim(cast (datediff(dd, dolChange, getDate()) as char(3))) + ' Days' end as age,

I.internalDescription as freshItem,
ISNULL(Q.qtyPriceString, '') as qtyPriceString,

--c.id as custID, I.id as itemID, 
c.name as freshName, c.city as freshCity, c.state as freshState,
 deadline, ps_CustomerQuoteSummary_REN, ps_CustomerQuoteSummary_RID, ps_CustomerQuoteSummary_RMA, 
 customerQty, wholeUnits, freshName, lostReason, PONumber, 
 actualPrice, LFOrdered, freshState, profitDollars, projectedCost, 
 qtyFormatted, internalComments, netCost, customTally, priceString, 
 customerQtyMessageFlag, numbSource, suggestedPrice, pickup, 
 customerQtyMessage, priceFormatted, selectedFlag, freshCity, 
 status, dateEntered, lostComments, per, statusString, 
 customerContactID, Q.BMEs, qtyPriceString, replaceDescription, 
 LFperDefaultUM, WRD, dating, SRO, freshItem, sunsetDate, 
 age, UMOrdered, perString, ob_Customers_REN, ob_Customers_RID, ob_Customers_RMA, 
 Q.designComments, hasServiceCharge, customerUM, formHeading, lineCost, Q.buyer, 
 reload, lineTotal, DOLChange, Q.profitPct, customTallyMsg, LFMaxQty, tallyUM, 
 additionalInvoiceDescription, sellFromStock, 
 ps_BillTo_REN, ps_BillTo_RID, ps_BillTo_RMA, 
 ps_OrderLines_REN, ps_OrderLines_RID, ps_OrderLines_RMA, 
 ps_PurchaseLines_REN, ps_PurchaseLines_RID, ps_PurchaseLines_RMA, 
 daysOld, Q.LFperUM, numbTarget, deferred, noUnitsAssigned, 
 ob_Items_REN, ob_Items_RID, ob_Items_RMA, materialCost, 
 financeCost, handlingCost, sellingCost, freightCost, 
 customCost, tallyCost, materialCostUM, whichMaterialCostUsed, 
 tallyDeltaPct, customPrice, freightMultiplier, tallyPieces,
 Q.termsCostForDating, Q.daysUntilDeadline, 
 Q.BMEsperLB, Q.contractorFlag, Q.BMETypeUsed, Q.datingDays, Q.BMEsperFT3,
 Q.customTallyCostDeltaPct, Q.squareUnit,
 ps_AltDeliveryLocations_REN, ps_AltDeliveryLocations_RID, ps_AltDeliveryLocations_RMA,
 intactWholeUnit, customTallyString, actualPricePlus3rdParty,
 ps_LinkToContractorOrderLine_REN, ps_LinkToContractorOrderLine_RID, ps_LinkToContractorOrderLine_RMA,
 Q.keyboarder_REN, Q.keyboarder_RID, Q.keyboarder_RMA, msgForQuoteQuery,
 rebatePct, rebateCost, Q.customerPrice, Q.customLFperUM, Q.numbSourceLookup, Q.maxQtyFromSalesPersonKey,
 tempConsignmentOrders, tempConsignmentStock, ps_ItemForContractForStock_REN, ps_ItemForContractForStock_RID, 
 ps_ItemForContractForStock_RMA, itemIDtoReturnContactServiceTo,
 ContractOrderCustomer_REN, ContractOrderCustomer_RID, ContractOrderCustomer_RMA

from

QUOTES Q inner join CUSTOMERS C on Q.ob_Customers_RID = C.ID
inner join ITEMS I on Q.ob_Items_RID = I.ID

where (@fieldRep = '' OR C.fieldRep = @fieldRep) AND Q.status = 'Q'
order by 4
GO
