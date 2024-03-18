USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateOrderTallyPriorToEdit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateOrderTallyPriorToEdit]



@orderLineID integer = 1317371

as

update OrderTally set qtyUM = ROUND(T.length * T.pieces / I.LFperUM,0)

from OrderTally T inner join OrderLines L on T.ob_OrderLines_RID = L.ID
inner join Items I on L.ob_Items_RID = I.ID

where T.ob_OrderLines_RID = @orderLineID

Update OrderLines set tallyString = dbo.OrderTallyToString(@orderLineID)
where orderLines.ID = @orderlineID
GO
