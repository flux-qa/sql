USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadTemplatableInventory]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadTemplatableInventory]
AS



delete from TemplatableInventory
;

with W as (select U.ob_Items_RID as item, L.length, 
    sum(qtyOnHand * L.length) as lengthFootage, 
    round(100.0 * sum(qtyOnHand * L.length) / max(LFperUM) / max(I.UMStock - I.UMPocketWood),1) as actualPct,
    max(suggestedPct) as suggestedPct, max(T.tempSuggestedPct) as tempSuggestedPct
    
    from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
    inner join Items I on U.ob_Items_RID = I.ID
    inner join Templates T on T.ob_Items_RID = I.ID and T.length = L.length
    where qtyOnHand > 0 and U.pocketWoodFlag = 0
    and I.UMStock - I.UMPocketWood > 0
    group by U.ob_Items_RID, L.length
    )



INSERT INTO [dbo].[TEMPLATABLEINVENTORY]([ID], [BASVERSION], [BASTIMESTAMP],
item, description, UMStock, templatable, UMPocketWood, UM, templatablePct, buyer, totalShipped, tempTemplatablePct,
deltaValue) 


select I.ID, 1 as BASVERSION, getDate() as BASDATE,  I.oldCode as item, 
    I.internalDescription as description, UMStock, 
    round(UMStock * case when isNULL(templatablePct,0) > 100 then 1 else isNULL(templatablePct,0)  end,0) as templatable, 
    UMPocketWood, UM, round(100.0 * case when isNULL(templatablePct,0) > 1 then 1 else 
		isNULL(templatablePct,0) end,0) as templatablePct, buyer, Y.totalShipped, 
		round(100.0 * case when isNULL(tempTemplatablePct,0) > 1 then 1 else 
		tempTemplatablePct end,0), TC.deltaValue
		
    from Items I left outer join (select w.item, count(*) as noTmpl,
        min(case when actualPct >= suggestedPct or isnull(suggestedPct,0) = 0 then 1 
        else actualPct / suggestedPct end) as templatablePct
        from  W group by w.item having count(*) > 1) as Z on I.ID = Z.item
               
        left outer join (select w.item, count(*) as tempNoTmpl,
        min(case when tempSuggestedPct is null then null when actualPct >= tempSuggestedPct or tempSuggestedPct = 0 then 1 
        else actualPct / tempSuggestedPct end) as tempTemplatablePct
        from  W group by w.item having count(*) > 1) as Z1 on I.ID = Z1.item
               
        
    left outer join (select ob_Items_RID, sum(UMShipped) as totalShipped
        from OrderLines
        where dateShipped > '01/01/2016' and UMShipped > 0 
        group by ob_Items_RID) as Y on I.ID = Y.ob_Items_RID
        
    left outer join (select item,
--
-- COST DELTA CALC -- SKIP (DEFAULT TO 0) IF NO ABOVE TALLY PCT (0 OR 100) OR SUGGESTED = 100
-- ELSE subtract 100 from AboveTallyPct (since 100 is neutral) and divide that by 100 - suggested.
-- This returns the cost delta per %.  Multiply this by the suggested% - TallyPct
--
/*
    ROUND(SUM(CASE WHEN aboveTallyPct = 0 or aboveTallyPct = 100 or aboveTallyPct IS NULL 
    or W.suggestedPct = 0  or W.suggestedPct > 99 THEN 0 
    ELSE (aboveTallyPct - 100.0) / (100.0 - W.suggestedPct) * (actualPct - W.suggestedPct) end), 1) as deltaValue
*/

-- CHANGE 3/30/21 JUST SHOW PCT DIFF ON VALUABLE LENGTHS
    ROUND(SUM(CASE WHEN aboveTallyPct = 0 or aboveTallyPct = 100 or aboveTallyPct IS NULL 
    or W.suggestedPct = 0  or W.suggestedPct > 99 THEN 0 
    ELSE  actualPct - W.suggestedPct end), 1) as deltaValue
    
from W inner join Templates T on W.item = T.ob_Items_RID and W.length = T.length
group by Item) as TC on I.ID = TC.item

WHERE (I.UMStock > 0 OR Y.totalShipped > 0) and left(I.oldCode,1) <> '{' and left(I.oldcode,1) <> '|'AND
 (noTmpl > 1)
	
EXEC UpdateTemplatePctStock

/*
Update TemplatableInventory
set templatable = Z.UMTemplatable,
templatablePct = Z.pctShort
from TemplatableInventory T inner join (select ob_Items_RID,  
min(pctShort) as pctShort, 
round(sum(case when pctStock * 100 > suggestedPct then suggestedPct * UMStock * 0.01
else pctStock * UMStock end),0) as UMTemplatable from templates
group by ob_Items_RID) as Z on T.ID = Z.ob_Items_RID
*/
GO
