USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[ReturnDailyOrderTotals]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReturnDailyOrderTotals]
@fromdate date = '03/22/2018',
@thruDate date = '03/22/2018',

@salesTotal float output,
@profitTotal float output

as

select @salesTotal = sum(round(L.UMOrdered * actualPrice / L.per,0)),
    @profitTotal = sum(round(L.UMOrdered * (actualPrice - L.projectedCost) / L.per,0))
    from Orders O INNER JOIN OrderLines L ON O.ID = L.ob_Orders_RID
    where O.dateEntered between @fromDate and @thruDate
GO
