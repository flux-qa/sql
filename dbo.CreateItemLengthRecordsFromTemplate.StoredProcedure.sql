USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateItemLengthRecordsFromTemplate]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[CreateItemLengthRecordsFromTemplate]

@itemID integer

as

insert into ItemLengthCosts (ID, BASVERSION, BASTIMESTAMP,
    ob_Items_REN, ob_Items_RID, ob_Items_RMA, length)
select next value for bas_IDGEN_SEQ, 1, getdate(),
    'Items', @itemID, 'om_ItemLengthCosts', length
    from Templates T where ob_Items_RID = @itemID
    and length not in (select length from ITEMLENGTHCOSTS where ob_Items_RID = @itemID)
GO
