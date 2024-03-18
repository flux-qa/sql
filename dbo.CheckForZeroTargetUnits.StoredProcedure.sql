USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckForZeroTargetUnits]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CheckForZeroTargetUnits]

@CADDrillID integer = 10299389,
@noUnits    integer OUT

as

select @noUnits = count(Distinct U.ID)

    from CADTransactions T inner join Units U on T.ps_TargetUnit_RID = U.ID
    where T.ps_CADDrills_RID = @CADDrillID and U.piecesStock = 0
    

set @noUnits = 0
GO
