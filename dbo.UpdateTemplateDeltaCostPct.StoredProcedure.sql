USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateTemplateDeltaCostPct]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[UpdateTemplateDeltaCostPct]

as

-- 1st Digit - 16
print '1st digit A, C or D'
update Templates set aboveTallyPct =
    case when left(I.TemplateCostCode,1) = 'A' then ROUND(10000 / suggestedPct,0)
    when left (I.TemplateCostCode,1) = 'C' then 200
    when left (I.TemplateCostCode,1) = 'D' then 150
    else 0 end
    
from Items I inner join Templates M on I.ID = M.ob_Items_RID
where  M.length = 16  and suggestedPct > 0

-- 1st Digit - 16, type = B  Sum
print '1st digit B'
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from Items I inner join Templates M on I.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates
 where length < 12 group by ob_Items_RID) as Z on I.ID = Z.item
where M.length = 16  AND left(I.TemplateCostCode,1) = 'B' and shortSuggestedPct < 100 and shortSuggestedPct > 0


-- 2nd digit 12
update Templates set aboveTallyPct =
    case when substring(I.TemplateCostCode,2,1) = 'A' then ROUND(10000 / suggestedPct,0)
    when substring(I.TemplateCostCode,2,1) = 'B' then 200
    when substring(I.TemplateCostCode,2,1) = 'C' then 150
    else 0 end

from Items I inner join Templates M on I.ID = M.ob_Items_RID
where  M.length = 12 and suggestedPct > 0

-- 3rd digit > 12  and <> 16
update Templates set aboveTallyPct =
    case when substring(I.TemplateCostCode,3,1) = 'A' then 200
    when substring(I.TemplateCostCode,3,1) = 'B' then 120
    else 0 end

from Items I inner join Templates M on I.ID = M.ob_Items_RID
where M.length > 12 and M.length <> 16

-- 4th digit > 16
update Templates set aboveTallyPct =
    case when substring(I.TemplateCostCode,4,1) = 'B' then 200
    else 0 end

from Items I inner join Templates M on I.ID = M.ob_Items_RID
where  M.length > 16 

-- 4th digit.  find total % of everything < 16
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from Items I inner join Templates M on I.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates 
where length < 16 group by ob_Items_RID) as Z on I.ID = Z.item
where  M.length > 16  AND substring(I.TemplateCostCode,4,1) = 'A' and shortSuggestedPct < 100 and shortSuggestedPct > 0

-- 1st Digit 16 A Pay for all below 16
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from Items I inner join Templates M on I.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates 
where length < 16 group by ob_Items_RID) as Z on I.ID = Z.item
where  M.length = 16  AND substring(I.TemplateCostCode,1,1) = 'A' and shortSuggestedPct < 100 and shortSuggestedPct > 0

-- 1st Digit 16 A Pay for all below 12
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from Items I inner join Templates M on I.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates 
where length < 12 group by ob_Items_RID) as Z on I.ID = Z.item
where  M.length = 16  AND substring(I.TemplateCostCode,1,1) = 'B' and shortSuggestedPct < 100 and shortSuggestedPct > 0

-- 2nd Digit 12 A Pay for all below 12
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from Items I inner join Templates M on I.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates 
where length < 12 group by ob_Items_RID) as Z on I.ID = Z.item
where  M.length = 12  AND substring(I.TemplateCostCode,2,1) = 'A' and shortSuggestedPct < 100 and shortSuggestedPct > 0
GO
