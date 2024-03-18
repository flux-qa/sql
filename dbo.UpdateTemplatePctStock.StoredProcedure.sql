USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateTemplatePctStock]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateTemplatePctStock]
as


SET NOCOUNT ON


update Templates set UMStock = ISNULL(UMTemplate,0) , pctStock = isNULL(pctTemplatable,0),
pctShort = null, UMShortWithGrowth = case when isNULL(pctTemplatable,0) * 100  >= suggestedPct then null
else ROUND((0.01 * suggestedPct - isNULL(pctTemplatable,0)) * Z.totAvail,0) end
from Templates T left outer join (
select I.ID, L.length, sum(L.qtyOnHand) as pcs,
    ROUND(sum(L.length * L.qtyOnHand / I.LFperUM),0) as UMTemplate,
    ROUND(100.0 * sum(L.length * L.qtyOnHand / I.LFperUM) /
     max((I.UMStock - I.UMPocketWood)),0)  * 0.01 as pctTemplatable,
     max(I.UMStock - I.UMPocketwood) as totAvail
    from Units U inner join UnitLengths L on U.ID = L.ob_Units_RID
    inner join Items I on I.ID = U.ob_Items_RID
    where  L.qtyOnHand <> 0 and U.pocketWoodFlag = 0 and I.UMStock > 0
        and LFperUM > 0 and I.UMStock > I.UMPocketWood
    group by I.ID, L.length) as Z on T.ob_Items_RID = Z.ID and T.length = Z.length
    

update templates set pctShort = 
    case when pctStock = 0 then 0 else round(10000.0 *  pctStock / suggestedPct, 2) end
    where pctStock * 100 < suggestedPct and suggestedPct > 0
GO
