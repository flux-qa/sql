USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DisplayTheUnitLengthAudit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DisplayTheUnitLengthAudit]

@unit   integer

as

select row_number() over (order by A.ID) as ID, 1 as  BASVERSION, getDate() as BASTIMESTAMP,
U.unit, L.length, A.originalQty, A.newQty, A.entered, R.LoginName

    from UnitLengthsAdjustmentLog A inner join UnitLengths L on A.ps_UnitLengths_RID = L.ID
    inner join Units U on L.ob_Units_RID = U.ID
    inner join RegularUser R on A.ps_RegularUser_RID = R.ID
    where U.unit = @unit
    order by L.length, A.entered
GO
