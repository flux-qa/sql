USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CheckInvalidBundling]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CheckInvalidBundling]

@unit       integer,
@success    integer OUT

as 
select @success = count(*)
    from UnitLengths L inner join Units U on L.ob_Units_RID = U.ID
    inner join Items I on U.ob_Items_RID = I.ID
    where U.unit = @unit
    and I.pcsBundle > 1
    and floor(L.qtyOnHand / I.pcsBundle) * I.pcsBundle <> L.qtyOnHand
    
IF @success > 1
   set @success = 1
GO
