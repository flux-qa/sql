USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadHandleTargetSources]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadHandleTargetSources]
@handleTargetMobileID   integer

as

select CD.ID as cadDrillID, CD.designDate, CD.drillNumber,
    U.unit as sourceUnit, S.bay, S.undigTo, S.isPlaced

    
    from HandleTargetSources S 
    inner join CADDrills CD on S.ps_CADDrills_RID = CD.ID
    inner join Units U on S.ps_SourceUnit_RID = U.ID 
    
    --WHERE S.ob_HandleTargetMobile_RID = @HandleTargetMobileID
GO
