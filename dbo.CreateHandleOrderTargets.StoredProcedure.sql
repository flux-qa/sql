USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CreateHandleOrderTargets]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateHandleOrderTargets]
@drillID integer  = 14729257

as

-- last change 02/05/24

delete from HandleOrderTargets where drillID = @drillID

INSERT INTO [dbo].[HandleOrderTargets]([ID], [BASVERSION], [BASTIMESTAMP], 
[ob_HandleCustomerOrders_REN], [ob_HandleCustomerOrders_RID],  
[piecesToDesign], piecesDesigned, UMToDesign, [UMDesigned], LFToDesign, LFDesigned,
[targetUnitNumber], [high], [plus], [wide],  [drillID]) 


select next value for mySeq, 1, getdate(),
'HandleCustomerOrders', Z.hcID, piecesToDesign, 0, UMOrdered, 0, LFOrdered, 0, targetUnit,
0, 0, 0, Z.drillID

from (select distinct L.ID as orderLineID, TU.unit as targetUnit, HCO.ID as hcID, piecesToDesign,
    L.UMOrdered, L.LFOrdered, T.ps_CADDrills_RID as drillID
from CADTransactions T
    inner join CADDrills CD on T.ps_CADDrills_RID = CD.ID
    inner join Units TU on T.ps_TargetUnit_RID = TU.ID
    inner join OrderLines L on T.ps_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    inner join HandleCustomer HC on HC.customerID = O.ob_Customers_RID and HC.drillID = T.ps_CADDrills_RID
    inner join HandleCustomerOrders HCO on HCO.ob_HandleCustomer_RID = HC.ID
    inner join (select ob_OrderLines_RID, sum(pieces) as piecesToDesign 
        from OrderTally group by ob_OrderLines_RID) as OT on OT.ob_OrderLines_RID = L.ID
    where T.ps_CADDrills_RID  = @drillID) AS Z
GO
