USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[HandleReadTargetTransactions]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[HandleReadTargetTransactions]

@orderLinesID   integer = 14738218,
@designDate     date = '02/06/24',
@drillNumber    integer = 1

as

-- last change 02/06/24

declare @drillID        integer


select @drillID = ID from CADDrills where designDate = @designDate and drillNumber = @drillNumber


select targetUnitNumber, UMToDesign, UMDesigned, piecesToDesign, piecesDesigned, TAR.ob_HandleCustomerOrders_RID,
    sourceUnitNumber as sourceUnit, length, lengthText take, takeAll, took, tookAll, modifier, balance


from HandleOrderTransactions T inner join HandleOrderTargets TAR on T.ob_HandleOrderTargets_RID = TAR.ID
inner join HandleCustomerOrders HCO on TAR.ob_HandleCustomerOrders_RID = HCO.ID
where HCO.ob_OrderLines_RID = @orderLinesID

order by targetUnitNumber, sourceUnitNumber, length
GO
