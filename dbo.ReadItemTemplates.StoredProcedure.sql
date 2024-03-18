USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadItemTemplates]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadItemTemplates]

-- 
-- 01/14/16 - change pctStock to decimal
-- 01/15/16 - fixed logic for cost delta
-- 01/21/16 -- changed pct short calc to be 100 times larger
-- 03/02/16 -- updated UMPocketWood
-- 03/05/16 -- fixed divide by zero
-- 03/10/16 -- changed so pct short computes as pct delta
--
@Item integer
as


declare @TempUMStockOver integer,
@TempUMStockUnder Integer

;

Update TEMPLATES
	set UMStock = 0,
        UMPocketWood = 0,
		pctStock = 0,
		pctShort = 0,
		noUnits = 0,
		costDelta = 0
		FROM [TEMPLATES] 
		where ob_Items_RID = @Item
;
 
 
with w as (
select L.length, sum(L.qtyOnHand) as pcs, 
    sum(case when U.pocketWoodFlag = 1 then 0 else L.length * L.qtyOnHand end) as LFStock,
    round(sum(case when U.pocketWoodFlag = 1 then 0 else L.length * L.qtyOnHand / I.LFperUM end),0) as UMStock,
    count (distinct U.unit) as noUnits,
    sum (case when U.pocketWoodFlag = 1 then Round(L.length * L.qtyOnHand / I.LFperUM ,0) else 0 end) as UMPocketWood

    from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_items_RID = I.item
    where I.item = @Item and L.qtyOnHand > 0 and U.lostFlag = 0
    group by L.Length)


Update TEMPLATES
	set UMStock = W.UMStock,
        UMPocketWood = W.UMPocketWood,
		pctStock = case when totLFStock = 0 then 0 else Round(1.0 * w.LFStock / totLFStock,3)  end,
		pctShort = case when totLFStock = 0 or suggestedPct <= 0 then 0 
        else Round(10000.0 * w.LFStock / totLFStock / suggestedPct,2) - 100 end,
		noUnits = w.noUnits,
		--
		-- COST DELTA CALC -- SKIP (DEFAULT TO 0) IF NO ABOVE TALLY PCT (0 OR 100) OR SUGGESTED = 100
		-- ELSE subtract 100 from AboveTallyPct (since 100 is neutral) and divide that by 100 - suggested.
		-- This returns the cost delta per %.  Multiply this by the suggested% - TallyPct
		--
		/*
		costDelta = ROUND(CASE WHEN aboveTallyPct = 0 or aboveTallyPct = 100 
            or suggestedPct = 0  or suggestedPct > 99 THEN 0 ELSE
			(aboveTallyPct - 100.0) / (100.0 - suggestedPct) * (
			CASE WHEN totLFStock = 0 THEN 0 ELSE 100.0 * LFStock / totLFStock END - suggestedPct) END,4)
		*/
	    -- CHANGE 3/30/21 HAVE DELTA VALUE JUST BE THE PCT OFF
	    	costDelta = ROUND(CASE WHEN aboveTallyPct = 0 or aboveTallyPct = 100 
            or suggestedPct = 0  or suggestedPct > 99 THEN 0 ELSE
			
			CASE WHEN totLFStock = 0 THEN 0 ELSE 100.0 * LFStock / totLFStock END - suggestedPct END,4)
		FROM [TEMPLATES] I inner join w on I.length = w.length
		inner join (select sum(LFStock) as totLFStock from w) as Z on 1 = 1
		where ob_Items_RID = @Item 

select top 1 @TempUMStockOver = ROUND(UMStock * 100 / suggestedPct,0)
    from TEMPLATES where ob_Items_RID = @Item and suggestedPct > 0
    order by (100 * pctStock / suggestedPct) desc

select top 1 @TempUMStockUnder = ROUND(UMStock * 100 / suggestedPct,0)
    from TEMPLATES where ob_Items_RID = @item and suggestedPct > 0
    order by (100 * pctStock / suggestedPct) 

Update TEMPLATES
	set UMTemplatable = UMStock - ROUND(@TempUMStockUnder * suggestedPct * 0.01,0),
        UMShortWithGrowth = case when ROUND((@TempUMStockOver * SuggestedPct / 100) - UMStock,0) < 0 then 0 else
            ROUND((@TempUMStockOver * SuggestedPct / 100) - UMStock,0) end

		FROM [TEMPLATES] T 
		where ob_Items_RID = @Item
GO
