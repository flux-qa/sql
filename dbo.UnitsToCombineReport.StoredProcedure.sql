USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UnitsToCombineReport]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROCEDURE [dbo].[UnitsToCombineReport]
as
select UT.unit as targetUnit, US.unit as sourceUnit, tank,
    I.oldCode as code, I.internalDescription as description,
    UT.piecesStock as targetPieces, US.piecesStock as sourcePieces,
    dbo.UnitTallyToString(UT.ID) as targetTally,
    dbo.UnitTallyToString(US.ID) as sourceTally,
    UT.piecesStock + US.piecesStock as newTargetPieces
    
from UnitsToCombine UC
    inner join Units US on UC.sourceUnit_RID = US.ID
    inner join Units UT on UC.targetUnit_RID = UT.ID
    inner join Items I on UT.ob_Items_RID = I.ID

    
order by cast(tank as integer), targetUnit, sourceUnit
GO
