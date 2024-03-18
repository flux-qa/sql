USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[TallyCostDeltaUpdateForOneItem]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TallyCostDeltaUpdateForOneItem]

@item   integer

as

-- First Digit


-- 1st Digit - 16
print '1st digit A, C or D'
update Templates set aboveTallyPct =
    case when left(T.type,1) = 'A' then ROUND(10000 / suggestedPct,0)
    when left (T.type,1) = 'C' then 200
    when left (T.type,1) = 'D' then 150
    else 0 end
    
from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
where M.ob_Items_RID = @item AND M.length = 16  

-- 1st Digit - 16, type = B  Sum
print '1st digit B'
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates
 where length < 12 group by ob_Items_RID) as Z on T.ID = Z.item
where M.ob_Items_RID = @item AND M.length = 16  AND left(T.type,1) = 'B' and shortSuggestedPct < 100


-- 2nd digit 12
update Templates set aboveTallyPct =
    case when substring(T.type,2,1) = 'A' then ROUND(10000 / suggestedPct,0)
    when substring(T.type,2,1) = 'B' then 200
    when substring(T.type,2,1) = 'C' then 150
    else 0 end

from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
where M.ob_Items_RID = @item AND M.length = 12

-- 3rd digit > 12  and <> 16
update Templates set aboveTallyPct =
    case when substring(T.type,3,1) = 'A' then 200
    when substring(T.type,3,1) = 'B' then 120
    else 0 end

from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
where M.ob_Items_RID = @item AND M.length > 12 and M.length <> 16

-- 4th digit > 16
update Templates set aboveTallyPct =
    case when substring(T.type,4,1) = 'B' then 200
    else 0 end

from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
where M.ob_Items_RID = @item AND M.length > 16 

-- 4th digit.  find total % of everything < 16
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates 
where length < 16 group by ob_Items_RID) as Z on T.ID = Z.item
where M.ob_Items_RID = @item AND M.length > 16  AND substring(T.type,4,1) = 'A' and shortSuggestedPct < 100

-- 1st Digit 16 A Pay for all below 16
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates 
where length < 16 group by ob_Items_RID) as Z on T.ID = Z.item
where M.ob_Items_RID = @item AND M.length = 16  AND substring(T.type,1,1) = 'A' and shortSuggestedPct < 100

-- 1st Digit 16 A Pay for all below 12
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates 
where length < 12 group by ob_Items_RID) as Z on T.ID = Z.item
where M.ob_Items_RID = @item AND M.length = 16  AND substring(T.type,1,1) = 'B' and shortSuggestedPct < 100

-- 2nd Digit 12 A Pay for all below 12
update Templates set aboveTallyPct =
    ROUND(10000 / (100 - shortSuggestedPct),0)
    
from TemplateDataForCalcs T inner join Templates M on T.ID = M.ob_Items_RID
inner join (select ob_Items_RID as item, sum(suggestedPct) as shortSuggestedPct from Templates 
where length < 12 group by ob_Items_RID) as Z on T.ID = Z.item
where M.ob_Items_RID = @item AND M.length = 12  AND substring(T.type,2,1) = 'A' and shortSuggestedPct < 100
GO
