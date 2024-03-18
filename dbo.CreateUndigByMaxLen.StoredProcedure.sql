USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateUndigByMaxLen]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateUndigByMaxLen]

as


-- FIND MAX LENGTH FOR ORIGINAL QTY FOR UNITS and IF NOT IN UnDigByMaxLen INSERT IT
INSERT INTO [dbo].[UndigByMaxLen]([ID], [BASVERSION], [BASTIMESTAMP], 
[len], maxlen, [location], [dateAdded], [dateLastChange], 
[ob_Items_REN], [ob_Items_RID], [ob_Items_RMA]) 

select next value for mySeq, 1, getdate(),
RIGHT('    ' + cast(maxLen as varchar(3)),3)  + '''' as Len, maxlen as mlen, '', getdate(), null,
'ob_Items', ob_Items_RID, 'pm_UndigByMaxLen'
from (
select distinct U.ob_Items_RID, Z.maxLen
from Units U inner join (select ob_Units_RID, max(length) as maxLen
    from UnitLengths
    where originalQty > 0
    group by ob_Units_RID) as Z on Z.ob_Units_RID = U.ID
left outer join UndigByMaxLen UD on UD.ob_Items_RID = U.ob_Items_RID and ud.maxlen = Z.maxLen 
where UD.ID is null AND U.unitType <> 'T') as Y 

/*
-- NEXT, ADD AN "OPEN" LENGTH FOR EACH ITEM
INSERT INTO [dbo].[UndigByMaxLen]([ID], [BASVERSION], [BASTIMESTAMP], 
[len], [location], [dateAdded], [dateLastChange], 
[ob_Items_REN], [ob_Items_RID], [ob_Items_RMA]) 

select next value for mySeq, 1, getdate(),
'Open', '', getdate(), null,
'ob_Items', I.ID, 'pm_UndigByMaxLen'
from Items I left outer join UndigByMaxLen UD on UD.ob_Items_RID = I.ID and UD.len = 'Open'
where UD.ID is null
*/
GO
