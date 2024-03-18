USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTempUnitTagOneUnit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateTempUnitTagOneUnit]

@unit   integer = 43626


as

delete from TempUnitTags

INSERT INTO TempUnitTags (ID, BASVERSION, BASTIMESTAMP,
    unit, description, tally)


select next Value For mySeq, 1, getdate(),
unit, I.oldCode + ' ' + I.internalDescription as description,
format(U.UMStock + U.UMRolling, '##,###') + ' ' + I.UM + ' ' + cast(U.piecesStock + U.piecesRolling as char(3)) + 'pcs  ' +
dbo.UnitTallyToString(U.ID)  as tally

from Units U inner join Items I on U.ob_Items_RID = I.ID
where U.unit = @unit
GO
