USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[DeleteQuoteUnitsWhenOrderedForDifferentCustomer]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create Procedure [dbo].[DeleteQuoteUnitsWhenOrderedForDifferentCustomer]

as

delete from quoteUnits where ID in 
    (select qu.id
    from quoteUnits QU inner join Quotes Q on QU.ob_Quotes_RID = Q.ID
    inner join OrderUnits OU on QU.ps_Units_RID = OU.ps_Units_RID
    inner join OrderLines L on OU.ob_OrderLines_RID = L.ID
    inner join Orders O on L.ob_Orders_RID = O.ID
    where O.originalShipTo_RID <> Q.ob_Customers_RID)
GO
