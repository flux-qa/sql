USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateDirectSalesOrderNumber]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateDirectSalesOrderNumber]

as

    Update PurchaseOrders set directSalesOrderNumber = O.orderNumber

    from Orders O inner join OrderLines L on O.ID = L.ob_Orders_RID
    inner join PurchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    inner join PurchaseOrders PO on PL.ob_PurchaseOrders_RID = PO.ID
    where ps_PurchaseLines_RID > 0 and L.wrd = 'D'
GO
