USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckIfNewLengthsShouldBeAddedToQuoteTally]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CheckIfNewLengthsShouldBeAddedToQuoteTally]
@quoteID integer

as

Set NOCOUNT ON
update QuoteTally set pieces = null, qtyUM = null, pct=null, qtyLF=null, piecesStock=null
    where ob_Quotes_RID = @QuoteID

;

-- CTE HAS THE LENGTH, THE TOTAL PIECES FROM ASSIGNED UNITS AND TOTAL PIECES FROM ALL UNITS THIS ITEM, THIS LENGTH
with x as (select distinct length
    from QuoteUnits QU inner join UnitLengths L on QU.ps_Units_RID = L.ob_Units_RID
    and length not in (select length from quoteTally where ob_Quotes_RID = @quoteID)
    where ob_Quotes_RID = @quoteID)
    
Insert into QuoteTally (ID, BASVERSION, BASTIMESTAMP, length, piecesStock, ob_Quotes_REN, ob_Quotes_RID, ob_Quotes_RMA)
select @quoteID * 100 + length, 1, getdate(), length, 0, 'Quotes', @quoteID, 'om_QuoteTally' from x
GO
