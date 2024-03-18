USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReadTerminalPurchaseLinesForShipments]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadTerminalPurchaseLinesForShipments]
@P integer = 123

as

SELECT L.ID, L.BASVERSION, L.BASTIMESTAMP, [cost], [theirItemCode], [comments], 
[ob_Items_REN], [ob_Items_RID], [ob_Items_RMA], [noCommentLines], [LFReceived], 
[estDeliveredCost], [costPer], [dateShipped], L.description, [UM], [ob_PurchaseOrders_REN], 
[ob_PurchaseOrders_RID], [ob_PurchaseOrders_RMA], [lineNumber], [quantityReceived], 
[costPerString], [item], [status], [isLineComplete], [adjustedCost], [LFOrdered], 
[BMEOrdered], [dateReceived], [quantityOrdered], [lineTotal], [transitDays], 
[LFRolling], [BASTIMESTAMPTime], [minutesSinceMidnight], [LFPocketWood], 
[quantityPocketWood], [quantityAvailable] 
	FROM PurchaseLines L inner join TerminalItems T on L.ob_Items_RID = T.ID
    WHERE L.ob_PurchaseOrders_RID = @P
    and T.balance > 0 
    
order by L.lineNumber
GO
