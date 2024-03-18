USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ClearPhantomContractorLinks]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[ClearPhantomContractorLinks]

as

update orderLines set ps_LinkToContractorOrderLine_RID = null

    from OrderLines L inner join Quotes Q on Q.ps_OrderLines_RID = L.ID
    where L.UMShipped = 0 and 
    L.ps_LinkToContractorOrderLine_RID is not null and 
    Q.ps_LinkToContractorOrderLine_RID is null
GO
