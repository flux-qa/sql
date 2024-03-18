USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateQuoteTallyFromWholeUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateQuoteTallyFromWholeUnits]
--
-- Last change 12/29/17
--

@QuoteID        Integer,
@Item           Integer,
@LFPerUM        float,
@customerQty    integer OUT,
@tallyUM        integer OUT,
@LFMaxQty       integer OUT

as


declare
@noRecs     Integer

Set NOCOUNT ON
update QuoteTally set pieces = null, qtyUM = null, pct=null, qtyLF=null, piecesStock=null
    where ob_Quotes_RID = @QuoteID
    
exec CheckIfNewLengthsShouldBeAddedToQuoteTally @quoteID    

;

-- CTE HAS THE LENGTH, THE TOTAL PIECES FROM ASSIGNED UNITS AND TOTAL PIECES FROM ALL UNITS THIS ITEM, THIS LENGTH
with w as (select L.length, sum(L.qtyOnHand + L.qtyInTransit) as unitPieces,
 max(totalPieces) as totalPieces
    from UNITLENGTHS L inner join  QUOTEUNITS U on L.ob_Units_RID = U.ps_Units_RID
        inner join (select length, sum(qtyOnHand + qtyInTransit) as totalPieces 
            from UNITLENGTHS L1 inner join UNITS U1 on L1.ob_Units_RID = U1.ID
            where U1.ob_Items_RID = @Item group by Length) as M on L.length = M.length
    where U.ob_Quotes_RID = @QuoteID
group by L.length)

-- CREATE THE QUOTE TALLY
update QuoteTally set pieces = unitPieces, piecesStock = TotalPieces
    from QuoteTally Q inner join W on Q.length = W.length
    where Q.ob_Quotes_RID = @QuoteID
  

-- GET THE LFMaxQty OF THE TALLY AND IF > 0 THEN COMPUTE THE PCT OF EACH LENGTH
select @LFMaxQty = sum(length * pieces), @noRecs = count(*)
from QuoteTally where ob_Quotes_RID = @QuoteID

-- COMPUTE THE PCT OF EACH LENGTH, THE QTY LF AND UM
IF @LFMaxQty > 0
    Update QuoteTally 
        set pct = round(100.0 * length * pieces / @LFMaxQty,0), 
        qtyLF = length * pieces,
        qtyUM = round(length * pieces / @LFperUM,0)
    FROM QuoteTally
     --T INNER JOIN Quotes Q on T.ob_Quotes_RID = Q.ID
    where ob_Quotes_RID = @QuoteID

-- UPDATE THE QUOTE QTYS

SET @customerQty = FLOOR(@LFMaxQty / @LFperUM) 
SET @tallyUM = FLOOR(@LFMaxQty / @LFperUM)
GO
