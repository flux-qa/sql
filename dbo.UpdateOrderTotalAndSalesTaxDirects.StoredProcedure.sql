USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[UpdateOrderTotalAndSalesTaxDirects]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateOrderTotalAndSalesTaxDirects]

@orderID integer = 1266537

as

declare @salesTaxPct decimal(10,4)

select @salesTaxPct = localSalesTax from SYSTEMSETTINGS

  
update OrderLines set UMShipped = case when PL.quantityOrdered is null then L.UMOrdered else PL.quantityOrdered end, 
    dateShipped = case when L.dateShipped is null then getdate() else L.dateShipped end  
    from OrderLines L left outer join PurchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    where L.ob_Orders_RID = @orderID
    
-- HANDLE FREIGHT AND MISC
update OrderLines set UMShipped = 1 WHERE ob_Orders_RID = @orderID AND ob_Items_RID between 10000 and 10010


update Orders set orderTotal =  Z.orderTotal, dateShipped = case when dateShipped is null then getDate() else dateshipped END,
    salesTax = ROUND(case when isNull(C.salesTaxPct,0) = 0 then 0 when O.pickup = 1 then @salesTaxPct else isNull(C.salesTaxPct,0) end 
        * Z.orderTotal * 0.01,2) 

from Orders O inner join Customers C on O.ob_Customers_RID = C.ID
inner join (select L.ob_Orders_RID, 
    sum(round(1.0 * case when PL.quantityOrdered is null then L.UMOrdered else PL.quantityOrdered end * L.actualPrice / L.per, 2)) as orderTotal
    from OrderLines L left outer join PurchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    where L.ob_Orders_RID = @orderID
    group by L.ob_Orders_RID) as Z on Z.ob_Orders_RID = O.ID   

where O.ID = @orderID
GO
