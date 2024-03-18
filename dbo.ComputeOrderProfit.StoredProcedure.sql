USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ComputeOrderProfit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create Procedure [dbo].[ComputeOrderProfit]

@orderID integer = 4488768,
@profit     decimal(10,2) out

as

select @profit = sum(round(1.0 * customerQty * (actualPrice - projectedCost) / per,2 ))
    from OrderLines 
    where OrderLines.ob_Orders_RID = @orderID
GO
