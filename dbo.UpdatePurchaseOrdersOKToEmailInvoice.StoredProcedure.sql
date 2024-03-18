USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdatePurchaseOrdersOKToEmailInvoice]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdatePurchaseOrdersOKToEmailInvoice]

as

Update PurchaseOrders set okEmailInvoice = case when R.email > '' and R.emailInvoices = 1 then 1 else 0 end,
    directSalesOrderNumber = O.orderNumber

    from PurchaseOrders P inner join PurchaseLines L on L.ob_PurchaseOrders_RID = P.ID
    inner join OrderLines OL on OL.ps_PurchaseLines_RID = L.ID
    inner join Orders O on OL.ob_Orders_RID = O.ID
    inner join CustomerRelations R on O.ob_BillTo_RID = R.ID
    
    where P.ps_Customers_RID > 0 AND P.status <> 'Complete' AND P.status <> 'Cancelled'
GO
