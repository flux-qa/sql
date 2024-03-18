USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeUnitHighAndWide]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeUnitHighAndWide]
as



UPDATE Units set wide = case when wide = 0 then cadWidthPieces else wide end,
high = floor (piecesStock / cadWidthPieces / case when U.pcsPerBundle > 0 then U.pcsPerBundle else 1 end)

from units U inner join Items I on U.ob_Items_RID = I.ID
inner join (select ob_units_RID as unit, min(length) as minLen, 
max(length) as maxLen from unitLengths
where qtyOnHand > 0 group by ob_Units_RID) as Z on U.ID = Z.unit


where high = 0 and minlen * 2 > maxlen and CADWidthPieces > 0
GO
