USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeUnitTallyCostDelta]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeUnitTallyCostDelta]
as

-- last change 05/03/18  NEW LOGIC

-- COMPUTE THE TALLY PCT FOR EACH LENGTH
update UnitLengths
    set tallyPct = 0 where tallyPct <> 0 and qtyOnHand = 0

update unitLengths
    set tallyPct = round(100.0 * ((L.length * L.qtyOnHand) / I.LFperUM) / U.UMStock,1)
    from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
        where U.UMStock > 0 and L.qtyOnHand > 0  and I.lfperUM > 0

Update Units 
    set ComputedTallyCostDeltaPct = ROUND(case when Z.costDeltaPct <= 0 then 0 else Z.costDeltaPct end,0)
    from Units U inner join (select U.ID, 
        sum(case when suggestedPct = 100  or aboveTallyPct = 0 or aboveTallyPct = 100 then 0
        else ROUND(0.01 * aboveTallyPct * (isnull(tallyPct,0) - suggestedPct),1)
        end) as costDeltaPct
            from Templates T inner join Units U on T.ob_Items_RID = U.ob_Items_RID
            left outer join UnitLengths L on L.ob_Units_RID = U.ID and L.length = T.length
            where U.UMStock > 0 group by U.ID) as Z on U.ID = Z.ID
GO
