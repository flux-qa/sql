USE [Lumber]
GO
/****** Object:  StoredProcedure [dbo].[CompleteDirectShipment]    Script Date: 3/18/2024 4:24:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CompleteDirectShipment]

@PONumber integer 

as


declare @UMShipped integer,
        @dateShipped date = getDate(),
        @orderID    integer

-- GET THE UMSHIPPED AND ORDERID
select @UMShipped = L.UMOrdered, 
    @orderID = L.ob_Orders_RID
    
    from OrderLines L inner join purchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    inner join PurchaseOrders P on PL.ob_PurchaseOrders_RID = P.ID  
    where P.PONumber = @PONumber

-- UPDATE THE ORDERLINES    
update orderLines set UMShipped = ISNULL(quantityOrdered, L.UMOrdered), dateShipped = @dateShipped,
    shipDateOrDesignStatus = Convert(varchar(11), @dateShipped, 7), shippedFlag = 1
    
    from OrderLines L 
    LEFT OUTER join purchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    LEFT OUTER join PurchaseOrders P on PL.ob_PurchaseOrders_RID = P.ID
    --where P.PONumber = @PONumber
    where L.ob_Orders_RID = @orderID
    
-- UPDATE THE ORDERs    
update Orders set  dateShipped = @dateShipped
    --from OrderLines L inner join Orders O on L.ob_Orders_RID = O.ID
    --inner join purchaseLines PL on L.ps_PurchaseLines_RID = PL.ID
    --inner join PurchaseOrders P on PL.ob_PurchaseOrders_RID = P.ID
    --where P.PONumber = @PONumber   
    where ID = @orderID 
     
     
-- UPDATE THE PURCHASELINES    
update PurchaseLines set quantityReceived = quantityOrdered, dateReceived = @dateShipped,
    status = 'Complete', isLineComplete = 1
    from purchaseLines PL inner join PurchaseOrders P on PL.ob_PurchaseOrders_RID = P.ID
    where P.PONumber = @PONumber     
 
-- UPDATE THE PURCHASELINES    
update PurchaseOrders set status = 'Complete', statusFormatted = 'Complete', dateCompleted = @DateShipped
    where PONumber = @PONumber
GO
