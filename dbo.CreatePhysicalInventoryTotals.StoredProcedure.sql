USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreatePhysicalInventoryTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreatePhysicalInventoryTotals]
@skipFixed integer = 0
as

delete from PhysicalInventoryTotals

--update PhysicalInventoryLog set fixedFlag = 1 WHERE left(statusMsg,5) = 'FIXED'
update PhysicalInventoryLog set statusMsg = '' where statusMsg is null
;

with w as (select I.oldcode as code, I.internalDescription as item, I.ID as itemID,
count(*) as noItems,
    sum(case when P.found = 1 then 1 else 0 end) as noFound,
    sum(case when P.missing = 1 then 1 else 0 end) as noMissing,
    sum(case when P.found = 1 and U.UMShipped > 0 then 1 else 0 end) as noShipped,
    sum(case when P.found = 1 and U.unitType <> 'I' then 1 else 0 end) as noHandled   
    from PhysicalInventoryLog P inner join Units U on P.ps_Unit_RID = U.ID
     inner join Items I on U.ob_Items_RID = I.ID
     where (@skipFixed = 0 or fixedFlag = 0) AND statusMsg<>'Bay Changed'
     group by I.oldCode, I.internalDescription, I.ID)

Insert into PhysicalInventoryTotals (ID, BASVERSION, BASTIMESTAMP,
code, item, itemID, noItems, noFound, noMissing, noShipped, noHandled)

    select next Value for mySeq, 1, getdate(),
     code, item, itemID, noItems, noFound, noMissing, noShipped, noHandled
     from W
GO
