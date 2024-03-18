USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[FindPreviousUnpostedTargets]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FindPreviousUnpostedTargets]
@target integer,
@ret    integer out

as

select @ret = ISNULL(min(TU.unit),0)
    from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join Units TU on T.ps_TargetUnit_RID = TU.ID
    where U.ID in (select L.ob_Units_RID
        from CADTransactions T inner join UnitLengths L on T.ps_UnitLengths_RID = L.ID
        inner join Units TU on T.ps_TargetUnit_RID = TU.ID 
         where TU.unit = @target and TU.unitType = 'T')
     and TU.dateWorkPapersProcessed is null AND TU.UMStock > 0 AND TU.unitType = 'T' AND TU.unit < @target
GO
