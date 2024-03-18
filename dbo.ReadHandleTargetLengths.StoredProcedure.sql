USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadHandleTargetLengths]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadHandleTargetLengths]
@handleTargetMobileID   integer

as

select CD.ID as cadDrillID, CD.designDate, CD.drillNumber,
    U.unit as sourceUnit, L.length, L.take, L.takeAll, L.took, L.tookAll, L.balance, L.piecesNested

    
    from HandleTargetLengths L 
    inner join CADDrills CD on L.ps_CADDrills_RID = CD.ID
    inner join Units U on L.ps_SourceUnit_RID = U.ID 

    WHERE L.ob_HandleTargetMobile_RID = @HandleTargetMobileID
GO
