USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CombinePocketWoodItems]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
creaTE PROCEDURE [dbo].[CombinePocketWoodItems]

as

Update UNITS set pocketWoodFlag = 1
from UNITS U inner join ITEMS I on U.ob_Items_RID = I.ID
Where I.oldCode in (select oldCode from OldPocketWoodCodes)

Update UNITS
set ob_Items_RID = I2.ID
from UNITS U inner join ITEMS I on U.ob_Items_RID = I.ID
inner join OldPocketWoodCodes O on I.oldCode = O.oldCode
Inner join ITEMS I2 on O.newCode = I2.oldCode

Update PurchaseLines
set ob_Items_RID = I2.ID
from PURCHASELINES U inner join ITEMS I on U.ob_Items_RID = I.ID
inner join OldPocketWoodCodes O on I.oldCode = O.oldCode
Inner join ITEMS I2 on O.newCode = I2.oldCode

Delete from ITEMS
WHERE oldCode in (select OldCode from OldPocketWoodCodes) 

declare @eightFoot integer
declare @tenFoot integer
declare @twelveFoot integer

select @eightFoot = ID from ITEMS where oldcode = '34C8'
select @tenFoot = ID from ITEMS where oldcode = '34C0'
select @twelveFoot = ID from ITEMS where oldcode = '34C1'

update UNITS
    set ob_Items_RID = @tenFoot
    where ob_Items_RID = @eightFoot 
    and pocketWoodFlag = 1 and shortLength = 10

update UNITS
    set ob_Items_RID = @twelveFoot
    where ob_Items_RID = @eightFoot 
    and pocketWoodFlag = 1 and shortLength = 12
GO
