USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeSubstituteLengthDeltaPcs]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ComputeSubstituteLengthDeltaPcs]
@CADDrill       integer,
@originalUnit   integer,
@substituteUnit integer

as


Update UnitLengths
    set deltaFromSubstituteUnit = case when T.take is null then qtyOnHand
    else qtyOnHand - T.take end
    
from UnitLengths L left outer join CADTransactions T on L.length = T.length

WHERE T.unitNumber = @OriginalUnit AND T.ps_CADDrills_RID = @CADDrill
    AND L.ob_Units_RID = @substituteUnit
GO
