USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateQuoteRecord]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateQuoteRecord]   
--
-- LAST CHANGE 11/30/06
--

@Custno Integer,
@Item Integer,
@Buyer Integer

as

declare @QuoteID integer
declare @BuyerName varchar(100)
declare @CR integer

select @BuyerName = firstName + ' ' + lastName from CustomerContacts
where ID = @Buyer

select top 1 @CR =  C.ID 
from CustomerRelations C inner join CustomerRelations_REF CR 
on C.ID = CR.ID
where CR.RID = 3732
order by preferred


    select @QuoteID = NEXT VALUE FOR BAS_IDGEN_SEQ
-- `1st CREATE QUOTE
insert into QUOTES 
    ([ID], [BASVERSION], [BASTIMESTAMP], 
    [ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], 
    [ob_Customers_REN], [ob_Customers_RID], [ob_Customers_RMA], 
    WRD, SRO, pickup, customTally, wholeUnits, 
    status, statusString, per, perString, dateEntered, sunsetDate, DOLChange,
    customerUM, LFperUM, numbSource, numbTarget,
    LFMaxQty, UMOrdered, BMEs, tallyUM, formHeading, buyer, customerContactID, 
    noUnitsAssigned, LFperDefaultUM,
    ps_BIllTo_REN, ps_BillTo_RID, ps_BillTo_RMA) 

select @QuoteID, 1, getDate(), 'Items', @Item, 'om_Quotes',
    'Customers', @Custno, 'om_Quotes',
    'W', 'S', 0, 0, 0,
    'Q', 'Quote', I.UMPer, I.UMPerString, getDate(), dateAdd(dd, coalesce(I.daysToSunsetQuote,1), getDate()), getDate(),
    I.UM, I.LFperUM, defaultNoSourcesForQuote, defaultNoTargetsForQuote,
    0, 0, 0, 0,  '', @BuyerName, @Buyer, 0, I.LFperUM,
    'CustomerRelations', @CR, null

from ITEMS I WHERE I.ID = @Item
GO
