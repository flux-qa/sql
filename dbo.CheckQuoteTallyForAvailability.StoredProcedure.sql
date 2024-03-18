USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckQuoteTallyForAvailability]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CheckQuoteTallyForAvailability]  
--
-- Last change 10/04/17
-- Called when quote is displayed to check availability
--

@QuoteID            Integer,
@userID             varchar(6) = '',
@noShortLengths     integer output


as

Declare 

@TallyLF    Integer,
@Item       Integer,
@LFperUM     float,
@wholeUnit  integer

select @item = ob_Items_RID, @LFperUM = LFperUM, @wholeUnit = wholeUnits
from Quotes where ID = @QuoteID



-- SKIP IF WHOLE UNITS
if @wholeUnit = 1 return 0
/*
 * -- FIND THE LENGTHS THAT ARE NOT PART OF ASSIGNED UNITS
 * -- SUBTRACT THE ORDER TALLY WHERE THE ORDER IS NOT A WHOLE UNIT
 * -- AND THE LINE HAS NOT BEEN SHIPPED
*/

update QuoteTally  set piecesStock = availPieces
--pieces = case when pieces is null or availpieces is null then null when pieces <= availPieces then pieces when availPieces <= 0 then 0 else availpieces end
from QuoteTally Q left outer join (
SELECT L.length, sum(isNull(L.qtyOnHand,0)) -  max(isNull(allocatedPieces,0)) as availPieces
from Units U join UnitLengths L on U.ID = L.ob_Units_RID
left outer join (select length, sum(pieces) as allocatedPieces from ORDERTALLY T
        inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
        where L.ob_Items_RID = @Item and L.UMShipped = 0 and L.WRD = 'W' and L.designStatus = '' and 
        L.ps_PurchaseLines_RID is null 
-- NEXT LINE COMMENTED OUT 6/28/20        
--        and L.ID not in (select ob_OrderLines_RID from OrderUnits WHERE ob_OrderLines_RID IS NOT NULL)
        group by length) as T on L.length = T.length

-- Added U.ps_OrderLines_RID is null on 09/07/20
where U.ob_Items_RID = @item and L.qtyOnHand > 0 and U.lostFlag = 0 AND (U.pocketWoodFlag = 0 OR @userID = 'BRUCE' or @userID = 'RP' or @userID = 'JK' )
and U.ps_OrderLines_RID is null
-- NEXT LINE COMMENTED OUT ON 6/28/20
--and U.ID not in (select ps_Units_RID from OrderUnits where ps_units_RID is not null)
group by L.length) as Z on Q.length = Z.length
where Q.ob_Quotes_RID = @QuoteID

/*
-- COMPUTE THE QTYLF
update QuoteTally  set qtyLF = length * pieces, qtyUM = round(length * pieces / @LFperUM,0)
where ob_Quotes_RID = @QuoteID

select @TallyLF = sum(qtyLF) from QuoteTally where ob_Quotes_RID = @QuoteID

-- RECOMPUTE THE PCT OF LENGTH AND CLEAR THE COST DELTA %
update quoteTally set pct = round(100.0 * qtyLF / @TallyLF,0), costDeltaPct = 0
where ob_Quotes_RID = @QuoteID and @TallyLF > 0

-- COMPUTE THE COST DELTA
update QuoteTally set costDeltaPct = ROUND(cast(pct - suggestedPct as integer) * (1.0 * costDeltaPctFromTemplate - 100) / (100 - suggestedPct),2)
where ob_Quotes_RID = @QuoteID and suggestedPct < 100 and costDeltaPctFromTemplate > 0 and cast(pct - suggestedPct as integer) > 0
*/

select @noShortLengths = count(*) from QuoteTally Q 
where Q.ob_Quotes_RID = @quoteID and pieces > piecesStock
GO
