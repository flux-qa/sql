USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdatePOAvailableWhenRolling]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdatePOAvailableWhenRolling]
@POLine integer = 8843083
as
 
Update PurchaseLines set quantityAvailable = 
    case when L.status = 'Rolling' then ISNULL(U.UMRolling,0) else L.quantityOrdered END
     - (L.quantityPocketWood + ISNULL(OL.UMOrdered,0))
    from PurchaseLines L 
    left outer join (select ps_PurchaseLines_RID, sum(UMOrdered) as UMOrdered
        from OrderLines group by ps_PurchaseLines_RID)  as OL ON OL.ps_PurchaseLines_RID = @POLine
    left outer join (select ps_PurchaseLines_RID, sum(UMRolling) as UMRolling 
        from Units where Units.pocketWoodFlag = 0 group by ps_PurchaseLines_RID) as U on U.ps_PurchaseLines_RID = @POLine
    where L.ID = @POLine
GO
