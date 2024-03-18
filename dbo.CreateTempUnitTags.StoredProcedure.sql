USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTempUnitTags]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateTempUnitTags]

@PONumber   integer = 43626


as

delete from TempUnitTags

INSERT INTO TempUnitTags (ID, BASVERSION, BASTIMESTAMP,
    unit, description, tally)


select next Value For mySeq, 1, getdate(),
unit, I.oldCode + ' ' + I.internalDescription as description,
format(U.UMStock + U.UMRolling, '##,###') + ' ' + I.UM + ' ' + 
format(U.piecesStock + U.piecesRolling , '#,###') + ' pcs  ' +
dbo.UnitTallyToString(U.ID)  as tally

from Units U inner join Items I on U.ob_Items_RID = I.ID
inner join PurchaseOrders P on U.ps_PurchaseOrders_RID = P.ID
where P.PONumber = @PONumber
GO
