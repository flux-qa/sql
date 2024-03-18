USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[RecomputeQuoteTallyPct]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RecomputeQuoteTallyPct]
@quoteID integer,
@tallyUM integer,
@itemID  integer

as

-- Last Change 05/13/18 -- 

declare @tallyLF integer,
        @wholeUnits integer
        
select @wholeUnits = wholeUnits from Quotes where ID = @quoteID

select @tallyLF = SUM(length * pieces) from QuoteTally where ob_Quotes_RID = @QuoteID

-- 1st Compute the Tally Pct
IF @tallyLF > 0 BEGIN
    update QuoteTally 
        set pieces = isnull(pieces,0), 
        pct = round(100.0 * length * pieces / @tallyLF,0),
        computedTallyDeltaPct = round(isnull(100.0 * length * pieces / @tallyLF,0) - suggestedPct,1),
        costDeltaPct = isNull(costDeltaPct,0),
        suggestedPct = isnull(suggestedPct,0)
        where ob_Quotes_RID = @QuoteID
        
    -- 3RD, UPDATE THE computedTallyDeltaPct
    update QuoteTally set costDeltaPct = 
            case when suggestedPct = 100  or costDeltaPctFromTemplate is null or 
                costDeltaPctFromTemplate = 0 or costDeltaPctFromTemplate = 100 then 0
            else ROUND(0.01 * costDeltaPctFromTemplate * (isnull(pct,0) - suggestedPct),1)
            end
            from QuoteTally Q 
            --left outer join Templates T
            --on T.ob_Items_RID = @ItemID AND Q.length = T.length 
            where Q.ob_Quotes_RID = @quoteID
        
    Update Quotes 
        set customTallyCostDeltaPct = ROUND(case when Z.totalDelta <= 0 then 0 else Z.totalDelta end,0)
        from Quotes Q inner join (select ob_Quotes_RID as unit, 
            sum(costDeltaPct) as totalDelta
            from QuoteTally where ob_Quotes_RID = @QuoteID AND pieces > 0 
            group by ob_Quotes_RID) as Z on Q.ID = Z.Unit    
        

IF @WholeUnits = 1 
    Update Quotes set customTallyCostDeltaPct = ROUND(customTallyCostDeltaPct / 3,0)
    Where ID = @QuoteID

END        


