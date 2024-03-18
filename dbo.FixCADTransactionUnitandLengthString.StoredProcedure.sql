USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FixCADTransactionUnitandLengthString]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[FixCADTransactionUnitandLengthString]

as

update CADTransactions set unitNumber = SU.unit
from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
inner join Units SU on L.ob_Units_RID = SU.ID
where T.unitNumber is null

update CADTransactions set lengthString = '<b>' + RTRIM(LTRIM(length)) + '''</b>'
where lengthString is null
GO
