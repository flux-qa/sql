USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateQuoteTally]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateQuoteTally]  

-- last change 05/24/18

@QuoteID        Integer,
@Item           Integer,
@LFRequired     Integer,
@LFtoUM         float,
@Bundle         Integer,
@RecomputeFlag  integer = 0,
@maxQty         integer = 0


as


Declare 	
@Totlf      Integer,
@TotalPct 	Float,
@TallyLF    Integer,
@MAX_ID     integer

if @Bundle < 1 or @Bundle is null set @Bundle = 1

Set NOCOUNT ON

/* 0TH DELETE ANY EXISTING TALLY (and QuoteUnit) RECORDS */
Delete From QuoteTally where ob_Quotes_RID = @QuoteID
delete from QuoteUnits where ob_Quotes_RID = @QuoteID

/* SKIP IF THERE ARE NO TEMPLATE LENGTHS WITH PERCENTAGES */
Select @TotalPct = sum(SuggestedPct) from Templates where ob_Items_RID = @Item

if @TotalPct is null begin    -- NO TEMPLATE SO COMPUTE BY CURRENT TALLY

    /* 1ST COMPUTE THE TOTAL LF FOR THIS ITEM */
    select @TOTLF = coalesce(sum(length * qtyOnHand),0)
    from UnitLengths L inner join  units U on U.ID = L.ob_Units_RID
    where U.ob_Items_RID = @ITEM and (pocketwoodFlag = 0 or @maxQty > 0)  and QtyOnHand > 0 AND U.lostFlag = 0
    and U.ID not in (select ps_Units_RID from OrderUnits)

    /* 2ND INSERT INTO THE QUOTE LINE TALLY TABLE THE PERCENTAGE AND PIECES */
    if @LFRequired >= 0 AND @TOTLF > 0 
        Insert into QuoteTally 
    		( ob_Quotes_REN, ob_Quotes_RID, ob_Quotes_RMA, 
                Length, Pieces, Pct,  piecesStock, costDeltaPctFromTemplate, suggestedPct)

    select  'Quotes', @QuoteID, 'om_QuoteTally',
        L.length, round(0.0 + 1.0 * @LFRequired / L.length * sum(L.length * qtyOnHand) / (@Bundle * @TOTLF), 0) * @Bundle,
        Round(sum(L.length * qtyOnHand) * 1000.0 / @TOTLF,1) / 10, sum(qtyOnHand), 0, 0
        from UnitLengths L inner Join Units U on U.ID = L.ob_Units_RID
        Where ob_Items_RID = @ITEM
            and (pocketwoodFlag = 0 or @maxQty > 0)
            and QtyOnHand > 0
            and U.lostFlag = 0
            and U.ID not in (select ps_Units_RID from OrderUnits)
        group by L.length   
    
end else begin

    -- Item has Template so Use it to compute the tally
    Insert into QuoteTally
        (ob_Quotes_REN, ob_Quotes_RID, ob_Quotes_RMA, 
        Length, Pieces, Pct, piecesStock , costDeltaPctFromTemplate, suggestedPct)

    select  'Quotes', @QuoteID, 'om_QuoteTally',
        T.length, round(0.5 + SuggestedPct * @LFRequired / 100 / (T.Length * @Bundle), 0) * @Bundle,
        SuggestedPct, piecesStock - isNull(pcsAllocated,0), T.aboveTallyPct, 
        case when T.tempSuggestedPct > 0 then T.tempSuggestedPct else T.suggestedPct end
        from Templates T inner join (
            select Length, TotalStock = coalesce(sum(length * qtyOnHand),0), sum(qtyOnHand) as piecesStock
            from Units U join UnitLengths L on U.ID = L.ob_Units_RID
            where ob_Items_RID = @ITEM
            and qtyOnHand > 0
            group by Length) as I on T.Length = I.Length
        left outer join (select length, sum(pieces) as pcsAllocated 
            FROM ORDERTALLY T 
                inner join ORDERLINES L on T.ob_OrderLines_RID = L.ID
                inner join ITEMS I on L.ob_Items_RID = I.ID 
                    WHERE L.ob_Items_RID = @Item and L.UmShipped = 0 group by length) as Y
        on T.length = Y.length    
                
        where ob_Items_RID = @Item   
end

commit Transaction

/*
update QuoteTally set qtyUM = round(length * pieces * @LFtoUM,0), 
qtyLF = length * pieces 
where ob_Quotes_RID = @QuoteID
*/

-- ONLY TAKE WHAT IS LESS, STOCK PIECES OR COMPUTED TALLY

exec CheckQuoteTallyForAvailability @QuoteID


-- IF < 90%, and 1st call to this process, recursively call function with LFRequired bumpted up
IF @RecomputeFlag = 0 AND @TallyLF > 0 AND 100.0 * @TallyLF / @LFRequired < 90 begin
    set @TallyLF = ROUND(@LFRequired / (1.0 * @TallyLF / @LFRequired),0) + ROUND(@LFRequired * 0.20,0)
    Exec CreateQuoteTally @QuoteID, @Item, @TallyLF, @LFtoUM, @Bundle, 1
    END
GO