/*
set nocount on
IF OBJECT_ID('tempdb.dbo.#TempCDif', 'U') IS NOT NULL
    drop table #tempCDif

create table #tempCDif (
    unit    int,
    CDif    float,
    lastDeltaAmount float,
    INDEX ix_1 NONCLUSTERED (unit) 
)

-- 2ND, COMPUTE THE TALLY PCT FOR EACH LENGTH
Update QuoteTally
    set pct = ROUND(100.0 * Q.qtyLF / @tallyLF,0),
    costDeltaPct = case WHEN
    T.aboveTallyPct is NULL or T.aboveTallyPct = 0 
        or T.aboveTallyPct = 100 or Q.suggestedPct = 0 
        or ROUND(100.0 * Q.qtyLF / @tallyLF,0) <= Q.suggestedPct then 0 
   -- Compute the Delta cost per each pct then multiply by Pct over Suggested
   else ROUND(T.aboveTallyPct / (100.0 - Q.suggestedPct) * 
        (ROUND(100.0 * Q.qtyLF / @tallyLF,0) - Q.suggestedPct),1) END

    from QuoteTally Q left outer join Templates T
        on T.ob_Items_RID = @ItemID AND Q.length = T.length 
    where Q.ob_Quotes_RID = @quoteID

-- 3RD, UPDATE THE computedTallyDeltaPct
update QuoteTally
set computedTallyDeltaPct = round(Pct - suggestedPct,1),
computedTallyDeltaCostPct = case when suggestedPct = 100 or Pct <= suggestedPct then 0 else
costDeltaPctFromTemplate  end
Where ob_Quotes_RID = @quoteID 

-- CREATE A TEMP TABLE WITH THE CDIF FOR EACH UNIT
insert into #tempCDif (unit, cdif, lastDeltaAmount)
    select  Q.ob_Quotes_RID as unit, sum(round(isnull(pct,0) - T.suggestedPct,1)) as CDif, 
    1.0 as lastDeltaAmount 
    from QuoteTally Q left outer join Templates T 
        on T.ob_Items_RID = @ItemID AND Q.length = T.length  
    
    inner join (select  Q.ob_Quotes_RID as unit, min(length) as firstCostLength
        from QuoteTally Q 
        where Q.pieces > 0 and Q.costDeltaPctFromTemplate > 100
        group by Q.ob_Quotes_RID) as Z on Q.ob_Quotes_RID  = Z.unit
    where Q.length < firstCostLength
    group by Q.ob_Quotes_RID
    having sum(computedTallyDeltaPct) > 0
     
-- ADD the HIGHLengthCredit

update #tempCDif set cdif = cdif + highCredit
    from #tempCDif T inner join (select Q.ob_Quotes_RID as unit, 
        round(sum(T.suggestedPct - isnull(pct,0)), 1) as highCredit
        from QuoteTally Q left outer join Templates T
        on T.ob_Items_RID = @ItemID AND Q.length = T.length 
        where  T.aboveTallyPct > 100 and T.suggestedPct - isnull(pct,0) > 0
        group by Q.ob_Quotes_RID) as Z on T.unit = Z.unit    
    
declare @MaxCount integer = 1
while @maxCount <  10 BEGIN    
    
    IF OBJECT_ID('tempdb.dbo.#TempUnitLengthID', 'U') IS NOT NULL
    drop table #TempUnitLengthID
    
    -- GET THE ID FROM THE UNIT LENGTHS THAT HAS THE LARGEST ABOVETALLYPCT
    select ID into #TempUnitLengthID from QuoteTally Q inner join (
        select ob_Quotes_RID, min(length) as theLength
        from QuoteTally Q inner join (
            select ob_Quotes_RID as unit, max(computedTallyDeltaCostPct) as largestDelta
            from QuoteTally Q inner join #TempCDif T on Q.ob_Quotes_RID = T.unit 
            where computedTallyDeltaCostPct > 0  and ComputedTallyDeltaPct > 0                 
            group by ob_Quotes_RID) as Z on Q.ob_Quotes_RID = Z.unit and Q.computedTallyDeltaCostPct = Z.largestDelta
        group by ob_Quotes_RID) as Y on Q.ob_Quotes_RID = Y.ob_Quotes_RID and Q.length = Y.theLength
    

    
    --  COMPUTE AND SAVE THE AMOUNT TO REDUCE THE LARGEST COST DELTA LENGTH IN THE TEMPCDIF TABLE
    Update #TempCDif set lastDeltaAmount = 
        case when CDif <= Q.computedTallyDeltaPct then CDif else Q.computedTallyDeltaPct end  
        from QuoteTally Q inner join #TempUnitLengthID TUL on Q.ob_Quotes_RID = TUL.ID 
        inner join #TempCDif TCD on Q.ob_Quotes_RID = TCD.unit
    
    
    Update QuoteTally set computedTallyDeltaPct = ROUND(computedTallyDeltaPct - TCD.lastDeltaAmount,1)
        from QuoteTally Q inner join #TempUnitLengthID TUL on Q.ob_Quotes_RID = TUL.ID 
        inner join #TempCDif TCD on Q.ob_Quotes_RID = TCD.unit
    
    delete from #tempCDif where lastDeltaAmount < 0.01
    
    update #TempCDif set CDif = CDif - lastDeltaAmount, lastDeltaAmount = 0
    
    delete from #tempCDif where CDif < 0.01
    
    select 'after pass ' + ltrim(rtrim(cast(@maxCount as char(2)))) + 
        ' there are ' + ltrim(rtrim(cast(count(*) as char(5))))
     + ' Records Left' as results from #TempCDif 
    
    set @MaxCount = @MaxCount + 1
    if not (exists (select 1 from #tempCDif)) break
end


-- COMPUTE THE ComputedTallyCostDelta
Update QuoteTally set ComputedTallyDeltaCostPct =
 case when  computedtallydeltaPct <= 0.01 then 0 else
round(computedTallyDeltaPct * (costDeltaPctfromTemplate / (100 - suggestedPct)),1) end
from QuoteTally
 where ob_Quotes_RID = @QuoteID


Update Quotes set customTallyCostDeltaPct = ROUND(Z.totalDelta,0)
from Quotes Q inner join (select ob_Quotes_RID as unit, sum(ComputedTallyDeltaCostPct) as totalDelta
    from QuoteTally where ob_Quotes_RID = @QuoteID AND pieces > 0 group by ob_Quotes_RID) as Z on Q.ID = Z.Unit
*/
GO
