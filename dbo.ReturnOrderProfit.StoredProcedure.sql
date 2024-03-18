USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnOrderProfit]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReturnOrderProfit]

@orderNumber    integer,
@profit         integer OUT

as

select @profit = ROUND(sum(L.UMOrdered * (L.actualPrice - L.projectedCost) / L.per),0)
    from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    where O.orderNumber = @orderNumber
GO
