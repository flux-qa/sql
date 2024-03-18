USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateTempUnitTagsOneLocation]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateTempUnitTagsOneLocation]

@location   varchar(10)


as

set @location = rtrim(@location) + '%'

delete from TempUnitTags

INSERT INTO TempUnitTags (ID, BASVERSION, BASTIMESTAMP,
    unit, description, tally, location)


select next Value For mySeq, 1, getdate(),
unit, I.oldCode + ' ' + I.internalDescription as description,
format(U.UMStock + U.UMRolling, '##,###') + ' ' + I.UM + ' ' + 
format(U.piecesStock + U.piecesRolling , '#,###') + ' pcs  ' +
dbo.UnitTallyToString(U.ID)  as tally, U.location

from Units U inner join Items I on U.ob_Items_RID = I.ID

where U.UMStock > 0 and U.lostFlag = 0 AND U.location like @location
GO
