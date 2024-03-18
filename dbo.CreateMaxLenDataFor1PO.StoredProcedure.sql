USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateMaxLenDataFor1PO]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateMaxLenDataFor1PO]
@poNumber   integer

as

delete from POMaxLenData where PONumber = @poNumber


insert into POMaxLenData(ID, BASVERSION, BASTIMESTAMP,
    PONumber, code, item, maxLength, bayName, inchesHigh, monthlyUsage, preferredBay)

select next value for mySEQ as ID, 1 as BASVERSION, getdate() as BASTIMESTAMP,
@poNumber, I.oldcode as code, I.internalDescription as item, U.maxLength, isNull(U.bayName,'') as bayName, U.inchesHigh, U.monthlyUsage, U.preferredBay
    from UnitMaxLenData U inner join PurchaseLines L on L.ob_Items_RID = U.ob_Item_RID
    inner join Items I on U.ob_Item_RID = I.ID
    where L.PONumber = @PONumber
GO
